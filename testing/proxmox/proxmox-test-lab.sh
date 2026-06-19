#!/usr/bin/env bash
# proxmox-test-lab.sh — Orquestador del harness de pruebas Proxmox para OpenSec Lab v1.
#
# Subcomandos implementados:
#   build-template  — Prepara el template Kali cloud-init en el host (una sola vez, idempotente)
#   create          — Crea y arranca la VM de prueba (linked clone del template)
#   destroy         — Detiene y elimina la VM de prueba
#   ssh             — Abre sesión SSH al guest (passthrough)
#   provision       — Instala Docker + deps en el guest (idempotente, con fallback)
#   snapshot        — Crea snapshot limpio (Kali+Docker, lab sin instalar)
#   reset           — Rollback al snapshot limpio, arranca VM y espera SSH
#   help            — Muestra este mensaje
#
# Subcomandos futuros (próximas tareas): test, health, urls, hosts
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
# provision_vm — Instala Docker + deps en el guest (SSH). Idempotente.
# Intenta primero el convenience script oficial; si Docker no queda disponible
# (Kali rolling a veces no está en la lista de distros reconocidas), cae a
# docker.io + docker-compose-plugin del repositorio de Kali.
# ---------------------------------------------------------------------------
provision_vm() {
    echo "[*] Provisionando VM (Docker + deps)..."
    if guest_ssh "sudo bash -s -- $CI_USER" <<'REMOTE'
set -uo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq ca-certificates curl git jq rsync

# --- Intento 1: convenience script oficial de Docker ---
if ! command -v docker >/dev/null 2>&1; then
  echo "[provision] Intentando get.docker.com..."
  curl -fsSL https://get.docker.com | sh || true
fi

# --- Intento 2: docker.io del repo de Kali ---
# Kali rolling no está reconocida por get.docker.com (no tiene Release file).
# docker.io en Kali ya incluye el daemon completo; docker compose se provee
# por docker-compose-plugin (si existe) o por el paquete standalone docker-compose.
if ! command -v docker >/dev/null 2>&1; then
  echo "[provision] get.docker.com falló; usando docker.io de Kali"
  apt-get install -y -qq docker.io || true
  # docker-compose-plugin (v2 integrado) — puede no existir en todas las versiones
  apt-get install -y -qq docker-compose-plugin 2>/dev/null || true
  # Fallback a docker-compose standalone (v1 compatible con 'docker compose' via alias)
  if ! docker compose version >/dev/null 2>&1; then
    apt-get install -y -qq docker-compose 2>/dev/null || true
  fi
fi

systemctl enable --now docker
usermod -aG docker "${1:-kali}" || true
docker --version
# 'docker compose version' (plugin v2) o 'docker-compose version' (standalone)
docker compose version 2>/dev/null || docker-compose version
REMOTE
    then
        echo "[*] Provisionado. (El grupo docker aplica en la próxima sesión SSH.)"
    else
        echo "provision falló: Docker o compose no quedaron instalados" >&2
        return 1
    fi
}

# ---------------------------------------------------------------------------
# snapshot_vm — Crea snapshot limpio vía API (vmstate=0 — sin RAM).
# Baseline: Kali + Docker instalado, lab aún sin instalar.
# ---------------------------------------------------------------------------
snapshot_vm() {
    echo "[*] Creando snapshot $CLEAN_SNAPSHOT..."
    local upid
    upid=$(pve_call POST "/nodes/${PVE_NODE}/qemu/${VM_ID}/snapshot" \
        snapname="$CLEAN_SNAPSHOT" description="Kali+Docker, lab sin instalar" vmstate=0 | jq -r '.data')
    [[ "$(pve_wait_task "$upid")" == "OK" ]] || { echo "snapshot falló" >&2; return 1; }
    echo "[*] Snapshot $CLEAN_SNAPSHOT listo."
}

