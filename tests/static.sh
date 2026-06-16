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
assert_file_exists "api breach readiness helper"               "tests/api-breach-readiness.sh"

# Docs — escenario de phishing (api/web migrados a talleres web-hacking/api-breach)
assert_file_exists "docs scenarios/phishing.md"  "services/docs/docs/scenarios/phishing.md"

# Docs - talleres guiados
assert_file_exists "docs workshops/api-breach.md" "services/docs/docs/workshops/api-breach.md"
assert_file_exists "docs workshops/api-breach-instructor.md" "services/docs/docs/workshops/api-breach-instructor.md"
assert_file_exists "docs workshops/web-hacking.md" "services/docs/docs/workshops/web-hacking.md"
assert_file_exists "docs workshops/web-hacking-instructor.md" "services/docs/docs/workshops/web-hacking-instructor.md"
assert_file_exists "docs workshops/phishing.md" "services/docs/docs/workshops/phishing.md"
assert_file_exists "docs workshops/phishing-instructor.md" "services/docs/docs/workshops/phishing-instructor.md"
assert_file_exists "docs workshops/kill-chain.md" "services/docs/docs/workshops/kill-chain.md"
assert_file_exists "docs workshops/kill-chain-instructor.md" "services/docs/docs/workshops/kill-chain-instructor.md"
assert_file_exists "docs workshops/index.md (ruta)" "services/docs/docs/workshops/index.md"

# Docs — servicios (Plan 3)
for svc in dvwa juiceshop api wazuh gophish mail; do
    assert_file_exists "docs services/${svc}.md" "services/docs/docs/services/${svc}.md"
done

# Docs — cheatsheets (Plan 3)
for cs in curl nmap burp wazuh; do
    assert_file_exists "docs cheatsheets/${cs}.md" "services/docs/docs/cheatsheets/${cs}.md"
done

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
    tests/api-breach-readiness.sh \
    tests/web-hacking-readiness.sh \
    tests/phishing-readiness.sh \
    tests/kill-chain-readiness.sh \
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

# Reglas Suricata para la API (Plan 3)
for sid in 9000060 9000061 9000062 9000063; do
    assert_file_contains \
        "suricata SID ${sid} existe" \
        "services/suricata/rules/openseclab.rules" \
        "sid:${sid};"
done

# Portal redesign (Plan 3)
assert_file_contains \
    "portal tiene variable PORT_API" \
    "services/portal/generate_portal.sh" \
    'PORT_API='

assert_file_contains \
    "portal tiene variable PORT_DOCS" \
    "services/portal/generate_portal.sh" \
    'PORT_DOCS='

assert_file_contains \
    "portal tiene seccion de ataque (targets vulnerables)" \
    "services/portal/generate_portal.sh" \
    "targets vulnerables"

assert_file_contains \
    "portal tiene seccion Blue team" \
    "services/portal/generate_portal.sh" \
    "Blue team"

assert_file_contains \
    "portal muestra exploracion libre" \
    "services/portal/generate_portal.sh" \
    "Explorar libremente"

assert_file_contains \
    "portal muestra taller guiado" \
    "services/portal/generate_portal.sh" \
    "Talleres guiados"

assert_file_contains \
    "portal enlaza taller de APIs" \
    "services/portal/generate_portal.sh" \
    "Taller de API"

assert_file_contains \
    "portal enlaza taller Web Hacking" \
    "services/portal/generate_portal.sh" \
    "workshops/web-hacking/"

assert_file_contains \
    "portal enlaza taller Phishing" \
    "services/portal/generate_portal.sh" \
    "workshops/phishing/"

assert_file_contains \
    "portal enlaza taller Kill Chain" \
    "services/portal/generate_portal.sh" \
    "workshops/kill-chain/"

assert_file_contains \
    "portal conserva acceso directo a servicios" \
    "services/portal/generate_portal.sh" \
    "Acceso directo a servicios"

