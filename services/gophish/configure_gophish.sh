#!/bin/sh
# configure_gophish.sh — Configura GoPhish via API REST
# Se ejecuta como contenedor sidecar (opsn-gophish-init) al iniciar el lab.
# Es idempotente: verifica si cada recurso existe antes de crearlo.

set -e

# ─────────────────────────────────────────────────────────────────
# Variables de entorno — personaliza en .env o docker-compose.yml
# ─────────────────────────────────────────────────────────────────
OPSN_DOMAIN="${OPSN_DOMAIN:-opensec.lab}"
GOPHISH_HOST="opsn-gophish"
GOPHISH_PORT="3333"
GOPHISH_URL="https://${GOPHISH_HOST}:${GOPHISH_PORT}"

OPSN_MAIL_HOST="${OPSN_MAIL_HOST:-opsn-mail}"
OPSN_GOPHISH_SMTP_PORT="${OPSN_GOPHISH_SMTP_PORT:-25}"
OPSN_GOPHISH_PASSWORD="${OPSN_GOPHISH_PASSWORD:-Password}"

# Identidad de la empresa ficticia
OPSN_GOPHISH_COMPANY_NAME="${OPSN_GOPHISH_COMPANY_NAME:-Acme Corp}"
OPSN_GOPHISH_FROM_NAME="${OPSN_GOPHISH_FROM_NAME:-Soporte IT}"
OPSN_GOPHISH_SUPPORT_TEAM="${OPSN_GOPHISH_SUPPORT_TEAM:-Equipo de Seguridad IT}"
OPSN_GOPHISH_EMAIL_SUBJECT="${OPSN_GOPHISH_EMAIL_SUBJECT:-Accion requerida: Restablece tu contrasena corporativa}"

# Nombres de recursos — derivados del nombre de empresa para consistencia
SENDING_PROFILE_NAME="${OPSN_GOPHISH_COMPANY_NAME} Mail Server"
EMAIL_TEMPLATE_NAME="${OPSN_GOPHISH_COMPANY_NAME} Password Reset"
LANDING_PAGE_NAME="${OPSN_GOPHISH_COMPANY_NAME} Login Page"
USER_GROUP_NAME="${OPSN_GOPHISH_COMPANY_NAME} Lab Users"

LOG() { echo "[gophish-init] $*"; }

# ─────────────────────────────────────────────────────────────────
# Logo: convierte el SVG a data URI base64 para embeber en HTML
# Compatible con la mayoria de clientes de correo y navegadores
# ─────────────────────────────────────────────────────────────────
LOGO_FILE="/config/assets/logo.svg"
LOGO_IMG=""
if [ -f "$LOGO_FILE" ]; then
    LOGO_B64=$(base64 < "$LOGO_FILE" | tr -d '\n')
    LOGO_IMG="data:image/svg+xml;base64,${LOGO_B64}"
    LOG "Logo cargado desde ${LOGO_FILE}."
else
    LOG "AVISO: No se encontro el logo en ${LOGO_FILE}. Las plantillas usaran texto alternativo."
fi

# ─────────────────────────────────────────────────────────────────
# prepare_template() — aplica placeholders a un archivo HTML
# y retorna el string listo para incrustar en JSON (escapado)
# ─────────────────────────────────────────────────────────────────
prepare_template() {
    TEMPLATE_FILE="$1"
    cat "$TEMPLATE_FILE" \
        | sed "s|%%COMPANY_NAME%%|${OPSN_GOPHISH_COMPANY_NAME}|g" \
        | sed "s|%%SUPPORT_TEAM%%|${OPSN_GOPHISH_SUPPORT_TEAM}|g" \
        | sed "s|%%FROM_NAME%%|${OPSN_GOPHISH_FROM_NAME}|g" \
        | sed "s|%%DOMAIN%%|${OPSN_DOMAIN}|g" \
        | sed "s|%%LOGO_IMG%%|${LOGO_IMG}|g" \
        | sed 's/\\/\\\\/g' \
        | sed 's/"/\\"/g' \
        | tr -d '\n'
}

# ─────────────────────────────────────────────────────────────────
# 1. Esperar a que GoPhish esté disponible (responda en /api/users/)
# ─────────────────────────────────────────────────────────────────
LOG "Esperando a que GoPhish este disponible en ${GOPHISH_URL}..."
MAX_WAIT=120
WAITED=0
until curl -sk --max-time 5 -o /dev/null "${GOPHISH_URL}/api/users/" > /dev/null 2>&1; do
    sleep 3
    WAITED=$((WAITED + 3))
    if [ "$WAITED" -ge "$MAX_WAIT" ]; then
        LOG "ERROR: GoPhish no respondio tras ${MAX_WAIT}s. Abortando."
        exit 1
    fi
done
LOG "GoPhish disponible."

