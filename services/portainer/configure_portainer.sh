#!/bin/sh
# services/portainer/configure_portainer.sh
# Sidecar idempotente: configura Portainer CE con admin y endpoint Docker local.
# Corre como opsn-portainer-init despues de que Portainer esta saludable.

. /lib/common.sh

PORTAINER_URL="https://opsn-portainer:9443"
ADMIN_USER="admin"
ADMIN_PASS="${OPSN_PORTAINER_PASSWORD:-Password}"

# ─────────────────────────────────────────────────────────────────────────────
# Helpers HTTPS — Portainer usa cert auto-firmado, requiere -k
# No se pueden usar las funciones de common.sh porque no tienen -k
# ─────────────────────────────────────────────────────────────────────────────
https_get() {
    curl -sk --max-time 10 "$@"
}

https_post() {
    local url="$1"
    local data="$2"
    shift 2
    curl -sk --max-time 10 -X POST \
        -H "Content-Type: application/json" \
        "$@" \
        -d "$data" \
        "$url"
}

# ─────────────────────────────────────────────────────────────────────────────
# 1. Esperar que Portainer este disponible
# ─────────────────────────────────────────────────────────────────────────────
log_step "Esperando a que Portainer este disponible..."
MAX_WAIT=120
WAITED=0
until https_get "${PORTAINER_URL}/api/status" > /dev/null 2>&1; do
    sleep 3
    WAITED=$((WAITED + 3))
    if [ "$WAITED" -ge "$MAX_WAIT" ]; then
        log_error "Portainer no respondio tras ${MAX_WAIT}s. Abortando."
        exit 1
    fi
done
log_info "Portainer disponible en ${PORTAINER_URL}."

# ─────────────────────────────────────────────────────────────────────────────
# 2. Crear usuario admin (idempotente — 409 si ya existe)
# ─────────────────────────────────────────────────────────────────────────────
log_step "Creando usuario admin..."
INIT_RESP=$(https_post "${PORTAINER_URL}/api/users/admin/init" \
    "{\"Username\":\"${ADMIN_USER}\",\"Password\":\"${ADMIN_PASS}\"}")

INIT_ID=$(printf '%s' "$INIT_RESP" | sed -n 's/.*"Id":\([0-9]*\).*/\1/p' | head -1)

if [ -n "$INIT_ID" ]; then
    log_info "Usuario admin creado (Id: ${INIT_ID})."
elif printf '%s' "$INIT_RESP" | grep -qi "already initialized\|admin user already exists\|conflict"; then
    log_info "Usuario admin ya existe. Sin cambios."
else
    log_warn "Respuesta inesperada al crear admin: ${INIT_RESP}"
fi

# ─────────────────────────────────────────────────────────────────────────────
# 3. Autenticarse para obtener JWT
# ─────────────────────────────────────────────────────────────────────────────
log_step "Autenticando como ${ADMIN_USER}..."
AUTH_RESP=$(https_post "${PORTAINER_URL}/api/auth" \
    "{\"Username\":\"${ADMIN_USER}\",\"Password\":\"${ADMIN_PASS}\"}")

JWT=$(printf '%s' "$AUTH_RESP" | sed -n 's/.*"jwt":"\([^"]*\)".*/\1/p' | head -1)

if [ -z "$JWT" ]; then
    log_error "No se pudo autenticar. Respuesta: ${AUTH_RESP}"
    exit 1
fi
log_info "Autenticacion exitosa."

AUTH_HDR="Authorization: Bearer ${JWT}"

# ─────────────────────────────────────────────────────────────────────────────
# 4. Crear endpoint Docker local (idempotente)
# ─────────────────────────────────────────────────────────────────────────────
log_step "Verificando endpoint Docker local..."
ENDPOINTS=$(https_get -H "$AUTH_HDR" "${PORTAINER_URL}/api/endpoints")

if printf '%s' "$ENDPOINTS" | grep -q '"Name":"local"'; then
    log_info "Endpoint 'local' ya existe. Sin cambios."
else
    log_step "Creando endpoint Docker local..."
    EP_RESP=$(curl -sk --max-time 10 -X POST \
        -H "$AUTH_HDR" \
        -F "Name=local" \
        -F "EndpointCreationType=1" \
        "${PORTAINER_URL}/api/endpoints")

    EP_ID=$(printf '%s' "$EP_RESP" | sed -n 's/.*"Id":\([0-9]*\).*/\1/p' | head -1)
    if [ -n "$EP_ID" ]; then
        log_info "Endpoint 'local' creado (Id: ${EP_ID})."
    else
        log_warn "Respuesta inesperada al crear endpoint: ${EP_RESP}"
    fi
fi

# ─────────────────────────────────────────────────────────────────────────────
log_info "---------------------------------------------------"
log_info "Portainer configurado exitosamente."
log_info "  URL     : https://localhost:9443"
log_info "  Usuario : ${ADMIN_USER}"
log_info "  Endpoint: local (Docker socket)"
log_info "---------------------------------------------------"