# ---------------------------------------------------------------------------
# reset_vm — Rollback al snapshot limpio, arranca la VM y espera SSH.
# Proxmox exige que la VM esté detenida antes del rollback cuando vmstate=0;
# se detiene y espera antes de llamar al rollback.
# ---------------------------------------------------------------------------
reset_vm() {
    echo "[*] Deteniendo VM antes del rollback..."
    pve_call POST "/nodes/${PVE_NODE}/qemu/${VM_ID}/status/stop" >/dev/null 2>&1 || true
    local i
    for i in $(seq 1 20); do
        [[ "$(pve_get "/nodes/${PVE_NODE}/qemu/${VM_ID}/status/current" \
            | jq -r '.data.status // empty')" != "running" ]] && break
        sleep 3
    done

    echo "[*] Rollback a $CLEAN_SNAPSHOT..."
    local upid
    upid=$(pve_call POST "/nodes/${PVE_NODE}/qemu/${VM_ID}/snapshot/${CLEAN_SNAPSHOT}/rollback" | jq -r '.data')
    [[ "$(pve_wait_task "$upid")" == "OK" ]] || { echo "rollback falló" >&2; return 1; }

    local resp; resp=$(pve_call POST "/nodes/${PVE_NODE}/qemu/${VM_ID}/status/start"); pve_ok "$resp" || return 1
    echo "[*] Esperando SSH..."
    ssh-keygen -R "$VM_IP" >/dev/null 2>&1 || true
    local ok=0; for i in $(seq 1 40); do guest_ssh 'true' 2>/dev/null && { ok=1; break; }; sleep 5; done
    [[ "$ok" == 1 ]] || { echo "reset: SSH no respondió tras 40 intentos" >&2; return 1; }
    echo "[*] VM revertida y arriba."
}

# ---------------------------------------------------------------------------
# generar_reporte — Genera un informe Markdown con métricas de instalación.
# Escribe en $1; lee métricas de /tmp/metrics.log del guest vía SSH.
# ---------------------------------------------------------------------------
generar_reporte() {
    local out="$1" ts="$2" profiles="$3" dur="$4"
    local rampeak ramavg nsamp
    nsamp=$(guest_ssh 'wc -l < /tmp/metrics.log 2>/dev/null || echo 0' 2>/dev/null | tr -d "[:space:]"); nsamp=${nsamp:-0}
    rampeak=$(guest_ssh "awk 'BEGIN{m=0}{if(\$2>m)m=\$2}END{print m+0}' /tmp/metrics.log" 2>/dev/null || echo 0)
    ramavg=$(guest_ssh "awk '{s+=\$2;n++}END{if(n>0)printf \"%d\", s/n; else print 0}' /tmp/metrics.log" 2>/dev/null || echo 0)
    mkdir -p "$(dirname "$out")"
    {
        echo "# Reporte de instalación — ${ts}"
        echo ""
        echo "- Profiles: \`${profiles}\`"
        echo "- Duración instalación: **${dur}s**"
        if [[ "$nsamp" -gt 0 ]]; then
            echo "- RAM pico: **${rampeak} MB** · promedio: **${ramavg} MB** (${nsamp} muestras)"
        else
            echo "- ⚠️ Muestreador no produjo datos (0 muestras) — métricas de RAM no disponibles"
        fi
        echo ""
        echo "## Disco (/)"
        echo '```'; guest_ssh 'df -h /' 2>/dev/null; echo '```'
        echo "## Contenedores (docker ps)"
        echo '```'; guest_ssh 'docker ps --format "{{.Names}}\t{{.Status}}" 2>/dev/null || sudo docker ps --format "{{.Names}}\t{{.Status}}"' 2>/dev/null; echo '```'
        echo "## Uso por contenedor (docker stats)"
        echo '```'; guest_ssh 'docker stats --no-stream --format "{{.Name}}\t{{.MemUsage}}\t{{.CPUPerc}}" 2>/dev/null || sudo docker stats --no-stream --format "{{.Name}}\t{{.MemUsage}}\t{{.CPUPerc}}"' 2>/dev/null; echo '```'
    } > "$out"
}

