#!/usr/bin/env bash
# proxmox-test-lab.sh — Orquestador del harness de pruebas Proxmox para OpenSec Lab v1.
#
# Subcomandos implementados:
#   build-template  — Prepara el template Kali cloud-init en el host (una sola vez, idempotente)
#   create          — Crea y arranca la VM de prueba (linked clone del template)
#   destroy         — Detiene y elimina la VM de prueba
#   ssh             — Abre sesión SSH al guest (passthrough)
#   help            — Muestra este mensaje
#
# Subcomandos futuros (próximas tareas): provision, snapshot, reset, test, health, urls, hosts
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"

[[ -f "$HERE/config.env" ]] || { echo "Falta config.env (copia config.env.example)"; exit 1; }
set -a; . "$HERE/config.env"; set +a
. "$HERE/lib/pve-api.sh"

# ---------------------------------------------------------------------------
# SSH al hipervisor (solo usado por build-template)
# ---------------------------------------------------------------------------
host_ssh() {
    ssh -i "$SSH_KEY_PRIV" -o BatchMode=yes -o StrictHostKeyChecking=accept-new \
        -o ConnectTimeout=10 root@"$PVE_HOST" "$@"
}

# DELETE con parámetros como query string (Proxmox rechaza body en DELETE).
# Uso: pve_delete /path ?key=val&key2=val2
pve_delete() {
    local path="$1" qs="${2:-}"
    curl -sk -X DELETE -H "Authorization: PVEAPIToken=${PVE_TOKEN_ID}=${PVE_TOKEN_SECRET}" \
        "https://${PVE_HOST}:8006/api2/json${path}${qs}"
}

# Falla (return 1) si la respuesta JSON de la API trae .errors o viene vacía.
# Uso: resp=$(pve_call ...); pve_ok "$resp" || return 1
pve_ok() {
    local resp="$1"
    if [[ -z "$resp" ]] || echo "$resp" | jq -e '.errors' &>/dev/null; then
        echo "API error: $resp" >&2; return 1
    fi
    return 0
}

# ---------------------------------------------------------------------------
# build_template — Prepara el template Kali en el host vía SSH.
# Idempotente: si el template ya existe, no hace nada.
# ÚNICO subcomando que usa host SSH; todos los demás usan la API REST.
# ---------------------------------------------------------------------------
build_template() {
    echo "[*] build-template (SSH al host, operación única)..."
    if host_ssh "qm status $TEMPLATE_ID &>/dev/null"; then
        echo "Template $TEMPLATE_ID ya existe."; return 0
    fi
    host_ssh "bash -s" <<REMOTE
set -euo pipefail
W=/var/lib/vz/template/opsn; mkdir -p "\$W"; cd "\$W"
printf '%s\n' '$(cat "$SSH_KEY_PUB")' > /root/opsn-harness.pub
[ -f disk.raw ] || { curl -fSL --retry 3 -o img.tar.xz "$IMAGE_URL"; tar -xJSf img.tar.xz; }
qm create $TEMPLATE_ID --name opsn-kali-template --memory $VM_MEM --cores $VM_CORES \
  --cpu host --net0 virtio,bridge=$PVE_BRIDGE --scsihw virtio-scsi-single \
  --ostype l26 --agent enabled=1 --serial0 socket --vga serial0
qm importdisk $TEMPLATE_ID disk.raw $PVE_STORAGE
DISK=\$(qm config $TEMPLATE_ID | awk -F': ' '/^unused0:/ {print \$2}')
qm set $TEMPLATE_ID --scsi0 "\$DISK" --boot order=scsi0 --ide2 $PVE_STORAGE:cloudinit \
  --ciuser $CI_USER --sshkeys /root/opsn-harness.pub
qm resize $TEMPLATE_ID scsi0 $VM_DISK
qm template $TEMPLATE_ID
REMOTE
    echo "[*] Template $TEMPLATE_ID listo."
}

