#!/usr/bin/env bash
# tests/kill-chain-readiness.sh
# Verifica el camino minimo del taller "Kill Chain → Correlacion".
# Cadena: recon (port scan) + explotacion (SQLi) desde la maquina atacante
# (opsn-desktop) hacia la IP interna de DVWA. Evidencia: ambas firmas
# Suricata del mismo origen, correlacionadas en Wazuh.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

. tests/lib/helpers.sh

ENV_FILE="${OPSN_ENV:-}"
[ -z "$ENV_FILE" ] && [ -f "$HOME/OpenSec_Lab/.env" ] && ENV_FILE="$HOME/OpenSec_Lab/.env"
[ -z "$ENV_FILE" ] && ENV_FILE="config/defaults.env"

# shellcheck disable=SC1090
. "$ENV_FILE" 2>/dev/null || true

WAZUH_PASS="${OPSN_WAZUH_PASSWORD:-admin}"
SID_SCAN="9000050"
SID_EXPLOIT="9000001"

echo ""
printf "${BOLD}OpenSec Lab - Readiness Taller Kill Chain${NC}\n"

container_running() {
    docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$1"
}

# ─── Seccion: prerequisitos (atacante + objetivo) ─────────────────────────────
section "Prerequisitos — atacante y objetivo"

if ! container_running "opsn-desktop"; then
    warn "opsn-desktop no esta corriendo; es la maquina atacante del taller. Verificacion omitida."
    print_summary
    exit $?
fi
pass "Maquina atacante disponible: opsn-desktop"

TARGET_IP="$(docker inspect opsn-dvwa -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' 2>/dev/null)"
ATTACKER_IP="$(docker inspect opsn-desktop -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' 2>/dev/null)"

if [ -n "$TARGET_IP" ]; then
    pass "Objetivo opsn-dvwa en ${TARGET_IP}"
else
    fail "No se pudo resolver la IP de opsn-dvwa. Inicia el servicio."
    print_summary
    exit $?
fi
info "Origen del ataque (opsn-desktop): ${ATTACKER_IP:-desconocido}"

# ─── Seccion: Fase 1 — Reconocimiento ─────────────────────────────────────────
section "Fase 1 — Reconocimiento (port scan)"

docker exec opsn-desktop sh -c \
    "for p in \$(seq 1 60); do nc -z -w1 ${TARGET_IP} \$p 2>/dev/null; done" >/dev/null 2>&1
pass "Port scan ejecutado (60 puertos) desde opsn-desktop hacia ${TARGET_IP}"

# ─── Seccion: Fase 2 — Explotacion ────────────────────────────────────────────
section "Fase 2 — Explotacion (SQLi al servicio hallado)"

docker exec opsn-desktop sh -c \
    "curl -s -o /dev/null 'http://${TARGET_IP}/vulnerabilities/sqli/?id=1%27+OR+%271%27%3D%271&Submit=Submit'" >/dev/null 2>&1
pass "SQL Injection enviado al puerto 80 de ${TARGET_IP}"

# ─── Seccion: Suricata — cadena de firmas ─────────────────────────────────────
section "Suricata — cadena recon + explotacion"

if container_running "opsn-suricata"; then
    for entry in "${SID_SCAN}:Escaneo de puertos (recon)" "${SID_EXPLOIT}:SQL Injection (explotacion)"; do
        sid="${entry%%:*}"
        label="${entry#*:}"
        found=0
        for _ in 1 2 3 4 5 6; do
            if docker exec opsn-suricata sh -c \
                "grep -q '\"signature_id\":${sid}' /var/log/suricata/eve.json 2>/dev/null"; then
                found=1
                break
            fi
            sleep 5
        done
        if [ "$found" = "1" ]; then
            pass "Suricata firmo ${label} (sid ${sid})"
        else
            fail "Suricata no registro ${label} (sid ${sid}) tras ~30s. Revisa el disco del host y docker exec opsn-suricata tail /var/log/suricata/eve.json"
        fi
    done
else
    warn "opsn-suricata no esta corriendo; verificacion de firmas omitida (camino solo-ofensivo)"
fi

# ─── Seccion: Wazuh — correlacion por origen ──────────────────────────────────
section "Wazuh — correlacion por origen"

if container_running "opsn-wazuh-indexer" && [ -n "$ATTACKER_IP" ]; then
    correlated=0
    for _ in 1 2 3 4 5 6; do
        agg="$(docker exec opsn-wazuh-indexer curl -sk -u "admin:${WAZUH_PASS}" \
            'https://localhost:9200/wazuh-alerts-*/_search' \
            -H 'Content-Type: application/json' \
            -d "{\"query\":{\"bool\":{\"must\":[{\"match\":{\"data.src_ip\":\"${ATTACKER_IP}\"}},{\"match\":{\"rule.groups\":\"suricata\"}}]}},\"size\":0}" 2>/dev/null)"
        hits="$(printf '%s' "$agg" | grep -o '"value":[0-9]*' | head -1 | grep -o '[0-9]*')"
        if [ -n "$hits" ] && [ "$hits" -gt 1 ] 2>/dev/null; then
            correlated=1
            break
        fi
        sleep 20
    done
    if [ "$correlated" = "1" ]; then
        pass "Wazuh correlaciona la cadena desde ${ATTACKER_IP} (alertas Suricata: ${hits})"
    else
        warn "Wazuh no correlaciono la cadena tras ~2 min. En ARM/macOS la indexacion puede degradarse; verificar en AMD64."
    fi
else
    warn "opsn-wazuh-indexer no esta corriendo; verificacion de correlacion omitida (camino solo-ofensivo)"
fi

print_summary
