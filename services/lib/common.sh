#!/bin/sh
# services/lib/common.sh — Funciones compartidas para scripts de configuracion
# Usar con: . /lib/common.sh  (source)
# Compatible con /bin/sh (no bash-isms)

# ─────────────────────────────────────────────────────
# LOGGING
# ─────────────────────────────────────────────────────
log_info()  { echo "[✓] $*"; }
log_warn()  { echo "[!] $*"; }
log_error() { echo "[✗] $*" >&2; }
log_step()  { echo "[→] $*"; }

# ─────────────────────────────────────────────────────
# wait_for_api <url> [timeout_segundos] [insecure]
# Reintenta hasta que la URL responde HTTP 2xx.
# Pasar "insecure" como tercer argumento para skip TLS (-k).
# Retorna 0 si disponible, 1 si timeout.
# ─────────────────────────────────────────────────────
wait_for_api() {
    local url="$1"
    local timeout="${2:-120}"
    local insecure="${3:-}"
    local elapsed=0
    local curl_opts="-sf"
    [ "$insecure" = "insecure" ] && curl_opts="-skf"
    log_step "Esperando API: $url (max ${timeout}s)"
    until curl $curl_opts "$url" > /dev/null 2>&1; do
        if [ "$elapsed" -ge "$timeout" ]; then
            log_error "Timeout esperando $url"
            return 1
        fi
        sleep 3
        elapsed=$((elapsed + 3))
    done
    log_info "API disponible: $url"
    return 0
}

# ─────────────────────────────────────────────────────
# check_exists <url> [auth_header]
# Retorna 0 si la URL responde, 1 si no.
# ─────────────────────────────────────────────────────
check_exists() {
    local url="$1"
    local auth="${2:-}"
    if [ -n "$auth" ]; then
        curl -sf -H "$auth" "$url" > /dev/null 2>&1
    else
        curl -sf "$url" > /dev/null 2>&1
    fi
}

# ─────────────────────────────────────────────────────
# api_post <url> <json_data> [auth_header]
# Hace POST JSON y retorna el body de respuesta.
# ─────────────────────────────────────────────────────
api_post() {
    local url="$1"
    local data="$2"
    local auth="${3:-}"
    if [ -n "$auth" ]; then
        curl -s -X POST "$url" \
            -H "Content-Type: application/json" \
            -H "$auth" \
            -d "$data"
    else
        curl -s -X POST "$url" \
            -H "Content-Type: application/json" \
            -d "$data"
    fi
}

# ─────────────────────────────────────────────────────
# extract_json_field <json> <field>
# Extrae un campo de un JSON simple usando sed.
# ─────────────────────────────────────────────────────
extract_json_field() {
    local json="$1"
    local field="$2"
    echo "$json" | sed -n "s/.*\"${field}\":\([^,}]*\).*/\1/p" | tr -d '"' | head -1
}
