#!/bin/bash
# Descarga los archivos de build de opsn-mail desde GitHub
REPO_BASE="https://raw.githubusercontent.com/opensec-network/opsn-mail/refs/heads/main"

# Archivos raíz
wget -q --show-progress -O Dockerfile "$REPO_BASE/Dockerfile"
wget -q --show-progress -O entrypoint.sh "$REPO_BASE/entrypoint.sh"
wget -q --show-progress -O supervisord.conf "$REPO_BASE/supervisord.conf"

# Directorios de configuración
mkdir -p postfix dovecot nginx/sites-available roundcube

wget -q --show-progress -O postfix/main.cf "$REPO_BASE/postfix/main.cf"
wget -q --show-progress -O dovecot/dovecot.conf "$REPO_BASE/dovecot/dovecot.conf"
wget -q --show-progress -O nginx/nginx.conf "$REPO_BASE/nginx/nginx.conf"
wget -q --show-progress -O nginx/sites-available/roundcube.conf "$REPO_BASE/nginx/sites-available/roundcube.conf"
wget -q --show-progress -O roundcube/config.inc.php "$REPO_BASE/roundcube/config.inc.php"

chmod +x entrypoint.sh
