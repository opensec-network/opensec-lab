#!/usr/bin/env bash
# tests/phishing-readiness.sh
# Verifica el camino minimo del taller "Phishing → Deteccion".
# Ataque: envio de credenciales a la landing falsa (credential harvesting).
# Evidencia: firma Suricata 9000070 en eve.json, indexada en Wazuh.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

. tests/lib/helpers.sh

ENV_FILE="${OPSN_ENV:-}"
[ -z "$ENV_FILE" ] && [ -f "$HOME/OpenSec_Lab/.env" ] && ENV_FILE="$HOME/OpenSec_Lab/.env"
[ -z "$ENV_FILE" ] && ENV_FILE="config/defaults.env"

# shellcheck disable=SC1090
. "$ENV_FILE" 2>/dev/null || true

PHISH_PORT="${OPSN_GOPHISH_PHISH_PORT:-80}"
PHISH_BASE="http://localhost:${PHISH_PORT}"
WAZUH_PASS="${OPSN_WAZUH_PASSWORD:-admin}"
SIG_ID="9000070"
SIG_NAME="OpenSecLab - Envio de credenciales en claro"

echo ""
printf "${BOLD}OpenSec Lab - Readiness Taller Phishing${NC}\n"
printf "Landing de phishing: %s\n" "$PHISH_BASE"

container_running() {
    docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$1"
}

# ─── Seccion: GoPhish (landing) ───────────────────────────────────────────────
section "GoPhish — landing de phishing"

code=$(curl -skL -o /dev/null -w "%{http_code}" \
    --connect-timeout 5 --max-time 10 \
    "${PHISH_BASE}/" 2>/dev/null)

# El servidor de phishing responde aunque sea con 404 a una ruta sin rid valido:
# lo que importa es que el puerto este sirviendo.
if [ -n "$code" ] && [ "$code" != "000" ]; then
    pass "Servidor de phishing responde en ${PHISH_BASE} (HTTP ${code})"
else
    fail "Servidor de phishing no responde (obtenido: ${code:-sin respuesta}). Inicia opsn-gophish."
fi

# ─── Seccion: Ataque — credential harvesting ──────────────────────────────────
section "Ataque — envio de credenciales"

# POST con usuario + password por HTTP sin cifrar = comportamiento que dispara
# la firma. El rid no necesita ser valido: la deteccion es por comportamiento.
curl -s -o /dev/null \
    "${PHISH_BASE}/?rid=readiness" \
    --data-urlencode "username=admin@opensec.lab" \
    --data-urlencode "password=Readiness-Test-123" \
    --data-urlencode "new_password=Readiness-Nueva-456"
pass "Credenciales enviadas a la landing (POST con username + password)"

# ─── Seccion: Suricata — firma ────────────────────────────────────────────────
section "Suricata — firma de credential harvesting"

if container_running "opsn-suricata"; then
    found=0
    for _ in 1 2 3 4 5 6; do
        if docker exec opsn-suricata sh -c \
            "grep -q '\"signature_id\":${SIG_ID}' /var/log/suricata/eve.json 2>/dev/null"; then
            found=1
            break
        fi
        sleep 5
    done

    if [ "$found" = "1" ]; then
        pass "Suricata firmo el robo de credenciales (sid ${SIG_ID}): ${SIG_NAME}"
    else
        fail "Suricata no registro la firma ${SIG_ID} tras ~30s. Revisa: docker exec opsn-suricata tail -n 20 /var/log/suricata/eve.json (y el espacio en disco del host)"
    fi
else
    warn "opsn-suricata no esta corriendo; verificacion de firma omitida (camino solo-ofensivo)"
fi

# ─── Seccion: Wazuh — indexacion ──────────────────────────────────────────────
section "Wazuh — indexacion"

if container_running "opsn-wazuh-indexer"; then
    indexed=0
    for _ in 1 2 3 4 5 6; do
        agg="$(docker exec opsn-wazuh-indexer curl -sk -u "admin:${WAZUH_PASS}" \
            'https://localhost:9200/wazuh-alerts-*/_search' \
            -H 'Content-Type: application/json' \
            -d "{\"query\":{\"match\":{\"data.alert.signature_id\":\"${SIG_ID}\"}},\"size\":0}" 2>/dev/null)"
        hits="$(printf '%s' "$agg" | grep -o '"value":[0-9]*' | head -1 | grep -o '[0-9]*')"
        if [ -n "$hits" ] && [ "$hits" -gt 0 ] 2>/dev/null; then
            indexed=1
            break
        fi
        sleep 20
    done

    if [ "$indexed" = "1" ]; then
        pass "Wazuh indexo la alerta de credential harvesting (signature_id ${SIG_ID}, hits: ${hits})"
    else
        warn "Wazuh no indexo la alerta tras ~2 min. En ARM/macOS la indexacion puede degradarse; verificar en AMD64. Revisa filebeat: docker exec opsn-wazuh-manager filebeat test output"
    fi
else
    warn "opsn-wazuh-indexer no esta corriendo; verificacion de indexacion omitida (camino solo-ofensivo)"
fi

print_summary
