#!/bin/sh
# services/wazuh/configure_wazuh.sh
# Sidecar de inicializacion post-arranque para el stack Wazuh.
# Ejecutado por opsn-wazuh-init en docker-compose.yml.
#
# Acciones:
#   1. Espera que el Indexer responda (HTTP 401/503 = arriba)
#   2. Inicializa el indice de seguridad OpenSearch (solo primera vez)
#   3. Crea directorios de logs en el Manager

set -e

. /lib/common.sh

INDEXER_HOST="${OPSN_WAZUH_INDEXER_HOST:-opsn-wazuh-indexer}"
INDEXER_PORT="${OPSN_WAZUH_INDEXER_PORT:-9200}"
DASHBOARD_HOST="${OPSN_WAZUH_DASHBOARD_HOST:-opsn-wazuh-dashboard}"
DASHBOARD_PORT="${OPSN_WAZUH_DASHBOARD_PORT:-5601}"
WAZUH_PASSWORD="${OPSN_WAZUH_PASSWORD:-Password1.}"
TIMEOUT=180
DASHBOARD_TIMEOUT=300

# ─── 1. Esperar que el Indexer responda ──────────────────────────────────────

log_step "Esperando Wazuh Indexer en ${INDEXER_HOST}:${INDEXER_PORT} (max ${TIMEOUT}s)..."

elapsed=0
while [ "$elapsed" -lt "$TIMEOUT" ]; do
    code=$(curl -sk -o /dev/null -w '%{http_code}' \
        "https://${INDEXER_HOST}:${INDEXER_PORT}" 2>/dev/null || echo "000")
    # 401 = arriba con auth requerida; 503 = security index sin inicializar
    if [ "$code" = "401" ] || [ "$code" = "503" ]; then
        break
    fi
    sleep 5
    elapsed=$((elapsed + 5))
    printf "\r  [%ds/%ds] Esperando indexer (HTTP %s)..." "$elapsed" "$TIMEOUT" "$code"
done
echo ""

if [ "$elapsed" -ge "$TIMEOUT" ]; then
    log_error "Wazuh Indexer no respondio en ${TIMEOUT}s."
    log_error "Revisa los logs: docker logs opsn-wazuh-indexer"
    exit 1
fi

log_info "Wazuh Indexer disponible (HTTP ${code})."

# ─── 2. Inicializar indice de seguridad (solo primera vez) ───────────────────

idx_status=$(curl -sk -u "admin:${WAZUH_PASSWORD}" -o /dev/null -w '%{http_code}' \
    "https://${INDEXER_HOST}:${INDEXER_PORT}/.opendistro_security" 2>/dev/null || echo "000")

if [ "$idx_status" = "200" ]; then
    log_info "Indice de seguridad ya existe — omitiendo inicializacion."
else
    log_step "Inicializando indice de seguridad OpenSearch (primera ejecucion)..."
    docker exec opsn-wazuh-indexer bash -c \
        'export JAVA_HOME=/usr/share/wazuh-indexer/jdk
         bash /usr/share/wazuh-indexer/plugins/opensearch-security/tools/securityadmin.sh \
           -cd /usr/share/wazuh-indexer/opensearch-security/ \
           -nhnv \
           -cacert /usr/share/wazuh-indexer/certs/root-ca.pem \
           -cert  /usr/share/wazuh-indexer/certs/admin.pem \
           -key   /usr/share/wazuh-indexer/certs/admin-key.pem \
           -p 9200 -icl 2>&1 | tail -5'
    log_info "Indice de seguridad inicializado."
fi

# ─── 3. Crear directorios de logs en el Manager ──────────────────────────────

log_step "Creando directorios de logs en opsn-wazuh-manager..."

year=$(date +%Y)
mon=$(date +%b)

docker exec opsn-wazuh-manager bash -c \
    "mkdir -p /var/ossec/logs/{alerts,archives,firewall}/${year}/${mon} && \
     chown -R wazuh:wazuh \
       /var/ossec/logs/alerts \
       /var/ossec/logs/archives \
       /var/ossec/logs/firewall" 2>/dev/null || true

# ─── 4. Importar dashboards y saved searches del lab ─────────────────────────
# Los .ndjson estan montados en /opsn-dashboards dentro del contenedor del
# dashboard. El import es idempotente (overwrite=true): seguro en cada arranque.

log_step "Esperando Wazuh Dashboard en ${DASHBOARD_HOST}:${DASHBOARD_PORT} (max ${DASHBOARD_TIMEOUT}s)..."

elapsed=0
dash_ready=0
while [ "$elapsed" -lt "$DASHBOARD_TIMEOUT" ]; do
    code=$(docker exec "$DASHBOARD_HOST" \
        curl -sk -o /dev/null -w '%{http_code}' \
        -u "admin:${WAZUH_PASSWORD}" \
        "https://localhost:${DASHBOARD_PORT}/api/status" 2>/dev/null || echo "000")
    if [ "$code" = "200" ]; then
        dash_ready=1
        break
    fi
    sleep 5
    elapsed=$((elapsed + 5))
    printf "\r  [%ds/%ds] Esperando dashboard (HTTP %s)..." "$elapsed" "$DASHBOARD_TIMEOUT" "$code"
done
echo ""

if [ "$dash_ready" = "1" ]; then
    log_info "Wazuh Dashboard disponible — importando objetos guardados..."
    docker exec "$DASHBOARD_HOST" sh -c '
        for f in /opsn-dashboards/*.ndjson; do
            [ -e "$f" ] || continue
            name=$(basename "$f")
            result=$(curl -sk -u "admin:'"${WAZUH_PASSWORD}"'" \
                -X POST "https://localhost:'"${DASHBOARD_PORT}"'/api/saved_objects/_import?overwrite=true" \
                -H "osd-xsrf: true" --form file=@"$f" 2>/dev/null)
            echo "  [import] $name -> $result"
        done' 2>&1 | grep -o "\"success\":[a-z]*\|\[import\] [^ ]*" | tr "\n" " "
    echo ""
    log_info "Dashboards del lab importados."
else
    log_error "Wazuh Dashboard no respondio en ${DASHBOARD_TIMEOUT}s — omitiendo import de dashboards."
    log_error "Reintenta luego con: docker restart opsn-wazuh-init"
fi

log_info "Wazuh configurado correctamente."