# ─────────────────────────────────────────────────────────────────
# 2. Leer API key directamente del DB SQLite (volumen compartido)
#    El DB esta en /data/gophish.db gracias al config.json montado
# ─────────────────────────────────────────────────────────────────
LOG "Leyendo API key del usuario admin..."

GOPHISH_DB="/data/gophish.db"
API_KEY=""
WAITED=0
MAX_WAIT=60

while [ -z "$API_KEY" ] && [ "$WAITED" -lt "$MAX_WAIT" ]; do
    if [ -f "$GOPHISH_DB" ]; then
        API_KEY=$(sqlite3 "$GOPHISH_DB" "SELECT api_key FROM users WHERE username='admin' LIMIT 1;" 2>/dev/null || true)
    fi
    if [ -z "$API_KEY" ]; then
        sleep 3
        WAITED=$((WAITED + 3))
    fi
done

if [ -z "$API_KEY" ]; then
    LOG "ERROR: No se pudo leer el API key del DB tras ${MAX_WAIT}s. Abortando."
    exit 1
fi

LOG "API key obtenida."

# Helpers para llamadas autenticadas
api_get()  { curl -sk -H "Authorization: ${API_KEY}" "$@"; }
api_post() { curl -sk -H "Authorization: ${API_KEY}" -H "Content-Type: application/json" -X POST "$@"; }
api_put()  { curl -sk -H "Authorization: ${API_KEY}" -H "Content-Type: application/json" -X PUT "$@"; }

# ─────────────────────────────────────────────────────────────────
# 3. Cambiar contraseña del admin a la configurada
# ─────────────────────────────────────────────────────────────────
LOG "Estableciendo password del admin..."
api_put "${GOPHISH_URL}/api/users/1" -d "{
    \"username\": \"admin\",
    \"password\": \"${OPSN_GOPHISH_PASSWORD}\",
    \"role\": \"admin\"
}" > /dev/null
LOG "Password establecida."

# ─────────────────────────────────────────────────────────────────
# 4. Sending Profile — SMTP apuntando a opsn-mail
# ─────────────────────────────────────────────────────────────────
EXISTING_SP=$(api_get "${GOPHISH_URL}/api/smtp/" | grep -o "\"name\":\"${SENDING_PROFILE_NAME}\"" || true)

if [ -z "$EXISTING_SP" ]; then
    LOG "Creando Sending Profile '${SENDING_PROFILE_NAME}'..."
    api_post "${GOPHISH_URL}/api/smtp/" -d "{
        \"name\": \"${SENDING_PROFILE_NAME}\",
        \"host\": \"${OPSN_MAIL_HOST}:${OPSN_GOPHISH_SMTP_PORT}\",
        \"from_address\": \"admin@${OPSN_DOMAIN}\",
        \"username\": \"\",
        \"password\": \"\",
        \"ignore_cert_errors\": true,
        \"headers\": [{\"key\": \"From\", \"value\": \"${OPSN_GOPHISH_FROM_NAME} <admin@${OPSN_DOMAIN}>\"}]
    }" > /dev/null
    LOG "Sending Profile creado."
else
    LOG "Sending Profile ya existe. Sin cambios."
fi

SP_ID=$(api_get "${GOPHISH_URL}/api/smtp/" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)

# ─────────────────────────────────────────────────────────────────
# 5. Email Template
# ─────────────────────────────────────────────────────────────────
EXISTING_ET=$(api_get "${GOPHISH_URL}/api/templates/" | grep -o "\"name\":\"${EMAIL_TEMPLATE_NAME}\"" || true)

if [ -z "$EXISTING_ET" ]; then
    LOG "Creando Email Template '${EMAIL_TEMPLATE_NAME}'..."
    EMAIL_HTML=$(prepare_template /config/templates/email_template.html)
    api_post "${GOPHISH_URL}/api/templates/" -d "{
        \"name\": \"${EMAIL_TEMPLATE_NAME}\",
        \"subject\": \"${OPSN_GOPHISH_EMAIL_SUBJECT}\",
        \"html\": \"${EMAIL_HTML}\",
        \"text\": \"Tu contrasena ha expirado. Visita el siguiente enlace para restablecerla: {{.URL}}\",
        \"attachments\": []
    }" > /dev/null
    LOG "Email Template creado."
else
    LOG "Email Template ya existe. Sin cambios."
fi

ET_ID=$(api_get "${GOPHISH_URL}/api/templates/" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)

# ─────────────────────────────────────────────────────────────────
# 6. Landing Page
# ─────────────────────────────────────────────────────────────────
EXISTING_LP=$(api_get "${GOPHISH_URL}/api/pages/" | grep -o "\"name\":\"${LANDING_PAGE_NAME}\"" || true)

