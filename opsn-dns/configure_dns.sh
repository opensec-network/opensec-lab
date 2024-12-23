#!/bin/bash

# ============================================
# Configuración Inicial
# ============================================

# Configura las credenciales de administrador
ADMIN_USERNAME="admin"
ADMIN_PASSWORD="Password"

# Dirección y puerto del servidor Technitium DNS
TECHNITIUM_DNS_HOST="opsn-dns"
TECHNITIUM_DNS_PORT="5380"

# Nombre de la zona a crear
ZONE="opensec.lab"

# Tipo de zona a crear
ZONE_TYPE="Primary"

# Dirección IP del servidor de correo
SERVER_IP="172.18.0.7" 

# Dirección IP del servidor de DNS
DNS_SERVER_IP="172.18.0.2" 

# TTL para los registros DNS
TTL=3600

# Prioridad para el registro MX
MX_PRIORITY=10

if ! command -v curl &> /dev/null || ! command -v jq &> /dev/null; then
    apt-get update
    apt-get -y install curl jq
fi


# ============================================
# Función para manejar errores
# ============================================
handle_error() {
    echo "Error: $1"
    exit 1
}

# ============================================
# Esperar a que el servidor esté disponible
# ============================================
echo "Esperando a que Technitium DNS Server esté disponible..." >> /proc/1/fd/1
until $(curl --output /dev/null --silent --head --fail http://$TECHNITIUM_DNS_HOST:$TECHNITIUM_DNS_PORT); do
    echo '.' >> /proc/1/fd/1
    sleep 2
done
echo "Servidor listo" >> /proc/1/fd/1


# ============================================
# Obtener token de autenticación
# ============================================
echo "Obteniendo el token de autenticación..."
AUTH_RESPONSE=$(curl -s -X GET \
  "http://$TECHNITIUM_DNS_HOST:$TECHNITIUM_DNS_PORT/api/user/login?user=$ADMIN_USERNAME&pass=$ADMIN_PASSWORD&includeInfo=true")

# Mostrar la respuesta de autenticación (opcional)
# echo "Respuesta de autenticación: $AUTH_RESPONSE"

# Extraer el token de la respuesta usando jq
TOKEN=$(echo "$AUTH_RESPONSE" | jq -r '.token')

if [ "$TOKEN" = "null" ] || [ -z "$TOKEN" ]; then
  handle_error "No se pudo obtener el token de autenticación. Verifica tus credenciales."
fi

echo "Token de autenticación obtenido: $TOKEN"

# ============================================
# Verificar si la zona ya existe
# ============================================
echo "Verificando si la zona '$ZONE' ya existe..."

ZONE_EXISTS=$(curl -s -X GET "http://$TECHNITIUM_DNS_HOST:$TECHNITIUM_DNS_PORT/api/zones/list?token=$TOKEN" | \
  jq -r --arg ZONE "$ZONE" '.response.zones[]? | select(.name == $ZONE) | .name')



if [ "$ZONE_EXISTS" = "$ZONE" ]; then
    echo "La zona '$ZONE' ya existe. No se realizará ninguna acción."
    exit 0
fi

echo "La zona '$ZONE' no existe. Procediendo a crearla..."

# ============================================
# Crear la zona
# ============================================
CREATE_ZONE_URL="http://$TECHNITIUM_DNS_HOST:$TECHNITIUM_DNS_PORT/api/zones/create"
RESPONSE_CREATE_ZONE=$(curl -s -X GET "$CREATE_ZONE_URL?token=$TOKEN&zone=$ZONE&type=$ZONE_TYPE")

# Verificar si la creación de la zona fue exitosa"
ZONE_CREATION_STATUS=$(echo "$RESPONSE_CREATE_ZONE" | jq -r '.status')

if [ "$ZONE_CREATION_STATUS" != "ok" ]; then
    handle_error "No se pudo crear la zona '$ZONE'. Respuesta de la API: $RESPONSE_CREATE_ZONE"
fi

echo "Zona '$ZONE' creada exitosamente."

# ============================================
# Agregar registros DNS necesarios
# ============================================

# Función para agregar un registro DNS
add_dns_record() {
    local type=$1
    local name=$2
    local value=$3
    local priority=$4
    local ttl_value=$5

    ADD_RECORD_URL="http://$TECHNITIUM_DNS_HOST:$TECHNITIUM_DNS_PORT/api/zones/records/add"
    RECORD_URL="$ADD_RECORD_URL?token=$TOKEN&domain=$name.$ZONE&zone=$ZONE&type=$type&ttl=$ttl_value"

    # Agregar parámetros específicos para tipo MX y A
    if [ "$type" = "MX" ]; then
        RECORD_URL="${RECORD_URL}&exchange=${value}&preference=${priority}"
    elif [ "$type" = "A" ]; then
        RECORD_URL="${RECORD_URL}&ipAddress=${value}"
    elif [ "$type" = "TXT" ]; then
        RECORD_URL="${RECORD_URL}&text=${value}"
    fi

    # Realizar la llamada a la API para agregar el registro
    RESPONSE=$(curl -s -X GET "$RECORD_URL")

    # Verificar si la creación del registro fue exitosa
    RECORD_STATUS=$(echo "$RESPONSE" | jq -r '.status')

    if [ "$RECORD_STATUS" != "ok" ]; then
        handle_error "No se pudo agregar el registro $type para '$name'. Respuesta de la API: $RESPONSE"
    fi

    echo "Registro $type para '$name' agregado exitosamente."
}

echo "Agregando registros DNS necesarios..."

# a. Agregar registro A para mail.opsn.mail
add_dns_record "A" "mail" "$SERVER_IP" "" "$TTL"

# b. Agregar registro A para dns.opsn.mail
add_dns_record "A" "dns" "$DNS_SERVER_IP" "" "$TTL"

# c. Agregar registro MX para opsn.mail
add_dns_record "MX" "opensec.lab" "mail.$ZONE" "$MX_PRIORITY" "$TTL"

echo "Todos los registros DNS han sido agregados exitosamente."

exit 0
