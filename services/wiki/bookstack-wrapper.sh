#!/bin/bash
# services/wiki/bookstack-wrapper.sh
# Se ejecuta como entrypoint del contenedor BookStack (antes que /init de linuxserver.io).
# Escribe /config/www/.env con los valores correctos para que init-bookstack-config
# no sobreescriba con el template de defaults (database_username, etc.).

mkdir -p /config/www

cat > /config/www/.env << EOF
APP_KEY=${APP_KEY}
APP_URL=http://wiki.${OPSN_DOMAIN:-opensec.lab}:${OPSN_WIKI_PORT:-6875}
DB_HOST=${DB_HOST:-opsn-wiki-db}
DB_DATABASE=${DB_DATABASE:-bookstackapp}
DB_USERNAME=${DB_USER:-bookstack}
DB_PASSWORD=${DB_PASS:-wiki_db_password}
STORAGE_TYPE=local
MAIL_DRIVER=smtp
MAIL_FROM_NAME=BookStack
MAIL_FROM=bookstack@opensec.lab
EOF

exec /init
