#!/usr/bin/env bash
# tests/api-breach-readiness.sh
# Verifica el camino minimo del taller "Ataque y deteccion en APIs".

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

. tests/lib/helpers.sh

ENV_FILE="${OPSN_ENV:-}"
[ -z "$ENV_FILE" ] && [ -f "$HOME/OpenSec_Lab/.env" ] && ENV_FILE="$HOME/OpenSec_Lab/.env"
[ -z "$ENV_FILE" ] && ENV_FILE="config/defaults.env"

# shellcheck disable=SC1090
. "$ENV_FILE" 2>/dev/null || true

PORT_API="${OPSN_API_PORT:-8025}"
API_BASE="${OPSN_API_BASE_URL:-http://localhost:${PORT_API}}"

echo ""
printf "${BOLD}OpenSec Lab - Readiness Taller API Breach${NC}\n"
printf "API: %s\n" "$API_BASE"

api_request() {
    local method="$1"
    local path="$2"
    local token="${3:-}"
    local payload="${4:-}"

    if [ -n "$payload" ] && [ -n "$token" ]; then
        curl -sk --connect-timeout 5 --max-time 10 \
            -X "$method" "$API_BASE$path" \
            -H "Authorization: Bearer ${token}" \
            -H "Content-Type: application/json" \
            -d "$payload"
    elif [ -n "$payload" ]; then
        curl -sk --connect-timeout 5 --max-time 10 \
            -X "$method" "$API_BASE$path" \
            -H "Content-Type: application/json" \
            -d "$payload"
    elif [ -n "$token" ]; then
        curl -sk --connect-timeout 5 --max-time 10 \
            -X "$method" "$API_BASE$path" \
            -H "Authorization: Bearer ${token}"
    else
        curl -sk --connect-timeout 5 --max-time 10 \
            -X "$method" "$API_BASE$path"
    fi
}

container_running() {
    docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$1"
}

log_contains() {
    local event="$1"

    if container_running "opsn-api"; then
        docker exec opsn-api sh -lc "grep -q '\"event\": \"${event}\"' /logs/api.log 2>/dev/null || grep -q '\"event\":\"${event}\"' /logs/api.log 2>/dev/null"
        return $?
    fi

    warn "No se puede verificar el log porque el contenedor opsn-api no esta disponible"
    return 1
}

section "API"

health="$(api_request GET /api/health)"
if printf '%s' "$health" | grep -q '"status":"ok"\|"status": "ok"'; then
    pass "API health responde correctamente"
else
    fail "API health no responde. Inicia opsn-api y revisa ${API_BASE}/api/health"
fi

section "Autenticacion"

login_body="$(api_request POST /api/auth/login "" '{"username":"alice","password":"alice123"}')"
token="$(printf '%s' "$login_body" | sed -n 's/.*"token"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"

if [ "$token" = "token_alice" ]; then
    pass "Login de alice devuelve token_alice"
else
    fail "Login de alice no devolvio token_alice. Respuesta: ${login_body}"
fi

section "Eventos del taller"

bola_body="$(api_request GET /api/users/2/profile "$token")"
if printf '%s' "$bola_body" | grep -q '"username":"bob"\|"username": "bob"'; then
    pass "BOLA responde con perfil de bob"
else
    fail "BOLA no devolvio perfil de bob"
fi

mass_body="$(api_request PUT /api/users/1/profile "$token" '{"email":"alice+lab@opensec.lab","role":"admin"}')"
if printf '%s' "$mass_body" | grep -q '"role":"admin"\|"role": "admin"'; then
    pass "Mass assignment modifica role"
else
    fail "Mass assignment no mostro role admin"
fi

admin_body="$(api_request GET /api/admin/users "$token")"
if printf '%s' "$admin_body" | grep -q '"username":"admin"\|"username": "admin"'; then
    pass "Broken function auth devuelve lista administrativa"
else
    fail "Broken function auth no devolvio lista administrativa"
fi

section "Log de API"

for event in bola_attempt mass_assignment_attempt broken_function_auth; do
    if log_contains "$event"; then
        pass "Log contiene evento ${event}"
    else
        fail "Log no contiene evento ${event}. Revisa docker exec opsn-api sh -lc 'tail -n 20 /logs/api.log'"
    fi
done

section "Wazuh"

if container_running "opsn-wazuh-manager"; then
    pass "Wazuh manager esta corriendo; busca rule.groups: openseclab_api en el dashboard"
else
    warn "Wazuh manager no esta corriendo; la parte de dashboard queda como verificacion manual"
fi

print_summary
