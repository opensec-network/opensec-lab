#!/usr/bin/env bash
# tests/static.sh
# Tests estáticos — no requieren Docker ni servicios corriendo.
# Valida: sintaxis de scripts, estructura de archivos, vars de entorno.
#
# Uso: bash tests/static.sh
# Desde la raiz del repo.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

. tests/lib/helpers.sh

echo ""
printf "${BOLD}OpenSec Lab — Tests Estáticos${NC}\n"
printf "Directorio: %s\n" "$(pwd)"

# ─────────────────────────────────────────────────────────────────────────────
section "Estructura de archivos"
# ─────────────────────────────────────────────────────────────────────────────

assert_file_exists "opensec-lab.sh"          "opensec-lab.sh"
assert_file_exists "docker-compose.yml"      "docker-compose.yml"
assert_file_exists "config/defaults.env"     "config/defaults.env"
assert_file_exists ".env.example"            ".env.example"
assert_file_exists "Makefile"                "Makefile"

assert_dir_exists "services/lib"       "services/lib"
assert_dir_exists "services/dns"       "services/dns"
assert_dir_exists "services/mail"      "services/mail"
assert_dir_exists "services/gophish"   "services/gophish"
assert_dir_exists "services/desktop"   "services/desktop"
assert_dir_exists "services/gitea"     "services/gitea"
assert_dir_exists "services/portal"      "services/portal"

assert_file_exists "services/lib/common.sh"                    "services/lib/common.sh"
assert_file_exists "services/dns/configure_dns.sh"             "services/dns/configure_dns.sh"
assert_file_exists "services/gophish/configure_gophish.sh"     "services/gophish/configure_gophish.sh"
assert_file_exists "services/gophish/templates/landing_page.html" "services/gophish/templates/landing_page.html"
assert_file_exists "services/gitea/configure_gitea.sh"         "services/gitea/configure_gitea.sh"
assert_file_exists "services/portal/generate_portal.sh"           "services/portal/generate_portal.sh"
assert_file_exists "services/portal/nginx.conf"                   "services/portal/nginx.conf"
assert_file_exists ".github/workflows/release.yml"             ".github/workflows/release.yml"
assert_file_exists ".github/workflows/build-mail.yml"          ".github/workflows/build-mail.yml"
assert_file_exists "services/api/Dockerfile"                   "services/api/Dockerfile"
assert_file_exists "services/api/app.py"                       "services/api/app.py"
assert_file_exists "services/api/requirements.txt"             "services/api/requirements.txt"
assert_file_exists "services/docs/mkdocs.yml"                  "services/docs/mkdocs.yml"
assert_file_exists "services/docs/nginx.conf"                  "services/docs/nginx.conf"
assert_file_exists "services/docs/docs/index.md"               "services/docs/docs/index.md"

# ─────────────────────────────────────────────────────────────────────────────
section "Sintaxis de scripts shell"
# ─────────────────────────────────────────────────────────────────────────────

for script in \
    opensec-lab.sh \
    services/lib/common.sh \
    services/dns/configure_dns.sh \
    services/gophish/configure_gophish.sh \
    services/gitea/configure_gitea.sh \
    services/portal/generate_portal.sh \
    services/mail/entrypoint.sh \
    services/desktop/custom-init.sh \
    services/desktop/init.sh
do
    if [ -f "$script" ]; then
        assert_syntax "$script" "$script"
    else
        warn "$script no existe (omitido)"
    fi
done

# ─────────────────────────────────────────────────────────────────────────────
section "Variables de entorno en defaults.env"
# ─────────────────────────────────────────────────────────────────────────────

DEFAULTS="config/defaults.env"

# Tier 0
for var in OPSN_DOMAIN OPSN_DNS_PASSWORD OPSN_MAIL_PASSWORD \
           OPSN_DNS_CONSOLE_PORT OPSN_DVWA_PORT OPSN_JUICE_PORT \
           OPSN_GOPHISH_ADMIN_PORT OPSN_DESKTOP_PORT OPSN_MAIL_WEBMAIL_PORT; do
    assert_env_var "defaults.env" "$DEFAULTS" "$var"
done

# Tier 1
for var in OPSN_WEBGOAT_PORT; do
    assert_env_var "defaults.env (Tier 1)" "$DEFAULTS" "$var"
done

# API y Docs
for var in OPSN_API_PORT OPSN_DOCS_PORT; do
    assert_env_var "defaults.env (API/Docs)" "$DEFAULTS" "$var"
done

# Tier 2
for var in OPSN_GITEA_PORT OPSN_GITEA_SSH_PORT OPSN_GITEA_PASSWORD \
           OPSN_PORTAL_PORT; do
    assert_env_var "defaults.env (Tier 2)" "$DEFAULTS" "$var"
done

