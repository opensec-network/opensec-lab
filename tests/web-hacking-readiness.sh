#!/usr/bin/env bash
# tests/web-hacking-readiness.sh
# Verifica el camino minimo del taller "Web Hacking → Deteccion".

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

. tests/lib/helpers.sh

ENV_FILE="${OPSN_ENV:-}"
[ -z "$ENV_FILE" ] && [ -f "$HOME/OpenSec_Lab/.env" ] && ENV_FILE="$HOME/OpenSec_Lab/.env"
[ -z "$ENV_FILE" ] && ENV_FILE="config/defaults.env"

# shellcheck disable=SC1090
. "$ENV_FILE" 2>/dev/null || true

PORT_DVWA="${OPSN_DVWA_PORT:-8080}"
DVWA_BASE="http://localhost:${PORT_DVWA}"
WAZUH_PASS="${OPSN_WAZUH_PASSWORD:-admin}"

echo ""
printf "${BOLD}OpenSec Lab - Readiness Taller Web Hacking${NC}\n"
printf "DVWA: %s\n" "$DVWA_BASE"

container_running() {
    docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$1"
}

# ─── Seccion: DVWA ────────────────────────────────────────────────────────────
section "DVWA"

code=$(curl -skL -o /dev/null -w "%{http_code}" \
    --connect-timeout 5 --max-time 10 \
    "${DVWA_BASE}/login.php" 2>/dev/null)

if [ "$code" = "200" ]; then
    pass "DVWA login.php responde HTTP 200"
else
    fail "DVWA login.php no responde HTTP 200 (obtenido: ${code}). Inicia opsn-dvwa y revisa ${DVWA_BASE}/login.php"
fi

# ─── Seccion: Ataques web ─────────────────────────────────────────────────────
section "Ataques web"

# SQL Injection
curl -s -o /dev/null \
    "${DVWA_BASE}/vulnerabilities/sqli/?id=1%27+OR+%271%27%3D%271&Submit=Submit"
pass "SQL Injection — payload enviado"

# Command Injection
curl -s -o /dev/null \
    "${DVWA_BASE}/vulnerabilities/exec/" \
    -d "ip=127.0.0.1;id&Submit=Submit"
pass "Command Injection — payload enviado"

# XSS Reflected
curl -s -o /dev/null \
    "${DVWA_BASE}/vulnerabilities/xss_r/?name=<script>alert(1)</script>"
pass "XSS Reflected — payload enviado"

# File Inclusion
curl -s -o /dev/null \
    "${DVWA_BASE}/vulnerabilities/fi/?page=../../../../etc/passwd"
pass "File Inclusion — payload enviado"

# ─── Seccion: Suricata — firmas ──────────────────────────────────────────────
section "Suricata — firmas"

if container_running "opsn-suricata"; then
    # Da tiempo a Suricata para escribir las firmas en eve.json
    declare -A SIGS
    SIGS["SQL Injection"]="OpenSecLab - SQL Injection en DVWA"
    SIGS["Command Injection"]="OpenSecLab - Command Injection en DVWA"
    SIGS["XSS"]="OpenSecLab - XSS en DVWA"
    SIGS["File Inclusion"]="OpenSecLab - File Inclusion en DVWA"

    for label in "SQL Injection" "Command Injection" "XSS" "File Inclusion"; do
        sig="${SIGS[$label]}"
        found=0
        for _ in 1 2 3 4 5 6; do
            if docker exec opsn-suricata sh -c \
                "grep -q \"${sig}\" /var/log/suricata/eve.json 2>/dev/null"; then
                found=1
                break
            fi
            sleep 5
        done

        if [ "$found" = "1" ]; then
            pass "Suricata firmo ${label}: ${sig}"
        else
            fail "Suricata no registro firma ${label} tras ~30s. Revisa: docker exec opsn-suricata tail -n 20 /var/log/suricata/eve.json"
        fi
    done
else
    warn "opsn-suricata no esta corriendo; verificacion de firmas omitida (camino solo-ofensivo)"
fi

# ─── Seccion: Wazuh — indexacion ─────────────────────────────────────────────
section "Wazuh — indexacion"

if container_running "opsn-wazuh-indexer"; then
    # Da tiempo a Wazuh para indexar los eventos de Suricata.
    indexed=0
    for _ in 1 2 3 4 5 6; do
        agg="$(docker exec opsn-wazuh-indexer curl -sk -u "admin:${WAZUH_PASS}" \
            'https://localhost:9200/wazuh-alerts-*/_search' \
            -H 'Content-Type: application/json' \
            -d '{"query":{"match":{"rule.groups":"suricata"}},"size":0}' 2>/dev/null)"
        hits="$(printf '%s' "$agg" | grep -o '"value":[0-9]*' | head -1 | grep -o '[0-9]*')"
        if [ -n "$hits" ] && [ "$hits" -gt 0 ] 2>/dev/null; then
            indexed=1
            break
        fi
        sleep 20
    done

    if [ "$indexed" = "1" ]; then
        pass "Wazuh indexo alertas de Suricata (rule.groups: suricata, hits: ${hits})"
    else
        fail "Wazuh no indexo alertas Suricata tras ~2 min. Revisa filebeat: docker exec opsn-wazuh-manager filebeat test output"
    fi
else
    warn "opsn-wazuh-indexer no esta corriendo; verificacion de indexacion omitida (camino solo-ofensivo)"
fi

print_summary
