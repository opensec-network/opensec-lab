#!/bin/bash

# ============================================
# Configuración — se leen desde variables de entorno con valores por defecto
# ============================================

ADMIN_USERNAME="${OPSN_DNS_ADMIN_USERNAME:-admin}"
ADMIN_PASSWORD="${OPSN_DNS_PASSWORD:-Password}"

TECHNITIUM_DNS_HOST="${OPSN_DNS_HOST:-opsn-dns}"
TECHNITIUM_DNS_PORT="${OPSN_DNS_CONSOLE_PORT:-5380}"

ZONE="${OPSN_DOMAIN:-opensec.lab}"
ZONE_TYPE="Primary"

# Resolver IPs dinámicamente via Docker DNS (los contenedores deben estar corriendo)
resolve_host() {
    local host="$1"
    getent hosts "$host" 2>/dev/null | awk '{print $1}' | head -1
}

# Intentar resolver con reintentos (otros contenedores pueden tardar en arrancar)
wait_for_host() {
    local host="$1"
    local ip=""
    local attempts=0
    local max=10
    while [ -z "$ip" ] && [ "$attempts" -lt "$max" ]; do
        ip=$(resolve_host "$host")
        if [ -z "$ip" ]; then
            sleep 3
            attempts=$((attempts + 1))
        fi
    done
    echo "$ip"
}

SERVER_IP=$(wait_for_host "opsn-mail")
DNS_SERVER_IP=$(resolve_host "opsn-dns")
GOPHISH_IP=$(wait_for_host "opsn-gophish")
WEBGOAT_IP=$(resolve_host "opsn-webgoat")
GITEA_IP=$(resolve_host "opsn-gitea")
PORTAL_IP=$(resolve_host "opsn-portal")
WAZUH_IP=$(resolve_host "opsn-wazuh-dashboard")
API_IP=$(resolve_host "opsn-api")

# Si el propio DNS no resuelve (extraño), usar la IP del contenedor actual
[ -z "$DNS_SERVER_IP" ] && DNS_SERVER_IP="$(hostname -i | awk '{print $1}')"
# SERVER_IP y GOPHISH_IP se dejan vacíos si no resuelven — sus registros se omitirán

TTL=3600
MX_PRIORITY=10

if ! command -v curl &> /dev/null; then
    apt-get update -qq
    apt-get -y -qq install curl
fi

# ============================================
# Manejo de errores
# ============================================
handle_error() {
    echo "Error: $1" >> /proc/1/fd/1
    exit 1
}

# ============================================
# Esperar a que el servidor esté disponible
# ============================================
echo "Esperando a que Technitium DNS Server esté disponible..." >> /proc/1/fd/1
until curl --output /dev/null --silent --head --fail "http://$TECHNITIUM_DNS_HOST:$TECHNITIUM_DNS_PORT"; do
    printf '.' >> /proc/1/fd/1
    sleep 2
done
echo "" >> /proc/1/fd/1
echo "Servidor DNS listo." >> /proc/1/fd/1

# ============================================
# Obtener token de autenticación
# ============================================
echo "Obteniendo token de autenticación..." >> /proc/1/fd/1
AUTH_RESPONSE=$(curl -s -X GET \
  "http://$TECHNITIUM_DNS_HOST:$TECHNITIUM_DNS_PORT/api/user/login?user=$ADMIN_USERNAME&pass=$ADMIN_PASSWORD&includeInfo=true")

TOKEN=$(echo "$AUTH_RESPONSE" | grep -o '"token":"[^"]*"' | sed 's/"token":"//;s/"//')

if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
    handle_error "No se pudo obtener token. Verifica credenciales de Technitium."
fi

echo "Token obtenido." >> /proc/1/fd/1

# ============================================
# Verificar si la zona ya existe (idempotente)
# ============================================
ZONE_EXISTS=$(curl -s -X GET "http://$TECHNITIUM_DNS_HOST:$TECHNITIUM_DNS_PORT/api/zones/list?token=$TOKEN" | \
  grep -o "\"name\":\"${ZONE}\"" | grep -o "\"${ZONE}\"" | tr -d '"')

if [ "$ZONE_EXISTS" = "$ZONE" ]; then
    echo "La zona '$ZONE' ya existe. Actualizando registros..." >> /proc/1/fd/1
else
    echo "Creando zona '$ZONE'..." >> /proc/1/fd/1

    RESPONSE_CREATE=$(curl -s -X GET \
      "http://$TECHNITIUM_DNS_HOST:$TECHNITIUM_DNS_PORT/api/zones/create?token=$TOKEN&zone=$ZONE&type=$ZONE_TYPE")

    ZONE_STATUS=$(echo "$RESPONSE_CREATE" | grep -o '"status":"[^"]*"' | sed 's/"status":"//;s/"//')
    if [ "$ZONE_STATUS" != "ok" ]; then
        handle_error "No se pudo crear la zona '$ZONE'. Respuesta: $RESPONSE_CREATE"
    fi

    echo "Zona '$ZONE' creada." >> /proc/1/fd/1