# ---------------------------------------------------------------------------
# create_vm — Crea la VM de prueba como linked clone del template (API).
# ---------------------------------------------------------------------------
create_vm() {
    if pve_get "/nodes/${PVE_NODE}/qemu/${VM_ID}/status/current" | jq -e '.data.status' &>/dev/null; then
        echo "VM $VM_ID ya existe; usa destroy primero."; return 1
    fi
    echo "[*] Clonando $TEMPLATE_ID -> $VM_ID (linked)..."
    local upid
    upid=$(pve_call POST "/nodes/${PVE_NODE}/qemu/${TEMPLATE_ID}/clone" \
        newid="$VM_ID" name="$VM_NAME" full=0 | jq -r '.data')
    [[ "$(pve_wait_task "$upid")" == "OK" ]] || { echo "clone falló"; return 1; }
    echo "[*] Configurando cloud-init (IP $VM_IP)..."
    local resp
    resp=$(pve_call PUT "/nodes/${PVE_NODE}/qemu/${VM_ID}/config" \
        ipconfig0="ip=${VM_IP}/${VM_CIDR},gw=${VM_GW}" nameserver="$VM_NAMESERVER")
    pve_ok "$resp" || return 1
    echo "[*] Arrancando..."
    resp=$(pve_call POST "/nodes/${PVE_NODE}/qemu/${VM_ID}/status/start")
    pve_ok "$resp" || return 1
    echo "[*] Esperando SSH en $VM_IP..."
    ssh-keygen -R "$VM_IP" >/dev/null 2>&1 || true
    local i ok=0
    for i in $(seq 1 40); do guest_ssh 'true' 2>/dev/null && { ok=1; break; }; sleep 5; done
    [[ "$ok" == 1 ]] || { echo "create: SSH no respondió tras 40 intentos (~200s)" >&2; return 1; }
    guest_ssh 'echo "OK $(hostname) $(uname -m)"'
}

# ---------------------------------------------------------------------------
# destroy_vm — Detiene y elimina la VM de prueba (API).
# ---------------------------------------------------------------------------
destroy_vm() {
    if ! pve_get "/nodes/${PVE_NODE}/qemu/${VM_ID}/status/current" | jq -e '.data.status' &>/dev/null; then
        echo "[*] VM $VM_ID ya no existe."; return 0
    fi
    pve_call POST "/nodes/${PVE_NODE}/qemu/${VM_ID}/status/stop" >/dev/null 2>&1 || true
    local i; for i in $(seq 1 20); do
        [[ "$(pve_get "/nodes/${PVE_NODE}/qemu/${VM_ID}/status/current" | jq -r '.data.status // empty')" != "running" ]] && break
        sleep 2
    done
    # Proxmox DELETE no acepta body — purge va como query string.
    local upid; upid=$(pve_delete "/nodes/${PVE_NODE}/qemu/${VM_ID}" "?purge=1" | jq -r '.data')
    [[ "$(pve_wait_task "$upid")" == "OK" ]] || { echo "destroy: la tarea de borrado no terminó OK" >&2; return 1; }
    echo "[*] VM $VM_ID destruida."
}

# ---------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------
cmd="${1:-help}"; shift || true
case "$cmd" in
    build-template) build_template ;;
    create)         create_vm ;;
    destroy)        destroy_vm ;;
    ssh)            guest_ssh "$@" ;;
    help|--help|-h)
        echo "Uso: $0 {build-template|create|destroy|ssh}"
        echo ""
        echo "  build-template  Prepara template Kali en el host (una vez, idempotente)"
        echo "  create          Crea VM de prueba como linked clone del template"
        echo "  destroy         Detiene y elimina la VM de prueba"
        echo "  ssh [cmd]       SSH al guest (con o sin comando)"
        echo ""
        echo "  Más subcomandos en próximas tareas: provision snapshot reset test health urls hosts"
        ;;
    *)
        echo "Uso: $0 {build-template|create|destroy|ssh}  (más subcomandos en próximas tareas)"
        exit 1
        ;;
esac