# La nueva direccion del producto no usa puntos, insignias ni rankings.
for forbidden in leaderboard leaderboards ranking rankings badge badges puntos puntaje insignias; do
    if rg -n -i "$forbidden" README.md ROADMAP.md USER_GUIDE.md services/docs/docs services/portal/generate_portal.sh 2>/dev/null \
        | rg -v -i "(\\.badge|class=\"badge)" >/dev/null 2>&1; then
        fail "terminologia de scoring reintroducida: ${forbidden}"
    else
        pass "terminologia de scoring ausente: ${forbidden}"
    fi
done

# Variables eliminadas en plan1 no deben estar en el portal
for dead_var in PORT_CRAPI PORT_PORTAINER PORT_WIKI PASS_PORTAINER PORT_GITEA PORT_WEBGOAT; do
    if grep -q "${dead_var}" services/portal/generate_portal.sh 2>/dev/null; then
        fail "portal todavia referencia variable eliminada: ${dead_var}"
    else
        pass "portal no referencia variable eliminada: ${dead_var}"
    fi
done

# MkDocs nav (Plan 3)
assert_file_contains \
    "mkdocs.yml tiene nav de escenarios" \
    "services/docs/mkdocs.yml" \
    "scenarios/phishing.md"

assert_file_contains \
    "mkdocs.yml tiene nav de servicios" \
    "services/docs/mkdocs.yml" \
    "services/dvwa.md"

assert_file_contains \
    "mkdocs.yml tiene nav de cheatsheets" \
    "services/docs/mkdocs.yml" \
    "cheatsheets/curl.md"

assert_file_contains \
    "mkdocs.yml tiene nav de talleres" \
    "services/docs/mkdocs.yml" \
    "Talleres"

assert_file_contains \
    "mkdocs.yml enlaza taller api-breach" \
    "services/docs/mkdocs.yml" \
    "workshops/api-breach.md"

assert_file_contains \
    "mkdocs.yml enlaza guia de instructor api-breach" \
    "services/docs/mkdocs.yml" \
    "workshops/api-breach-instructor.md"

assert_file_contains \
    "mkdocs nav incluye web-hacking" \
    "services/docs/mkdocs.yml" \
    "workshops/web-hacking.md"

assert_file_contains \
    "mkdocs nav incluye phishing" \
    "services/docs/mkdocs.yml" \
    "workshops/phishing.md"

assert_file_contains \
    "mkdocs nav incluye kill-chain" \
    "services/docs/mkdocs.yml" \
    "workshops/kill-chain.md"

assert_file_exists \
    "readiness web-hacking" \
    "tests/web-hacking-readiness.sh"

assert_file_exists \
    "readiness phishing" \
    "tests/phishing-readiness.sh"

assert_file_exists \
    "readiness kill-chain" \
    "tests/kill-chain-readiness.sh"

assert_file_contains \
    "script ofrece modo taller API Breach" \
    "opensec-lab.sh" \
    "taller_api_breach"

assert_file_contains \
    "script expone doctor del taller" \
    "opensec-lab.sh" \
    "doctor_taller"

assert_file_contains \
    "script verifica colisiones de puertos del host" \
    "opensec-lab.sh" \
    "verificar_puertos_host"

assert_file_contains \
    "script advierte exposicion de red" \
    "opensec-lab.sh" \
    "advertir_exposicion_red"

assert_file_contains \
    "script ofrece lab doctor general" \
    "opensec-lab.sh" \
    "lab_doctor"

assert_file_contains \
    "script ofrece reset del taller" \
    "opensec-lab.sh" \
    "reset_taller"

assert_file_contains \
    "prerequisitos verifican disco libre" \
    "opensec-lab.sh" \
    "Disco libre"

assert_file_contains \
    "wazuh init libera read-only block" \
    "services/wazuh/configure_wazuh.sh" \
    "read_only_allow_delete"

assert_file_contains \
    "compose bindea puertos via OPSN_BIND_ADDR" \
    "docker-compose.yml" \
    "OPSN_BIND_ADDR"

assert_file_contains \
    "defaults.env define OPSN_BIND_ADDR seguro por defecto" \
    "config/defaults.env" \
    "OPSN_BIND_ADDR=127.0.0.1"

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
