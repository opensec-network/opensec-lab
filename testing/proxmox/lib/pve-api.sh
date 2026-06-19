#!/usr/bin/env bash
# Helpers de la API REST de Proxmox. Requiere config.env cargado en el entorno.
# Sourced por proxmox-test-lab.sh — no ejecutar directamente.
#
# Variables requeridas (provistas por config.env vía el script padre):
#   PVE_HOST        — IP o FQDN del nodo Proxmox (e.g. 10.0.0.220)
#   PVE_NODE        — Nombre del nodo (e.g. lab)
#   PVE_TOKEN_ID    — Token ID en formato user@realm!tokenname
#   PVE_TOKEN_SECRET— Secret del token (nunca imprimir)
#   VM_IP           — IP del guest Kali
#   CI_USER         — Usuario SSH en el guest
#   SSH_KEY_PRIV    — Ruta a la clave privada SSH
# shellcheck disable=SC2154
#
# CONTRATO: pve_get y pve_call devuelven el JSON crudo de la API y NO verifican
# el código HTTP. Un 401/403/500 devuelve JSON de error con exit 0 — los callers
# DEBEN inspeccionar .data / .errors (o el exitstatus vía pve_wait_task) para
# detectar fallos. Un token vencido se ve como respuesta válida si no se revisa.

# ---------------------------------------------------------------------------
# Internos
# ---------------------------------------------------------------------------

# Construye la URL completa de la API.
_pve_url() { echo "https://${PVE_HOST}:8006/api2/json$1"; }

# Devuelve el header de autenticación con token.
_pve_auth() { echo "Authorization: PVEAPIToken=${PVE_TOKEN_ID}=${PVE_TOKEN_SECRET}"; }

# ---------------------------------------------------------------------------
# GET — imprime la respuesta JSON completa (incluye .data).
# Uso: pve_get /nodes/$PVE_NODE/status
# ---------------------------------------------------------------------------
pve_get() {
    curl -sk -H "$(_pve_auth)" "$(_pve_url "$1")"
}

# ---------------------------------------------------------------------------
# POST / PUT / DELETE con pares clave=valor url-encoded.
# Uso: pve_call METHOD /path key=value [key=value ...]
# ---------------------------------------------------------------------------
pve_call() {
    local method="$1" path="$2"
    shift 2
    local args=()
    local kv
    for kv in "$@"; do
        args+=(--data-urlencode "$kv")
    done
    curl -sk -X "$method" -H "$(_pve_auth)" "${args[@]}" "$(_pve_url "$path")"
}

# ---------------------------------------------------------------------------
# Espera a que una tarea Proxmox (UPID) finalice.
# Imprime el exitstatus de la tarea (e.g. "OK" o mensaje de error).
# Falla (return 1) si excede PVE_TASK_TIMEOUT segundos (default 600) — evita
# que un UPID inválido/colgado o un error de la API cuelguen el harness.
# Uso: pve_wait_task <UPID>
# ---------------------------------------------------------------------------
pve_wait_task() {
    local upid="$1"
    [[ -z "$upid" ]] && { echo "pve_wait_task: UPID vacío" >&2; return 2; }
    local st payload deadline=$(( SECONDS + ${PVE_TASK_TIMEOUT:-600} ))
    while :; do
        payload=$(pve_get "/nodes/${PVE_NODE}/tasks/${upid}/status")
        st=$(echo "$payload" | jq -r '.data.status // empty')
        [[ "$st" == "stopped" ]] && break
        if (( SECONDS >= deadline )); then
            echo "pve_wait_task: timeout esperando UPID ${upid} (status='${st}')" >&2
            return 1
        fi
        sleep 3
    done
    echo "$payload" | jq -r '.data.exitstatus // empty'
}

# ---------------------------------------------------------------------------
# SSH al guest Kali usando la clave de CI.
# Uso: guest_ssh 'comando remoto'
# ---------------------------------------------------------------------------
guest_ssh() {
    ssh -i "$SSH_KEY_PRIV" \
        -o BatchMode=yes \
        -o StrictHostKeyChecking=accept-new \
        -o ConnectTimeout=10 \
        "${CI_USER}@${VM_IP}" "$@"
}
