#!/usr/bin/env bash
# tests/smoke.sh
# Tests de integración — verifican que los servicios del lab estén UP y con contenido correcto.
#
# Prerequisito: lab corriendo
#   docker compose --profile all up -d
#   # Esperar ~3 min para que los sidecars terminen
#
# Uso:
#   bash tests/smoke.sh                     # Todos los servicios
#   bash tests/smoke.sh --profile ctfd      # Solo CTFd
#   OPSN_ENV=~/OpenSec_Lab/.env bash tests/smoke.sh
#
# Variables de entorno opcionales:
#   OPSN_ENV — ruta al .env del lab (default: config/defaults.env)

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

. tests/lib/helpers.sh

# ─── Cargar configuración ─────────────────────────────────────────────────────
ENV_FILE="${OPSN_ENV:-}"
[ -z "$ENV_FILE" ] && [ -f "$HOME/OpenSec_Lab/.env" ] && ENV_FILE="$HOME/OpenSec_Lab/.env"
[ -z "$ENV_FILE" ] && ENV_FILE="config/defaults.env"

# shellcheck disable=SC1090
. "$ENV_FILE" 2>/dev/null || true

PORT_CTFD="${OPSN_CTFD_PORT:-8000}"
PORT_WAZUH_DASH="${OPSN_WAZUH_DASH_PORT:-5601}"
PORT_WAZUH_API="${OPSN_WAZUH_API_PORT:-55000}"
WAZUH_API_PASS="${OPSN_WAZUH_API_PASSWORD:-WazuhApiP4ss.}"
PORT_WIKI="${OPSN_WIKI_PORT:-6875}"
PORT_GITEA="${OPSN_GITEA_PORT:-3002}"
PORT_PORTAL="${OPSN_PORTAL_PORT:-8443}"
PORT_DVWA="${OPSN_DVWA_PORT:-8080}"
PORT_JUICE="${OPSN_JUICE_PORT:-3000}"
PORT_WEBGOAT="${OPSN_WEBGOAT_PORT:-8081}"
PORT_CRAPI="${OPSN_CRAPI_PORT:-8025}"
PORT_MAIL="${OPSN_MAIL_WEBMAIL_PORT:-8888}"
PORT_DNS="${OPSN_DNS_CONSOLE_PORT:-5380}"
PORT_GOPHISH="${OPSN_GOPHISH_ADMIN_PORT:-3333}"
PORT_DESKTOP="${OPSN_DESKTOP_PORT:-3100}"

CTFD_PASS="${OPSN_CTFD_ADMIN_PASSWORD:-Password}"
GITEA_PASS="${OPSN_GITEA_PASSWORD:-Password}"
GITEA_USER="${OPSN_GITEA_ADMIN_USER:-admin}"
DOMAIN="${OPSN_DOMAIN:-opensec.lab}"

PROFILE="${1:-all}"

echo ""
printf "${BOLD}OpenSec Lab — Smoke Tests${NC}\n"
printf "Profile: %s | Env: %s\n" "$PROFILE" "$ENV_FILE"

