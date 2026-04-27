#!/bin/bash
# services/gitea/gitea-entrypoint.sh
# Wrapper del entrypoint de Gitea: arranca Gitea y crea el admin en primer boot.
# Se monta en el contenedor reemplazando el entrypoint original.

set -e

# Arrancar el entrypoint original de Gitea en segundo plano
/usr/bin/entrypoint "$@" &
GITEA_PID=$!

# Esperar a que la API de Gitea este disponible
MAX=60; I=0
until curl -sf "http://localhost:3000/api/v1/version" > /dev/null 2>&1; do
    I=$((I+1))
    [ $I -ge $MAX ] && echo "[gitea-entrypoint] Timeout esperando API" && break
    sleep 3
done

# Crear admin si no existe (idempotente via exit code)
ADMIN_USER="${OPSN_GITEA_ADMIN_USER:-admin}"
ADMIN_PASS="${OPSN_GITEA_PASSWORD:-Password}"
ADMIN_EMAIL="admin@${OPSN_DOMAIN:-opensec.lab}"

# Si hay mas de 1 linea (header + al menos 1 usuario), el admin ya existe
USER_COUNT=$(su git -c "gitea admin user list" 2>/dev/null | wc -l)
if [ "${USER_COUNT:-0}" -le 1 ]; then
    echo "[gitea-entrypoint] Creando usuario admin: $ADMIN_USER"
    su git -c "gitea admin user create \
        --admin \
        --username '$ADMIN_USER' \
        --password '$ADMIN_PASS' \
        --email '$ADMIN_EMAIL' \
        --must-change-password=false" 2>&1 && \
        echo "[gitea-entrypoint] Admin creado." || \
        echo "[gitea-entrypoint] Error al crear admin (puede ya existir)."
else
    echo "[gitea-entrypoint] Admin ya existe."
fi

# Esperar al proceso principal de Gitea
wait $GITEA_PID