# ─────────────────────────────────────────────────────────────────────────────
section "Contenido esperado en scripts"
# ─────────────────────────────────────────────────────────────────────────────

# Flag en landing page de GoPhish (comentario HTML)
assert_file_contains \
    "GoPhish landing page" \
    "services/gophish/templates/landing_page.html" \
    "OPSN{ph1sh1ng_aw4r3n3ss_ch4ll3ng3}"

# Flags en codigo vulnerable de Gitea
assert_file_contains \
    "Gitea — flag flask-app" \
    "services/gitea/configure_gitea.sh" \
    "OPSN{c0d3_r3v13w_vuln_f0und}"

assert_file_contains \
    "Gitea — flag insecure-api" \
    "services/gitea/configure_gitea.sh" \
    "OPSN{4p1_s3cur1ty_r3v13w}"

# Reglas Wazuh para la API (Plan 3)
for rule_id in 100060 100061 100062 100063 100064 100065; do
    assert_file_contains \
        "wazuh rule ${rule_id} existe" \
        "services/wazuh/rules/openseclab.xml" \
        "id=\"${rule_id}\""
done

assert_file_contains \
    "wazuh regla API base usa source opsn-api" \
    "services/wazuh/rules/openseclab.xml" \
    "opsn-api"

assert_file_contains \
    "wazuh regla API BOLA usa campo event" \
    "services/wazuh/rules/openseclab.xml" \
    "bola_attempt"

assert_file_contains \
    "wazuh regla mass assignment usa campo event" \
    "services/wazuh/rules/openseclab.xml" \
    "mass_assignment_attempt"

assert_file_contains \
    "wazuh regla broken function auth usa campo event" \
    "services/wazuh/rules/openseclab.xml" \
    "broken_function_auth"

# ─────────────────────────────────────────────────────────────────────────────
section "Docker Compose — estructura"
# ─────────────────────────────────────────────────────────────────────────────

COMPOSE="docker-compose.yml"

for service in opsn-dns opsn-dvwa opsn-juice-shop opsn-webgoat opsn-api \
               opsn-gophish opsn-desktop opsn-mail \
               opsn-gitea opsn-gitea-init \
               opsn-docs-build opsn-docs \
               opsn-portal opsn-portal-init; do
    assert_file_contains "compose tiene $service" "$COMPOSE" "container_name: $service"
done

# Verificar volumes declarados
for vol in opsn_dns_data opsn_dvwa_data opsn_gophish_data opsn_mail_data \
           opsn_gitea_data opsn_portal_html \
           opsn_api_logs opsn_docs_html; do
    assert_file_contains "compose volumen $vol" "$COMPOSE" "${vol}:"
done

# ─────────────────────────────────────────────────────────────────────────────
section "Docker Compose — validacion de sintaxis"
# ─────────────────────────────────────────────────────────────────────────────

if command -v docker > /dev/null 2>&1; then
    cp config/defaults.env .env 2>/dev/null
    err=$(docker compose config --quiet 2>&1)
    if [ $? -eq 0 ]; then
        pass "docker compose config --quiet"
    else
        fail "docker compose config: $err"
    fi
    rm -f .env
else
    warn "Docker no disponible — omitiendo validacion de compose"
fi

# ─────────────────────────────────────────────────────────────────────────────
section "release.yml — servicios empaquetados"
# ─────────────────────────────────────────────────────────────────────────────

RELEASE=".github/workflows/release.yml"
for svc in dns mail desktop gophish gitea portal api docs; do
    assert_file_contains "release.yml incluye $svc" "$RELEASE" "$svc"
done

# ─────────────────────────────────────────────────────────────────────────────
section "Makefile — targets"
# ─────────────────────────────────────────────────────────────────────────────

for svc in gitea portal; do
    assert_file_contains "Makefile SERVICES incluye $svc" "Makefile" "$svc"
done
assert_file_contains "Makefile SERVICES incluye api" "Makefile" "api"
assert_file_contains "Makefile SERVICES incluye docs" "Makefile" "docs"

assert_file_contains "Makefile tiene target validate" "Makefile" "validate:"
assert_file_contains "Makefile tiene target release"  "Makefile"  "release:"
assert_file_contains "Makefile tiene target test"     "Makefile"  "test"

# ─────────────────────────────────────────────────────────────────────────────
section "Idempotencia — funciones de init scripts"
# ─────────────────────────────────────────────────────────────────────────────

# Verificar que los init scripts tienen guards de idempotencia
assert_file_contains \
    "configure_gitea.sh — guard idempotencia (repo exists)" \
    "services/gitea/configure_gitea.sh" \
    "ya existe"

assert_file_contains \
    "configure_dns.sh — guard idempotencia (zona exists)" \
    "services/dns/configure_dns.sh" \
    "ya existe"

# ─────────────────────────────────────────────────────────────────────────────
print_summary