fi

# ============================================
# Función para agregar registros DNS
# Usa updateRecord para sobreescribir si ya existe.
# ============================================
add_dns_record() {
    local type=$1
    local name=$2
    local value=$3
    local priority=$4
    local ttl_value=$5

    # Intentar agregar; si falla por duplicado, actualizar.
    local BASE="http://$TECHNITIUM_DNS_HOST:$TECHNITIUM_DNS_PORT/api/zones/records"
    # Si name es "@" o igual al ZONE, usar el apex de la zona directamente
    local DOMAIN
    if [ "$name" = "@" ] || [ "$name" = "$ZONE" ]; then
        DOMAIN="$ZONE"
    else
        DOMAIN="${name}.${ZONE}"
    fi

    local ADD_URL="${BASE}/add?token=${TOKEN}&domain=${DOMAIN}&zone=${ZONE}&type=${type}&ttl=${ttl_value}"

    if [ "$type" = "MX" ]; then
        ADD_URL="${ADD_URL}&exchange=${value}&preference=${priority}"
    elif [ "$type" = "A" ]; then
        ADD_URL="${ADD_URL}&ipAddress=${value}"
    elif [ "$type" = "TXT" ]; then
        local text_encoded
        text_encoded=$(printf '%s' "$value" | sed 's/{/%7B/g; s/}/%7D/g')
        ADD_URL="${ADD_URL}&text=${text_encoded}"
    fi

    RESPONSE=$(curl -s --globoff -X GET "$ADD_URL")
    STATUS=$(echo "$RESPONSE" | grep -o '"status":"[^"]*"' | sed 's/"status":"//;s/"//')

    if [ "$STATUS" != "ok" ]; then
        # Registro probablemente ya existe — intentar actualizar (delete+add)
        local DEL_URL="${BASE}/delete?token=${TOKEN}&domain=${DOMAIN}&zone=${ZONE}&type=${type}"
        curl -s --globoff -X GET "$DEL_URL" > /dev/null 2>&1 || true
        RESPONSE=$(curl -s --globoff -X GET "$ADD_URL")
        STATUS=$(echo "$RESPONSE" | grep -o '"status":"[^"]*"' | sed 's/"status":"//;s/"//')
        if [ "$STATUS" != "ok" ]; then
            echo "  [!] No se pudo actualizar registro $type para '$name': $RESPONSE" >> /proc/1/fd/1
            return 0
        fi
    fi

    echo "  Registro $type: $name -> $value" >> /proc/1/fd/1
}

echo "Agregando registros DNS..." >> /proc/1/fd/1

add_dns_record "A"  "dns"          "$DNS_SERVER_IP" ""            "$TTL"

if [ -n "$SERVER_IP" ]; then
    add_dns_record "A"  "mail"     "$SERVER_IP"     ""            "$TTL"
    add_dns_record "A"  "webmail"  "$SERVER_IP"     ""            "$TTL"
    add_dns_record "MX" "@" "mail.$ZONE"  "$MX_PRIORITY" "$TTL"
else
    echo "  (mail/webmail omitidos — opsn-mail no está corriendo)" >> /proc/1/fd/1
fi

if [ -n "$GOPHISH_IP" ]; then
    add_dns_record "A"  "gophish"  "$GOPHISH_IP"    ""            "$TTL"
else
    echo "  (gophish omitido — opsn-gophish no está corriendo)" >> /proc/1/fd/1
fi

if [ -n "$WEBGOAT_IP" ]; then
    add_dns_record "A"  "webgoat"  "$WEBGOAT_IP"    ""            "$TTL"
else
    echo "  (webgoat omitido — opsn-webgoat no está corriendo)" >> /proc/1/fd/1
fi

if [ -n "$GITEA_IP" ]; then
    add_dns_record "A"  "git"       "$GITEA_IP"      ""            "$TTL"
else
    echo "  (git omitido — opsn-gitea no está corriendo)" >> /proc/1/fd/1
fi

if [ -n "$PORTAL_IP" ]; then
    add_dns_record "A"  "lab"       "$PORTAL_IP"     ""            "$TTL"
else
    echo "  (lab omitido — opsn-portal no está corriendo)" >> /proc/1/fd/1
fi

if [ -n "$WAZUH_IP" ]; then
    add_dns_record "A"  "wazuh"    "$WAZUH_IP"      ""            "$TTL"
else
    echo "  (wazuh omitido — opsn-wazuh-dashboard no está corriendo)" >> /proc/1/fd/1
fi

if [ -n "$API_IP" ]; then
    add_dns_record "A"  "api"       "$API_IP"        ""            "$TTL"
else
    echo "  (api omitido — opsn-api no esta corriendo)" >> /proc/1/fd/1
fi

echo "Configuración DNS completada." >> /proc/1/fd/1

exit 0