if [ -z "$EXISTING_LP" ]; then
    LOG "Creando Landing Page '${LANDING_PAGE_NAME}'..."
    LP_HTML=$(prepare_template /config/templates/landing_page.html)
    api_post "${GOPHISH_URL}/api/pages/" -d "{
        \"name\": \"${LANDING_PAGE_NAME}\",
        \"html\": \"${LP_HTML}\",
        \"capture_credentials\": true,
        \"capture_passwords\": true,
        \"redirect_url\": \"\"
    }" > /dev/null
    LOG "Landing Page creada."
else
    LOG "Landing Page ya existe. Sin cambios."
fi

LP_ID=$(api_get "${GOPHISH_URL}/api/pages/" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)

# ─────────────────────────────────────────────────────────────────
# 7. User Group
# ─────────────────────────────────────────────────────────────────
EXISTING_UG=$(api_get "${GOPHISH_URL}/api/groups/" | grep -o "\"name\":\"${USER_GROUP_NAME}\"" || true)

if [ -z "$EXISTING_UG" ]; then
    LOG "Creando User Group '${USER_GROUP_NAME}'..."
    api_post "${GOPHISH_URL}/api/groups/" -d "{
        \"name\": \"${USER_GROUP_NAME}\",
        \"targets\": [
            {\"first_name\": \"Admin\", \"last_name\": \"Lab\", \"email\": \"admin@${OPSN_DOMAIN}\", \"position\": \"IT Admin\"},
            {\"first_name\": \"Usuario\", \"last_name\": \"Prueba\", \"email\": \"user@${OPSN_DOMAIN}\", \"position\": \"Empleado\"}
        ]
    }" > /dev/null
    LOG "User Group creado."
else
    LOG "User Group ya existe. Sin cambios."
fi

UG_ID=$(api_get "${GOPHISH_URL}/api/groups/" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)

# ─────────────────────────────────────────────────────────────────
# 8. Campaign — crea la campaña lista para lanzar (no auto-inicia)
# ─────────────────────────────────────────────────────────────────
CAMPAIGN_NAME="${OPSN_GOPHISH_COMPANY_NAME} — Phishing Lab"
EXISTING_CAMP=$(api_get "${GOPHISH_URL}/api/campaigns/" | grep -o "\"name\":\"${CAMPAIGN_NAME}\"" || true)

if [ -z "$EXISTING_CAMP" ]; then
    LOG "Creando Campaign '${CAMPAIGN_NAME}'..."
    # La API de GoPhish referencia template/page/smtp/groups por NOMBRE, no por id
    # (pasar {"id": N} falla con "No email template specified"). Sin launch_date la
    # campaña se lanza al crearse y envia los correos a los targets del lab.
    # La URL es el dominio DNS del phish server (gophish.opensec.lab:80), resoluble
    # por la victima (Desktop/Thunderbird); "localhost" apuntaria al propio Desktop.
    PHISH_URL="http://gophish.${OPSN_DOMAIN}"
    CAMP_RESP=$(api_post "${GOPHISH_URL}/api/campaigns/" -d "{
        \"name\": \"${CAMPAIGN_NAME}\",
        \"template\": {\"name\": \"${EMAIL_TEMPLATE_NAME}\"},
        \"url\": \"${PHISH_URL}\",
        \"page\": {\"name\": \"${LANDING_PAGE_NAME}\"},
        \"smtp\": {\"name\": \"${SENDING_PROFILE_NAME}\"},
        \"groups\": [{\"name\": \"${USER_GROUP_NAME}\"}]
    }")
    if echo "$CAMP_RESP" | grep -q '"success":false'; then
        LOG "ERROR al crear la Campaign: $(echo "$CAMP_RESP" | grep -o '"message":"[^"]*"')"
    else
        LOG "Campaign creada y lanzada (correos enviados a los targets)."
    fi
else
    LOG "Campaign ya existe. Sin cambios."
fi

LOG "---------------------------------------------------"
LOG "Configuracion de GoPhish completada."
LOG "  Empresa        : ${OPSN_GOPHISH_COMPANY_NAME}"
LOG "  Sending Profile: ${SENDING_PROFILE_NAME}"
LOG "  Email Template : ${EMAIL_TEMPLATE_NAME}"
LOG "  Landing Page   : ${LANDING_PAGE_NAME}"
LOG "  User Group     : ${USER_GROUP_NAME}"
LOG "  Campaign       : ${CAMPAIGN_NAME}"
LOG "---------------------------------------------------"
LOG "  La campaña ya esta lanzada. Para el ejercicio:"
LOG "  1. Panel GoPhish: https://localhost:3333 (Campaigns -> '${CAMPAIGN_NAME}')"
LOG "  2. Victima (Desktop/Thunderbird): abrir el correo de ${OPSN_GOPHISH_FROM_NAME},"
LOG "     hacer click en el enlace y enviar credenciales en la landing."
