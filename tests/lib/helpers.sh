#!/bin/sh
# tests/lib/helpers.sh
# Funciones compartidas para todos los test scripts de OpenSec Lab

# ─── Colores ───────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
BOLD='\033[1m'
NC='\033[0m'

# ─── Contadores globales ───────────────────────────────────────────────────────
PASS=0
FAIL=0
WARN=0
# ERRORS es un archivo temporal para compatibilidad POSIX (no arrays en sh)
ERRORS_FILE="/tmp/opsn_test_errors_$$"

# ─── Helpers de output ────────────────────────────────────────────────────────
section() { printf "\n${BLUE}${BOLD}── %s ──${NC}\n" "$*"; }
pass()    { printf "  ${GREEN}✓${NC} %s\n" "$*"; PASS=$((PASS+1)); }
fail()    { printf "  ${RED}✗${NC} %s\n" "$*"; FAIL=$((FAIL+1)); echo "$*" >> "$ERRORS_FILE"; }
warn()    { printf "  ${YELLOW}!${NC} %s\n" "$*"; WARN=$((WARN+1)); }
info()    { printf "    %s\n" "$*"; }

# ─── Assertions HTTP ──────────────────────────────────────────────────────────

# assert_http NAME URL [EXPECTED_CODE]
# Sigue redirects (3xx) para comprobar disponibilidad real del servicio.
assert_http() {
    local name="$1"
    local url="$2"
    local expected="${3:-200}"
    local code

    code=$(curl -skL -o /dev/null -w "%{http_code}" \
        --connect-timeout 5 --max-time 10 "$url" 2>/dev/null)

    if [ "$code" = "$expected" ]; then
        pass "$name → HTTP $code"
    else
        fail "$name → HTTP $code (esperado $expected) [$url]"
    fi
}

# assert_contains NAME URL PATTERN [AUTH_HEADER]
assert_contains() {
    local name="$1"
    local url="$2"
    local pattern="$3"
    local auth_header="${4:-}"
    local body

    if [ -n "$auth_header" ]; then
        body=$(curl -sk --connect-timeout 5 --max-time 10 \
            -H "$auth_header" "$url" 2>/dev/null)
    else
        body=$(curl -sk --connect-timeout 5 --max-time 10 "$url" 2>/dev/null)
    fi

    if printf '%s' "$body" | grep -qF "$pattern"; then
        pass "$name contiene: $pattern"
    else
        fail "$name no contiene '$pattern' [$url]"
    fi
}

# assert_not_contains NAME URL PATTERN
assert_not_contains() {
    local name="$1"
    local url="$2"
    local pattern="$3"
    local body

    body=$(curl -sk --connect-timeout 5 --max-time 10 "$url" 2>/dev/null)

    if printf '%s' "$body" | grep -qF "$pattern"; then
        fail "$name contiene '$pattern' (no deberia) [$url]"
    else
        pass "$name no contiene '$pattern' (correcto)"
    fi
}

# assert_file_contains NAME FILE PATTERN
assert_file_contains() {
    local name="$1"
    local file="$2"
    local pattern="$3"

    if [ ! -f "$file" ]; then
        fail "$name — archivo no existe: $file"
        return
    fi

    if grep -qF "$pattern" "$file"; then
        pass "$name contiene: $pattern"
    else
        fail "$name no contiene '$pattern' [$file]"
    fi
}

# assert_file_exists NAME FILE
assert_file_exists() {
    local name="$1"
    local file="$2"

    if [ -f "$file" ]; then
        pass "$name existe: $file"
    else
        fail "$name no existe: $file"
    fi
}

# assert_dir_exists NAME DIR
assert_dir_exists() {
    local name="$1"
    local dir="$2"

    if [ -d "$dir" ]; then
        pass "$name existe: $dir"
    else
        fail "$name no existe: $dir"
    fi
}

# assert_syntax NAME FILE
assert_syntax() {
    local name="$1"
    local file="$2"
    local err

    err=$(bash -n "$file" 2>&1)
    if [ $? -eq 0 ]; then
        pass "$name sintaxis OK"
    else
        fail "$name error de sintaxis: $err"
    fi
}

# assert_json_min_count NAME URL JSON_KEY MIN_COUNT [AUTH_HEADER]
# Cuenta ocurrencias de "KEY" en el JSON para estimar el numero de elementos
assert_json_min_count() {
    local name="$1"
    local url="$2"
    local key="$3"
    local min_count="$4"
    local auth_header="${5:-}"
    local body count

    if [ -n "$auth_header" ]; then
        body=$(curl -sk --connect-timeout 5 --max-time 10 \
            -H "$auth_header" "$url" 2>/dev/null)
    else
        body=$(curl -sk --connect-timeout 5 --max-time 10 "$url" 2>/dev/null)
    fi

    count=$(printf '%s' "$body" | grep -o "\"$key\"" | wc -l | tr -d ' ')

    if [ "$count" -ge "$min_count" ] 2>/dev/null; then
        pass "$name tiene $count ocurrencias de '$key' (minimo $min_count)"
    else
        fail "$name tiene $count ocurrencias de '$key' (esperado >= $min_count) [$url]"
    fi
}

# assert_env_var NAME FILE VAR
assert_env_var() {
    local name="$1"
    local file="$2"
    local var="$3"

    if grep -q "^${var}=" "$file" 2>/dev/null; then
        pass "$name: $var definida en $file"
    else
        fail "$name: $var no definida en $file"
    fi
}

# ─── Summary ──────────────────────────────────────────────────────────────────
print_summary() {
    local total=$((PASS + FAIL))
    echo ""
    printf "${BOLD}═══════════════════════════════════════${NC}\n"
    printf "${BOLD}  Resultado: %d/%d tests pasaron${NC}\n" "$PASS" "$total"
    if [ "$WARN" -gt 0 ]; then
        printf "  ${YELLOW}Advertencias: %d${NC}\n" "$WARN"
    fi
    if [ "$FAIL" -gt 0 ]; then
        printf "\n${RED}${BOLD}  Fallidos:${NC}\n"
        while IFS= read -r line; do
            printf "  ${RED}✗${NC} %s\n" "$line"
        done < "$ERRORS_FILE"
    fi
    printf "${BOLD}═══════════════════════════════════════${NC}\n\n"
    rm -f "$ERRORS_FILE"
    return "$FAIL"
}