# ---------------------------------------------------------------------------
# test_lab — Rollback → rsync → instala headless → genera reporte de métricas.
# Uso: test_lab [profiles]    (default: all)
# ---------------------------------------------------------------------------
test_lab() {
    local profiles="${1:-all}"
    reset_vm || { echo "test: reset falló" >&2; return 1; }
    echo "[*] Copiando repo local a la VM..."
    rsync -az --delete \
        -e "ssh -i $SSH_KEY_PRIV -o StrictHostKeyChecking=accept-new -o BatchMode=yes" \
        --exclude '.git' --exclude 'testing/proxmox/config.env' \
        "$REPO_ROOT/" "${CI_USER}@${VM_IP}:/home/${CI_USER}/opensec-lab/" || { echo "test: rsync falló" >&2; return 1; }

    echo "[*] Instalando muestreador de consumo en la VM..."
    guest_ssh 'cat > /tmp/opsn-metrics.sh' <<'SAMP'
#!/bin/bash
# muestrea cada 5s: epoch, RAM usada (MB), nproc
for i in $(seq 1 720); do
  echo "$(date +%s) $(free -m | awk '/Mem:/{print $3}') $(nproc)"
  sleep 5
done
SAMP
    guest_ssh 'bash -c "nohup bash /tmp/opsn-metrics.sh >/tmp/metrics.log 2>&1 & echo \$! > /tmp/metrics.pid"; echo "sampler lanzado (pid=$(cat /tmp/metrics.pid))"' || true

    echo "[*] Instalando el lab (headless, profiles=$profiles)..."
    local start end
    start=$(guest_ssh 'date +%s')
    # SIN sudo explícito (el script auto-eleva); OPSN_SOURCE_DIR es el repo copiado
    guest_ssh "cd /home/${CI_USER}/opensec-lab && OPSN_NONINTERACTIVE=1 OPSN_PROFILES='${profiles}' OPSN_SOURCE_DIR=\$PWD bash opensec-lab.sh" \
        || echo "[!] El instalador retornó no-cero — revisa el reporte y los logs."
    end=$(guest_ssh 'date +%s')
    guest_ssh 'kill $(cat /tmp/metrics.pid 2>/dev/null) 2>/dev/null; rm -f /tmp/metrics.pid; echo "sampler detenido"' || true

    local ts report
    ts=$(date +%Y-%m-%d_%H%M%S)
    report="$HERE/reports/${ts}.md"
    generar_reporte "$report" "$ts" "$profiles" "$(( end - start ))"
    echo "[*] Reporte: $report"
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
    provision)      provision_vm ;;
    snapshot)       snapshot_vm ;;
    reset)          reset_vm ;;
    test)           test_lab "$@" ;;
    help|--help|-h)
        echo "Uso: $0 {build-template|create|destroy|ssh|provision|snapshot|reset|test}"
        echo ""
        echo "  build-template  Prepara template Kali en el host (una vez, idempotente)"
        echo "  create          Crea VM de prueba como linked clone del template"
        echo "  destroy         Detiene y elimina la VM de prueba"
        echo "  ssh [cmd]       SSH al guest (con o sin comando)"
        echo "  provision       Instala Docker + deps en el guest (idempotente, con fallback)"
        echo "  snapshot        Crea snapshot limpio (Kali+Docker, lab sin instalar)"
        echo "  reset           Rollback al snapshot limpio, arranca VM y espera SSH"
        echo "  test [profiles] Rollback + rsync + instalación headless + reporte de métricas"
        echo "                  profiles: lista entre comillas (e.g. \"dvwa api docs\") o 'all'"
        echo ""
        echo "  Más subcomandos: health urls hosts"
        ;;
    *)
        echo "Uso: $0 {build-template|create|destroy|ssh|provision|snapshot|reset|test}  (más subcomandos: health urls hosts)"
        exit 1
        ;;
esac