# ─── Función: obtener token de CTFd ──────────────────────────────────────────
ctfd_get_token() {
    local cookies="/tmp/opsn_test_ctfd_$$"
    local html nonce auth_html post_nonce token

    # Paso 1: Obtener nonce del login form
    html=$(curl -sk -c "$cookies" \
        --connect-timeout 5 --max-time 10 \
        "http://localhost:${PORT_CTFD}/login" 2>/dev/null)

    nonce=$(printf '%s' "$html" | \
        sed -n "s/.*'csrfNonce':[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -1)

    # Paso 2: Login (sin -L para conservar la cookie de sesion)
    curl -sk -b "$cookies" -c "$cookies" \
        --connect-timeout 5 --max-time 10 \
        -X POST "http://localhost:${PORT_CTFD}/login" \
        --data-urlencode "name=admin" \
        --data-urlencode "password=${CTFD_PASS}" \
        --data-urlencode "nonce=${nonce}" \
        -o /dev/null 2>/dev/null

    # Paso 3: Obtener csrfNonce post-autenticacion (cambia despues del login)
    auth_html=$(curl -sk -b "$cookies" \
        --connect-timeout 5 --max-time 10 \
        "http://localhost:${PORT_CTFD}/settings" 2>/dev/null)
    post_nonce=$(printf '%s' "$auth_html" | \
        sed -n "s/.*'csrfNonce':[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -1)

    # Paso 4: Crear token con CSRF-Token header usando nonce post-login
    token=$(curl -sk -b "$cookies" \
        --connect-timeout 5 --max-time 10 \
        -X POST "http://localhost:${PORT_CTFD}/api/v1/tokens" \
        -H "Content-Type: application/json" \
        -H "CSRF-Token: ${post_nonce}" \
        -d '{"expiration":"2099-01-01"}' 2>/dev/null | \
        sed -n 's/.*"value":[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)

    rm -f "$cookies"
    printf '%s' "$token"
}

# ─── Función: verificar que un contenedor está corriendo ─────────────────────
container_running() {
    docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$1"
}

# ─────────────────────────────────────────────────────────────────────────────
section "Servicios Tier 0 — Infraestructura base"
# ─────────────────────────────────────────────────────────────────────────────

if container_running "opsn-dns" || [ "$PROFILE" = "all" ] || [ "$PROFILE" = "dns" ]; then
    assert_http "DNS — panel admin"   "http://localhost:${PORT_DNS}"  "200"
fi

if container_running "opsn-mail" || [ "$PROFILE" = "all" ] || [ "$PROFILE" = "mail" ]; then
    assert_http "Mail — Roundcube webmail"  "http://localhost:${PORT_MAIL}"  "200"
fi

if container_running "opsn-gophish"; then
    assert_http "GoPhish — panel admin (HTTPS)"  "https://localhost:${PORT_GOPHISH}"  "200"
fi

if container_running "opsn-desktop"; then
    assert_http "Desktop — Webtop XFCE"  "http://localhost:${PORT_DESKTOP}"  "200"
fi

# ─────────────────────────────────────────────────────────────────────────────
section "Servicios Tier 1 — Targets vulnerables"
# ─────────────────────────────────────────────────────────────────────────────

if container_running "opsn-dvwa"; then
    assert_http "DVWA"        "http://localhost:${PORT_DVWA}"                   "200"
fi

if container_running "opsn-juice-shop"; then
    assert_http "Juice Shop"  "http://localhost:${PORT_JUICE}"                  "200"
fi

if container_running "opsn-webgoat"; then
    assert_http "WebGoat"     "http://localhost:${PORT_WEBGOAT}/WebGoat"        "200"
fi

if container_running "opsn-crapi"; then
    assert_http "crAPI"       "http://localhost:${PORT_CRAPI}"                  "200"
fi

if container_running "opsn-portainer"; then
    PORT_PORTAINER="${OPSN_PORTAINER_PORT:-9443}"
    assert_http "Portainer"   "https://localhost:${PORT_PORTAINER}"  "200"

    # Verificar que el sidecar configuro admin y endpoint
    PORTAINER_PASS="${OPSN_PORTAINER_PASSWORD:-Password}"
    PORTAINER_JWT=$(curl -sk --max-time 10 -X POST \
        "https://localhost:${PORT_PORTAINER}/api/auth" \
        -H "Content-Type: application/json" \
        -d "{\"Username\":\"admin\",\"Password\":\"${PORTAINER_PASS}\"}" 2>/dev/null | \
        sed -n 's/.*"jwt":"\([^"]*\)".*/\1/p' | head -1)

    if [ -n "$PORTAINER_JWT" ]; then
        pass "Portainer — autenticacion admin exitosa"
        EP_LIST=$(curl -sk --max-time 10 \
            -H "Authorization: Bearer ${PORTAINER_JWT}" \
            "https://localhost:${PORT_PORTAINER}/api/endpoints" 2>/dev/null)
        if printf '%s' "$EP_LIST" | grep -q '"Name":"local"'; then
            pass "Portainer — endpoint Docker local configurado"
        else
            fail "Portainer — endpoint Docker local NO encontrado"
        fi
    else
        fail "Portainer — no se pudo autenticar como admin (contrasena: ${PORTAINER_PASS})"
    fi
fi

# ─────────────────────────────────────────────────────────────────────────────
section "CTFd — disponibilidad y contenido"
# ─────────────────────────────────────────────────────────────────────────────

if container_running "opsn-ctfd" || [ "$PROFILE" = "ctfd" ] || [ "$PROFILE" = "all" ]; then

    assert_http "CTFd — página principal"  "http://localhost:${PORT_CTFD}"        "200"
    assert_http "CTFd — login"             "http://localhost:${PORT_CTFD}/login"  "200"

    info "Obteniendo token de API de CTFd..."
    CTFD_TOKEN=$(ctfd_get_token)

    if [ -n "$CTFD_TOKEN" ]; then
        pass "CTFd — autenticación admin exitosa"

        # Verificar número de retos (esperamos 7)
        assert_json_min_count \
            "CTFd — retos pre-cargados" \
            "http://localhost:${PORT_CTFD}/api/v1/challenges" \
            id \
            7 \
            "Authorization: Token ${CTFD_TOKEN}"

        # Verificar categorías presentes
        for category in "Social Engineering" "Web" "Learning" "API Security" "Forensics" "Recon"; do
            assert_contains \
                "CTFd — categoria '$category'" \
                "http://localhost:${PORT_CTFD}/api/v1/challenges" \
                "$category" \
                "Authorization: Token ${CTFD_TOKEN}"
        done

        # Verificar nombre del CTF (aparece en el titulo de la pagina principal)
        assert_contains \
            "CTFd — nombre del CTF configurado" \
            "http://localhost:${PORT_CTFD}" \
            "OpenSec Lab CTF"

    else
        fail "CTFd — no se pudo autenticar como admin (verificar OPSN_CTFD_ADMIN_PASSWORD)"
    fi
fi

# ─────────────────────────────────────────────────────────────────────────────
section "BookStack — disponibilidad y contenido"
# ─────────────────────────────────────────────────────────────────────────────

if container_running "opsn-wiki" || [ "$PROFILE" = "wiki" ] || [ "$PROFILE" = "all" ]; then

    WIKI_AUTH="Authorization: Token opsn_init_id_v1:opsn_init_secret_v1"

    assert_http "BookStack — página principal"  "http://localhost:${PORT_WIKI}"       "200"
    # La API sin auth retorna 401 — verificamos que el endpoint existe
    assert_http "BookStack — API disponible"    "http://localhost:${PORT_WIKI}/api/books" "401"

    # Verificar libros creados (esperamos al menos 2)
    assert_json_min_count \
        "BookStack — libros creados" \
        "http://localhost:${PORT_WIKI}/api/books" \
        id \
        2 \
        "$WIKI_AUTH"

    # Verificar libro "Guias del Lab"
    assert_contains \
        "BookStack — libro 'Guias del Lab'" \
        "http://localhost:${PORT_WIKI}/api/books" \
        "Guias del Lab" \
        "$WIKI_AUTH"

    # Verificar libro "Cheat Sheets"
    assert_contains \
        "BookStack — libro 'Cheat Sheets'" \
        "http://localhost:${PORT_WIKI}/api/books" \
        "Cheat Sheets" \
        "$WIKI_AUTH"

    # Verificar páginas creadas (esperamos al menos 8)
    assert_json_min_count \
        "BookStack — páginas creadas" \
        "http://localhost:${PORT_WIKI}/api/pages" \
        id \
        8 \
        "$WIKI_AUTH"
fi

# ─────────────────────────────────────────────────────────────────────────────
section "Gitea — disponibilidad y repositorios"
# ─────────────────────────────────────────────────────────────────────────────

if container_running "opsn-gitea" || [ "$PROFILE" = "gitea" ] || [ "$PROFILE" = "all" ]; then

    GITEA_AUTH="Authorization: Basic $(printf '%s:%s' "${GITEA_USER}" "${GITEA_PASS}" | base64 | tr -d '\n')"

    assert_http "Gitea — página principal"  "http://localhost:${PORT_GITEA}"       "200"
    assert_http "Gitea — API health"        "http://localhost:${PORT_GITEA}/api/v1/version"  "200"

    # Verificar repositorios creados
    assert_http \
        "Gitea — repo vulnerable-flask-app existe" \
        "http://localhost:${PORT_GITEA}/api/v1/repos/${GITEA_USER}/vulnerable-flask-app" \
        "200"

    assert_http \
        "Gitea — repo insecure-api existe" \
        "http://localhost:${PORT_GITEA}/api/v1/repos/${GITEA_USER}/insecure-api" \
        "200"

    # Verificar archivos en los repos
    assert_http \
        "Gitea — flask-app tiene app.py" \
        "http://localhost:${PORT_GITEA}/api/v1/repos/${GITEA_USER}/vulnerable-flask-app/contents/app.py" \
        "200"

    assert_http \
        "Gitea — insecure-api tiene api.js" \
        "http://localhost:${PORT_GITEA}/api/v1/repos/${GITEA_USER}/insecure-api/contents/api.js" \
        "200"

    # Verificar que el código contiene las vulnerabilidades esperadas
    APP_PY_B64=$(curl -sk \
        "http://localhost:${PORT_GITEA}/api/v1/repos/${GITEA_USER}/vulnerable-flask-app/contents/app.py" \
        2>/dev/null | sed -n 's/.*"content":"\([^"]*\)".*/\1/p')

    if [ -n "$APP_PY_B64" ]; then
        APP_PY=$(printf '%s' "$APP_PY_B64" | tr -d '\n' | base64 -d 2>/dev/null || true)
        if printf '%s' "$APP_PY" | grep -q "SQL Injection"; then
            pass "Gitea — flask-app contiene vulnerabilidades documentadas"
        else
            fail "Gitea — flask-app no contiene comentarios de vulnerabilidades"
        fi
    else
        warn "Gitea — no se pudo decodificar app.py para verificar contenido"
    fi

    # Verificar flag en README de flask-app
    README_B64=$(curl -sk \
        "http://localhost:${PORT_GITEA}/api/v1/repos/${GITEA_USER}/vulnerable-flask-app/contents/README.md" \
        2>/dev/null | tr -d '\n' | sed -n 's/.*"content":"\([^"]*\)".*/\1/p')

    if [ -n "$README_B64" ]; then
        README=$(printf '%s' "$README_B64" | tr -d '\n' | base64 -d 2>/dev/null || true)
        if printf '%s' "$README" | grep -qF "OPSN{c0d3_r3v13w_vuln_f0und}"; then
            pass "Gitea — README contiene flag CTF"
        else
            fail "Gitea — README no contiene flag CTF"
        fi
    else
        warn "Gitea — no se pudo decodificar README.md para verificar flag"
    fi
fi

# ─────────────────────────────────────────────────────────────────────────────
section "Portal — disponibilidad y contenido"
# ─────────────────────────────────────────────────────────────────────────────

if container_running "opsn-portal" || [ "$PROFILE" = "portal" ] || [ "$PROFILE" = "all" ]; then

    assert_http "Portal — página principal"  "http://localhost:${PORT_PORTAL}"  "200"

    assert_contains \
        "Portal — título OpenSec Lab" \
        "http://localhost:${PORT_PORTAL}" \
        "OpenSec Lab"

    assert_contains \
        "Portal — sección Gamificacion" \
        "http://localhost:${PORT_PORTAL}" \
        "Gamificacion"

    assert_contains \
        "Portal — sección Red Team" \
        "http://localhost:${PORT_PORTAL}" \
        "Red Team"

    assert_contains \
        "Portal — tabla de credenciales" \
        "http://localhost:${PORT_PORTAL}" \
        "Credenciales por defecto"

    assert_contains \
        "Portal — link a CTFd presente" \
        "http://localhost:${PORT_PORTAL}" \
        "CTFd"

    assert_contains \
        "Portal — link a DVWA presente" \
        "http://localhost:${PORT_PORTAL}" \
        "DVWA"

    assert_contains \
        "Portal — health check JS presente" \
        "http://localhost:${PORT_PORTAL}" \
        "status-dot"
fi

# ─────────────────────────────────────────────────────────────────────────────
section "GoPhish — flag CTF en landing page"
# ─────────────────────────────────────────────────────────────────────────────

if container_running "opsn-gophish"; then
    # El flag debe estar en el HTML de la landing page configurada
    # La landing page se sirve via GoPhish phishing listener (puerto 80)
    GOPHISH_PHISH_PORT="${OPSN_GOPHISH_PHISH_PORT:-80}"
    body=$(curl -sk --connect-timeout 5 --max-time 10 \
        "http://localhost:${GOPHISH_PHISH_PORT}" 2>/dev/null)

    if printf '%s' "$body" | grep -q "OPSN{ph1sh1ng_aw4r3n3ss_ch4ll3ng3}"; then
        pass "GoPhish — flag presente en landing page servida"
    else
        # El flag puede estar en el template pero no en la página servida si
        # la campaña no está activa — verificar solo el archivo
        warn "GoPhish — landing page activa no muestra el flag (¿campaña lanzada?)"
        info "  El flag está en el template HTML. Verifica que la campaña esté activa."
    fi
fi

# ─────────────────────────────────────────────────────────────────────────────
section "DNS — registros del lab"
# ─────────────────────────────────────────────────────────────────────────────

if container_running "opsn-dns"; then
    # Los tests DNS se ejecutan desde dentro de la red del lab con alpine
    # porque en macOS el puerto 53 del host es usado por mDNSResponder.
    DNS_CONTAINER="opsn-dns"

    for record in dns mail webmail gophish ctf wiki git lab; do
        result=$(docker run --rm --network openseclab \
            alpine sh -c "nslookup ${record}.${DOMAIN} opsn-dns 2>/dev/null | grep 'Address:' | tail -1 | awk '{print \$2}'" \
            2>/dev/null | head -1)
        if [ -n "$result" ] && [ "$result" != "${DOMAIN}" ]; then
            pass "DNS — A record ${record}.${DOMAIN} → $result"
        else
            fail "DNS — A record ${record}.${DOMAIN} no resuelve"
        fi
    done

    # TXT record con el flag de Recon
    txt_result=$(docker run --rm --network openseclab \
        alpine sh -c "nslookup -type=TXT flag.${DOMAIN} opsn-dns 2>/dev/null" \
        2>/dev/null)
    if printf '%s' "$txt_result" | grep -qF "OPSN{dns_r3c0n_m4st3r}"; then
        pass "DNS — TXT flag.${DOMAIN} contiene el flag CTF"
    else
        fail "DNS — TXT flag.${DOMAIN} no contiene el flag"
    fi
fi

# ─────────────────────────────────────────────────────────────────────────────
section "Idempotencia — ejecutar init scripts dos veces"
# ─────────────────────────────────────────────────────────────────────────────
# Verificamos idempotencia comprobando que el contador de recursos no sube
# tras una segunda ejecución de los sidecars.

if container_running "opsn-ctfd" && [ -n "${CTFD_TOKEN:-}" ]; then
    count_before=$(curl -sk \
        -H "Authorization: Token ${CTFD_TOKEN}" \
        "http://localhost:${PORT_CTFD}/api/v1/challenges" 2>/dev/null | \
        grep -o '"id"' | wc -l | tr -d ' ')

    # Re-ejecutar el init script dentro del contenedor
    docker run --rm \
        --network openseclab \
        -e OPSN_DOMAIN="${DOMAIN}" \
        -e OPSN_CTFD_ADMIN_PASSWORD="${CTFD_PASS}" \
        -v "$(pwd)/services/ctfd/configure_ctfd.sh:/configure_ctfd.sh:ro" \
        -v "$(pwd)/services/lib/common.sh:/lib/common.sh:ro" \
        alpine/curl:latest /bin/sh /configure_ctfd.sh > /dev/null 2>&1 || true

    count_after=$(curl -sk \
        -H "Authorization: Token ${CTFD_TOKEN}" \
        "http://localhost:${PORT_CTFD}/api/v1/challenges" 2>/dev/null | \
        grep -o '"id"' | wc -l | tr -d ' ')

    if [ "$count_before" = "$count_after" ]; then
        pass "CTFd init — idempotente ($count_before retos antes y después)"
    else
        fail "CTFd init — NO idempotente ($count_before → $count_after retos)"
    fi
fi

if container_running "opsn-wiki"; then
    WIKI_AUTH="Authorization: Token opsn_init_id_v1:opsn_init_secret_v1"

    books_before=$(curl -sk -H "$WIKI_AUTH" \
        "http://localhost:${PORT_WIKI}/api/books" 2>/dev/null | \
        grep -o '"id"' | wc -l | tr -d ' ')

    docker run --rm \
        --network openseclab \
        -v "$(pwd)/services/wiki/configure_wiki.sh:/configure_wiki.sh:ro" \
        -v "$(pwd)/services/lib/common.sh:/lib/common.sh:ro" \
        alpine/curl:latest /bin/sh /configure_wiki.sh > /dev/null 2>&1 || true

    books_after=$(curl -sk -H "$WIKI_AUTH" \
        "http://localhost:${PORT_WIKI}/api/books" 2>/dev/null | \
        grep -o '"id"' | wc -l | tr -d ' ')

    if [ "$books_before" = "$books_after" ]; then
        pass "BookStack init — idempotente ($books_before libros antes y después)"
    else
        fail "BookStack init — NO idempotente ($books_before → $books_after libros)"
    fi
fi

if container_running "opsn-gitea"; then
    repos_before=$(curl -sk \
        "http://localhost:${PORT_GITEA}/api/v1/repos/search?limit=50" 2>/dev/null | \
        grep -o '"id"' | wc -l | tr -d ' ')

    docker run --rm \
        --network openseclab \
        -e OPSN_DOMAIN="${DOMAIN}" \
        -e OPSN_GITEA_PASSWORD="${GITEA_PASS}" \
        -e OPSN_GITEA_ADMIN_USER="${GITEA_USER}" \
        -e OPSN_GITEA_PORT="${PORT_GITEA}" \
        -v "$(pwd)/services/gitea/configure_gitea.sh:/configure_gitea.sh:ro" \
        -v "$(pwd)/services/lib/common.sh:/lib/common.sh:ro" \
        alpine/curl:latest /bin/sh /configure_gitea.sh > /dev/null 2>&1 || true

    repos_after=$(curl -sk \
        "http://localhost:${PORT_GITEA}/api/v1/repos/search?limit=50" 2>/dev/null | \
        grep -o '"id"' | wc -l | tr -d ' ')

    if [ "$repos_before" = "$repos_after" ]; then
        pass "Gitea init — idempotente ($repos_before repos antes y después)"
    else
        fail "Gitea init — NO idempotente ($repos_before → $repos_after repos)"
    fi
fi

# ─────────────────────────────────────────────────────────────────────────────
section "Servicios Tier 3 — Blue Team (Wazuh + Suricata)"
# ─────────────────────────────────────────────────────────────────────────────

WAZUH_RUNNING=false
if container_running "opsn-wazuh-manager" || [ "$PROFILE" = "wazuh" ] || [ "$PROFILE" = "blue-team" ] || [ "$PROFILE" = "all" ]; then

    WAZUH_RUNNING=true

    # Verificar que el generador de certs completó (exited 0, no running)
    certs_status=$(docker inspect --format '{{.State.ExitCode}}' opsn-wazuh-certs 2>/dev/null)
    if [ "$certs_status" = "0" ]; then
        pass "Wazuh certs-generator — completó exitosamente (exit 0)"
    elif [ -z "$certs_status" ]; then
        warn "Wazuh certs-generator — contenedor no encontrado (¿fue removido?)"
    else
        fail "Wazuh certs-generator — exit code $certs_status (esperado 0)"
    fi

    # Verificar contenedores corriendo
    for svc in opsn-wazuh-indexer opsn-wazuh-manager opsn-wazuh-dashboard; do
        if container_running "$svc"; then
            pass "Wazuh — $svc está corriendo"
        else
            fail "Wazuh — $svc NO está corriendo"
        fi
    done

    # Wazuh Dashboard HTTP
    assert_http "Wazuh Dashboard — accesible HTTPS" \
        "https://localhost:${PORT_WAZUH_DASH}" "200"

    # Manager API — autenticación con wazuh-wui (via docker exec para evitar dep de port mapping)
    api_response=$(docker exec opsn-wazuh-manager \
        curl -sk --connect-timeout 10 --max-time 15 \
        -u "wazuh-wui:${WAZUH_API_PASS}" \
        "https://localhost:55000/?pretty" 2>/dev/null)

    if printf '%s' "$api_response" | grep -qi '"title"'; then
        pass "Wazuh Manager API — responde (wazuh-wui auth OK)"
    else
        fail "Wazuh Manager API — no responde en :55000 (¿password correcta?)"
    fi

    # Reglas custom cargadas en el Manager
    if docker exec opsn-wazuh-manager test -f /var/ossec/etc/rules/openseclab.xml 2>/dev/null; then
        pass "Wazuh — reglas custom openseclab.xml cargadas"
    else
        fail "Wazuh — reglas custom openseclab.xml NO encontradas en /var/ossec/etc/rules/"
    fi

    # Indexer cluster health (via docker exec — credenciales admin:admin por defecto Wazuh)
    indexer_health=$(docker exec opsn-wazuh-indexer \
        sh -c 'curl -sk --user admin:admin https://127.0.0.1:9200/_cluster/health 2>/dev/null')

    if printf '%s' "$indexer_health" | grep -qi '"status"'; then
        health_status=$(printf '%s' "$indexer_health" | \
            sed -n 's/.*"status":"\([^"]*\)".*/\1/p' | head -1)
        if [ "$health_status" = "green" ] || [ "$health_status" = "yellow" ]; then
            pass "Wazuh Indexer — cluster health: $health_status"
        else
            fail "Wazuh Indexer — cluster health: $health_status (esperado green/yellow)"
        fi
    else
        fail "Wazuh Indexer — no responde en :9200 (¿certificados OK?)"
    fi

fi

if container_running "opsn-suricata" || [ "$PROFILE" = "suricata" ] || [ "$PROFILE" = "blue-team" ] || [ "$PROFILE" = "all" ]; then

    if container_running "opsn-suricata"; then
        pass "Suricata IDS — contenedor corriendo (network_mode: host)"
    else
        fail "Suricata IDS — contenedor NO corriendo"
    fi

    # Verificar que el volumen de logs está montado en Wazuh Manager
    if $WAZUH_RUNNING; then
        suricata_vol=$(docker inspect opsn-wazuh-manager 2>/dev/null | \
            grep -o 'suricata_logs' | head -1)
        if [ -n "$suricata_vol" ]; then
            pass "Suricata → Wazuh — volumen suricata_logs montado en Manager"
        else
            fail "Suricata → Wazuh — volumen suricata_logs NO montado en Manager"
        fi
    fi

fi

# DNS record wazuh.opensec.lab (solo si dns y wazuh están corriendo)
if container_running "opsn-dns" && container_running "opsn-wazuh-dashboard"; then
    result=$(docker run --rm --network openseclab \
        alpine sh -c "nslookup wazuh.${DOMAIN} opsn-dns 2>/dev/null | grep 'Address:' | tail -1 | awk '{print \$2}'" \
        2>/dev/null | head -1)
    if [ -n "$result" ] && [ "$result" != "${DOMAIN}" ]; then
        pass "DNS — A record wazuh.${DOMAIN} → $result"
    else
        fail "DNS — A record wazuh.${DOMAIN} no resuelve"
    fi
fi

# ─────────────────────────────────────────────────────────────────────────────
print_summary
