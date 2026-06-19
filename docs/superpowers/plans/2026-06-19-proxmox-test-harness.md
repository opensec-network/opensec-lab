# Proxmox AMD64 Test Harness — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Construir un harness en bash que provisione una VM Kali AMD64 limpia en un Proxmox existente (vía API + SSH al invitado), instale el lab OSN completo de forma no interactiva desde el repo local, y mida consumo — para validar la ruta ataque→detección fuera de macOS/ARM.

**Architecture:** Patrón **template + clone**. Una preparación única vía SSH al host construye un template Kali cloud-init dorado (VMID 9000). El ciclo repetible (clone→9001, cloud-init, snapshot, rollback, destroy) es 100% API REST. El lab se instala desde el repo local copiado a la VM mediante un **modo headless nuevo en `opensec-lab.sh`** (`OPSN_NONINTERACTIVE`/`OPSN_PROFILES`/`OPSN_SOURCE_DIR`), porque el instalador es interactivo y descarga del release v3.0 (inexistente).

**Tech Stack:** Bash, Proxmox VE 8.4 API REST (token `root@pam!cicd`), cloud-init, SSH (llave `~/.ssh/opsn-harness`), `qm` (solo en `build-template`), `jq`, `rsync`, `shellcheck`.

**Estado del spike (2026-06-19, validado en vivo):** template 9000 y VM 9001 (10.0.0.50) ya existen en el host. Todos los comandos de `build-template`/`clone` de este plan se ejecutaron y funcionaron. Ver `docs/superpowers/specs/2026-06-16-proxmox-amd64-test-harness-design.md` y memoria `project_proxmox_harness`.

---

## File Structure

| Archivo | Responsabilidad | Acción |
|---|---|---|
| `opensec-lab.sh` | Instalador del lab — agregar modo headless | Modificar |
| `testing/proxmox/proxmox-test-lab.sh` | Orquestador del harness (subcomandos) | Crear |
| `testing/proxmox/config.env.example` | Plantilla de config versionada | Crear |
| `testing/proxmox/config.env` | Valores reales (secreto del token) | Crear (gitignored) |
| `testing/proxmox/.gitignore` | Ignorar `config.env`, `output/`, `reports/*.md` no | Crear |
| `testing/proxmox/README.md` | Cómo usar el harness + prep manual única | Crear |
| `testing/proxmox/lib/pve-api.sh` | Helpers: llamada API + polling de tareas | Crear |
| `testing/proxmox/reports/` | Reportes de métricas (versionados) | Crear (dir) |
| `testing/proxmox/output/` | Guía de usuario + screenshots (no versionado) | Crear (dir) |

**Convención de scenario (única costura de extensibilidad):** un escenario = `{ TEMPLATE_ID, IMAGE_URL, PROVISION_PKGS }`. Hoy solo `kali-amd64`. No construir runner de matriz (YAGNI).

---

## Task 1: Modo headless en `opensec-lab.sh`

**Files:**
- Modify: `opensec-lab.sh` (helper nuevo + guards en 6 funciones + 2 funciones de descarga + `main`)

Permite correr el instalador sin TTY: `OPSN_NONINTERACTIVE=1 OPSN_PROFILES=all OPSN_SOURCE_DIR=/path/to/repo bash opensec-lab.sh`. Testeable 100% en la Mac, sin Proxmox.

- [ ] **Step 1: Helper `confirmar()` para prompts.** Insertar tras el bloque de logging (después de `log_step`, ~línea 68):

```bash
# Devuelve 0 (sí) automáticamente en modo no interactivo; si no, pregunta.
# Uso: confirmar "  ¿Continuar? [s/N]: " || return 1
confirmar() {
    local prompt="$1" answer
    if [[ "${OPSN_NONINTERACTIVE:-0}" == "1" ]]; then
        return 0
    fi
    echo -n "$prompt"
    read -r answer
    [[ "$answer" =~ ^[sS]$ ]]
}
```

- [ ] **Step 2: Aplicar `confirmar` a los 5 prompts de confirmación.** Reemplazar cada bloque `echo -n "...[s/N]:"; read -r answer; [[ ... ]]` por `confirmar "..."`:
  - `verificar_puerto_53` (líneas 182-186): `confirmar "  ¿Continuar de todas formas? [s/N]: " || return 1`
  - `advertir_ram_si_necesario` (305-310): `if ! confirmar "  ¿Continuar de todas formas? [s/N]: "; then log_warn "Instalación cancelada..."; return 1; fi`
  - `advertir_exposicion_red` (254-256): `confirmar "  ¿Continuar con la exposición a ${bind_addr}? [s/N]: " || return 1`
  - `verificar_puertos_host` (el prompt `read -r answer` tras listar `ocupados`): mismo patrón con `confirmar`.
  - `check_prerequisites` Docker (122-129): `if confirmar "  ¿Instalar Docker ahora? [s/N]: "; then instalar_docker; else log_error ...; exit 1; fi`

- [ ] **Step 3: `descargar_archivos_base` — soportar copia local.** Al inicio de la función (línea ~518), si `OPSN_SOURCE_DIR` está set, copiar desde el repo en vez de `curl` al release:

```bash
    if [[ -n "${OPSN_SOURCE_DIR:-}" ]]; then
        log_step "Copiando archivos base desde repo local: $OPSN_SOURCE_DIR"
        cp "$OPSN_SOURCE_DIR/docker-compose.yml" "$DC_FILE"
        [[ -f "$ENV_FILE" ]] || cp "$OPSN_SOURCE_DIR/config/defaults.env" "$ENV_FILE"
        [[ -f "$LAB_DIR/opensec-lab.sh" ]] || cp "$OPSN_SOURCE_DIR/opensec-lab.sh" "$LAB_DIR/opensec-lab.sh"
        log_info "Archivos base copiados del repo local."
        return 0
    fi
```

- [ ] **Step 4: `descargar_paquete_servicio` — soportar copia local.** Tras el guard `[[ -d "$dest" ]]` (línea ~489), antes del `curl`:

```bash
    if [[ -n "${OPSN_SOURCE_DIR:-}" ]]; then
        log_step "Copiando servicio $service desde repo local..."
        mkdir -p "$dest"
        cp -a "$OPSN_SOURCE_DIR/services/$short/." "$dest/"
        log_info "Servicio $short copiado del repo local."
        return 0
    fi
```

- [ ] **Step 5: `main` — rama headless.** Reemplazar `main()` (líneas 1412-1420):

```bash
main() {
    if [[ "${OPSN_NONINTERACTIVE:-0}" == "1" ]]; then
        instalacion_headless
        return
    fi
    if [[ -f "$PROFILES_FILE" && -f "$DC_FILE" ]]; then
        sudo_docker
        menu_gestion
    else
        menu_instalacion
    fi
}
```

- [ ] **Step 6: Función `instalacion_headless`.** Insertar antes de `main()`. Convierte `OPSN_PROFILES` (lista separada por espacios o `all`) a nombres `opsn-*` y reusa `instalar_servicios`:

```bash
instalacion_headless() {
    banner
    log_step "Modo no interactivo (OPSN_PROFILES=${OPSN_PROFILES:-all})"
    check_prerequisites
    sudo_docker
    mkdir -p "$LAB_DIR/services"; touch "$LOG_FILE" "$PROFILES_FILE"
    descargar_archivos_base

    local sel=()
    if [[ "${OPSN_PROFILES:-all}" == "all" ]]; then
        for entry in "${SERVICES_CATALOG[@]}"; do
            sel+=("$(echo "$entry" | cut -d'|' -f1)")
        done
    else
        for p in ${OPSN_PROFILES}; do
            [[ "$p" == opsn-* ]] && sel+=("$p") || sel+=("opsn-$p")
        done
    fi
    instalar_servicios "${sel[@]}"
}
```

- [ ] **Step 7: shellcheck.** Run: `shellcheck -S warning opensec-lab.sh`
Expected: sin nuevos errores (los `disable` existentes se preservan).

- [ ] **Step 8: Test local en la Mac (servicio liviano, sin Proxmox).**

Run:
```bash
rm -rf /tmp/labtest && HOME=/tmp/labtest \
OPSN_NONINTERACTIVE=1 OPSN_PROFILES=dvwa OPSN_SOURCE_DIR="$PWD" \
bash opensec-lab.sh
```
Expected: instala DVWA sin pedir input; `docker ps` muestra `opsn-dvwa`; sin colgarse en ningún prompt. Limpiar: `HOME=/tmp/labtest bash opensec-lab.sh` no aplica (no TTY) → `docker compose -f /tmp/labtest/OpenSec_Lab/docker-compose.yml --profile dvwa down`.

- [ ] **Step 9: Commit.**
```bash
git add opensec-lab.sh
git commit -m "feat(installer): add non-interactive headless mode (OPSN_NONINTERACTIVE/PROFILES/SOURCE_DIR)"
```

---

## Task 2: Scaffolding de `testing/proxmox/`

**Files:**
- Create: `testing/proxmox/config.env.example`, `.gitignore`, `README.md`, dirs `reports/`, `output/`, `lib/`

- [ ] **Step 1: `config.env.example`** (valores reales como defaults comentados, secreto vacío):

```bash
# Proxmox host (API REST, sin SSH al hipervisor salvo build-template)
PVE_HOST=10.0.0.220
PVE_NODE=lab                       # minúscula — sensible a mayúsculas en la API
PVE_TOKEN_ID='root@pam!cicd'
PVE_TOKEN_SECRET=''                # <- rellenar; NUNCA commitear
PVE_STORAGE=local-lvm              # disco de la VM (lvmthin)
IMAGE_STORAGE=local                # dir storage para el disk.raw
PVE_BRIDGE=vmbr0

# Escenario (única costura para más distros)
TEMPLATE_ID=9000
IMAGE_URL='https://kali.download/cloud-images/current/kali-linux-2026.1-cloud-genericcloud-amd64.tar.xz'
PROVISION_PKGS='ca-certificates curl git jq rsync'

# VM de prueba (clone)
VM_ID=9001
VM_NAME=opsn-harness
VM_CORES=6
VM_MEM=16384
VM_DISK=80G
VM_IP=10.0.0.50
VM_CIDR=24
VM_GW=10.0.0.1
VM_NAMESERVER=8.8.8.8
CI_USER=kali

# SSH al invitado
SSH_KEY_PRIV="$HOME/.ssh/opsn-harness"
SSH_KEY_PUB="$HOME/.ssh/opsn-harness.pub"

# Snapshot limpio
CLEAN_SNAPSHOT=clean-base
```

- [ ] **Step 2: `.gitignore`:**
```
config.env
output/
```
(Nota: `reports/*.md` SÍ se versionan — histórico de consumo.)

- [ ] **Step 3: Crear `config.env` real** copiando el example y rellenando `PVE_TOKEN_SECRET`. NO se commitea.

- [ ] **Step 4: `README.md`** documentando: prerrequisitos (token sin priv-sep, llave SSH), el paso único `build-template` (usa SSH al host), y el flujo `create→provision→snapshot→test→reset`. Incluir la nota de seguridad del token.

- [ ] **Step 5: Commit.**
```bash
git add testing/proxmox/config.env.example testing/proxmox/.gitignore testing/proxmox/README.md
git commit -m "chore(harness): scaffold testing/proxmox config + docs"
```

---

## Task 3: Lib API + cargador de config

**Files:**
- Create: `testing/proxmox/lib/pve-api.sh`

- [ ] **Step 1: Helpers de API y polling.** (validado: el endpoint `/version` y tareas responden)

```bash
#!/usr/bin/env bash
# Helpers de la API REST de Proxmox. Requiere config.env cargado.
_pve_url() { echo "https://${PVE_HOST}:8006/api2/json$1"; }
_pve_auth() { echo "Authorization: PVEAPIToken=${PVE_TOKEN_ID}=${PVE_TOKEN_SECRET}"; }

# GET; imprime .data (json). Uso: pve_get /nodes/$PVE_NODE/status
pve_get() { curl -sk -H "$(_pve_auth)" "$(_pve_url "$1")"; }

# POST/PUT con pares clave=valor url-encoded. Uso: pve_post METHOD /path k=v k=v
pve_call() {
    local method="$1" path="$2"; shift 2
    local args=(); local kv
    for kv in "$@"; do args+=(--data-urlencode "$kv"); done
    curl -sk -X "$method" -H "$(_pve_auth)" "${args[@]}" "$(_pve_url "$path")"
}

# Espera a que una tarea (UPID) termine; retorna su exitstatus.
pve_wait_task() {
    local upid="$1" st
    while :; do
        st=$(pve_get "/nodes/${PVE_NODE}/tasks/${upid}/status" | jq -r '.data.status')
        [[ "$st" == "stopped" ]] && break
        sleep 3
    done
    pve_get "/nodes/${PVE_NODE}/tasks/${upid}/status" | jq -r '.data.exitstatus'
}

# SSH al invitado Kali. Uso: guest_ssh 'comando'
guest_ssh() {
    ssh -i "$SSH_KEY_PRIV" -o BatchMode=yes -o StrictHostKeyChecking=accept-new \
        -o ConnectTimeout=10 "${CI_USER}@${VM_IP}" "$@"
}
```

- [ ] **Step 2: shellcheck.** Run: `shellcheck testing/proxmox/lib/pve-api.sh` — Expected: limpio.

- [ ] **Step 3: Test de humo de la API.** Crear cargador mínimo y probar:
```bash
( set -a; . testing/proxmox/config.env; set +a; . testing/proxmox/lib/pve-api.sh; \
  pve_get /version | jq -e '.data.version' )
```
Expected: imprime `"8.4.14"` (o versión vigente), exit 0.

- [ ] **Step 4: Commit.** `git add testing/proxmox/lib/pve-api.sh && git commit -m "feat(harness): Proxmox API helpers + task polling"`

---

## Task 4: `proxmox-test-lab.sh` — esqueleto + `build-template`

**Files:**
- Create: `testing/proxmox/proxmox-test-lab.sh`

`build-template` es el ÚNICO subcomando que usa SSH al host. Comandos ya validados en el spike.

- [ ] **Step 1: Esqueleto con dispatch de subcomandos y carga de config.**

```bash
#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
[[ -f "$HERE/config.env" ]] || { echo "Falta config.env (copia config.env.example)"; exit 1; }
set -a; . "$HERE/config.env"; set +a
. "$HERE/lib/pve-api.sh"
host_ssh() { ssh -i "$SSH_KEY_PRIV" -o BatchMode=yes -o StrictHostKeyChecking=accept-new root@"$PVE_HOST" "$@"; }

cmd="${1:-help}"; shift || true
case "$cmd" in
    build-template) build_template ;;
    create)         create_vm ;;
    provision)      provision_vm ;;
    snapshot)       snapshot_vm ;;
    test)           test_lab ;;
    reset)          reset_vm ;;
    health)         health_vm ;;
    urls)           print_urls ;;
    hosts)          update_hosts ;;
    ssh)            guest_ssh "$@" ;;
    destroy)        destroy_vm ;;
    *) echo "Uso: $0 {build-template|create|provision|snapshot|test|reset|health|urls|hosts|ssh|destroy}"; exit 1 ;;
esac
```
(Definir las funciones ANTES del `case`, o mover el `case` al final tras todas las defs.)

- [ ] **Step 2: `build_template` (SSH host, validado).** Idempotente: si el template ya existe, no rehace.

```bash
build_template() {
    echo "[*] build-template (SSH al host, operación única)..."
    host_ssh "qm status $TEMPLATE_ID &>/dev/null" && { echo "Template $TEMPLATE_ID ya existe."; return 0; }
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
```

- [ ] **Step 3: Verificación en vivo.** Como el spike ya creó el 9000, probar idempotencia:
Run: `bash testing/proxmox/proxmox-test-lab.sh build-template`
Expected: `Template 9000 ya existe.` exit 0.

- [ ] **Step 4: Commit.** `git add testing/proxmox/proxmox-test-lab.sh && git commit -m "feat(harness): script skeleton + build-template (one-time host prep)"`

---

## Task 5: `create` (clone API, linked) + `destroy`

**Files:**
- Modify: `testing/proxmox/proxmox-test-lab.sh`

- [ ] **Step 1: `create_vm` — clone vía API.** Usar **linked clone** (`full=0`) para velocidad (el spike midió que `full=1` copia 80 GB).

```bash
create_vm() {
    pve_get "/nodes/${PVE_NODE}/qemu/${VM_ID}/status/current" | jq -e '.data' &>/dev/null \
        && { echo "VM $VM_ID ya existe; usa destroy primero."; return 1; }
    echo "[*] Clonando $TEMPLATE_ID -> $VM_ID (linked)..."
    local upid
    upid=$(pve_call POST "/nodes/${PVE_NODE}/qemu/${TEMPLATE_ID}/clone" \
        newid="$VM_ID" name="$VM_NAME" full=0 | jq -r '.data')
    [[ "$(pve_wait_task "$upid")" == "OK" ]] || { echo "clone falló"; return 1; }
    echo "[*] Configurando cloud-init (IP $VM_IP)..."
    pve_call PUT "/nodes/${PVE_NODE}/qemu/${VM_ID}/config" \
        ipconfig0="ip=${VM_IP}/${VM_CIDR},gw=${VM_GW}" nameserver="$VM_NAMESERVER" >/dev/null
    echo "[*] Arrancando..."
    pve_call POST "/nodes/${PVE_NODE}/qemu/${VM_ID}/status/start" >/dev/null
    echo "[*] Esperando SSH en $VM_IP..."
    local i; for i in $(seq 1 40); do guest_ssh 'true' 2>/dev/null && break; sleep 5; done
    guest_ssh 'echo "OK $(hostname) $(uname -m)"'
}
```

- [ ] **Step 2: `destroy_vm` — vía API.** Detener y borrar.

```bash
destroy_vm() {
    pve_call POST "/nodes/${PVE_NODE}/qemu/${VM_ID}/status/stop" >/dev/null 2>&1 || true
    local upid; for i in $(seq 1 20); do
        [[ "$(pve_get "/nodes/${PVE_NODE}/qemu/${VM_ID}/status/current" | jq -r '.data.status')" == "stopped" ]] && break
        sleep 2
    done
    upid=$(pve_call DELETE "/nodes/${PVE_NODE}/qemu/${VM_ID}" purge=1 | jq -r '.data')
    pve_wait_task "$upid"
    echo "[*] VM $VM_ID destruida."
}
```
(Nota: `pve_call DELETE` — añadir `DELETE` es compatible con `curl -X`.)

- [ ] **Step 3: Verificación en vivo.** El spike dejó 9001 con full clone. Probar el ciclo limpio:
Run: `bash proxmox-test-lab.sh destroy && bash proxmox-test-lab.sh create`
Expected: destroy OK; create hace linked clone (rápido), arranca, imprime `OK opsn-harness x86_64`.

- [ ] **Step 4: Commit.** `git commit -am "feat(harness): create (linked clone via API) + destroy"`

---

## Task 6: `provision` (SSH invitado — Docker)

**Files:**
- Modify: `testing/proxmox/proxmox-test-lab.sh`

- [ ] **Step 1: `provision_vm`.** Instala Docker CE + deps en la Kali. (Kali es Debian-based → repo Docker de Debian.)

```bash
provision_vm() {
    echo "[*] Provisionando VM (Docker + deps)..."
    guest_ssh "sudo bash -s" <<'REMOTE'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -qq
sudo apt-get install -y -qq ca-certificates curl git jq rsync
# Docker CE (get.docker.com soporta Kali vía VERSION codename de Debian)
if ! command -v docker &>/dev/null; then
  curl -fsSL https://get.docker.com | sudo sh
fi
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER" || true
docker --version; docker compose version
REMOTE
    echo "[*] Provisionado. (Nota: el grupo docker aplica en la próxima sesión SSH.)"
}
```

- [ ] **Step 2: Verificación en vivo.** Run: `bash proxmox-test-lab.sh provision`
Expected: imprime versiones de `docker` y `docker compose`, exit 0. (Si `get.docker.com` falla en Kali rolling por codename, fallback documentado en README: instalar `docker.io` de los repos de Kali.)

- [ ] **Step 3: Commit.** `git commit -am "feat(harness): provision guest with Docker + deps"`

---

## Task 7: `snapshot` + `reset` (API)

**Files:**
- Modify: `testing/proxmox/proxmox-test-lab.sh`

- [ ] **Step 1: `snapshot_vm`** — crea `clean-base` (VM provisionada, lab AÚN no instalado).

```bash
snapshot_vm() {
    echo "[*] Creando snapshot $CLEAN_SNAPSHOT..."
    local upid
    upid=$(pve_call POST "/nodes/${PVE_NODE}/qemu/${VM_ID}/snapshot" \
        snapname="$CLEAN_SNAPSHOT" description="Kali+Docker, lab sin instalar" vmstate=0 | jq -r '.data')
    [[ "$(pve_wait_task "$upid")" == "OK" ]] && echo "[*] Snapshot listo."
}
```

- [ ] **Step 2: `reset_vm`** — rollback al snapshot limpio y rearranque.

```bash
reset_vm() {
    echo "[*] Rollback a $CLEAN_SNAPSHOT..."
    local upid
    upid=$(pve_call POST "/nodes/${PVE_NODE}/qemu/${VM_ID}/snapshot/${CLEAN_SNAPSHOT}/rollback" | jq -r '.data')
    [[ "$(pve_wait_task "$upid")" == "OK" ]] || { echo "rollback falló"; return 1; }
    pve_call POST "/nodes/${PVE_NODE}/qemu/${VM_ID}/status/start" >/dev/null
    local i; for i in $(seq 1 40); do guest_ssh 'true' 2>/dev/null && break; sleep 5; done
    echo "[*] VM revertida y arriba."
}
```

- [ ] **Step 3: Verificación en vivo.** Run: `bash proxmox-test-lab.sh snapshot && bash proxmox-test-lab.sh reset`
Expected: snapshot OK; reset revierte, arranca y SSH responde.

- [ ] **Step 4: Commit.** `git commit -am "feat(harness): snapshot + reset (rollback) via API"`

---

## Task 8: `test` (rollback + instalar lab headless + métricas)

**Files:**
- Modify: `testing/proxmox/proxmox-test-lab.sh`

Depende de Task 1 (modo headless de `opensec-lab.sh`).

- [ ] **Step 1: `test_lab`.** Revierte a limpio, copia el repo, muestrea consumo, corre el instalador headless, genera reporte.

```bash
test_lab() {
    reset_vm
    echo "[*] Copiando repo local a la VM..."
    rsync -az --delete -e "ssh -i $SSH_KEY_PRIV -o StrictHostKeyChecking=accept-new" \
        --exclude '.git' --exclude 'testing/proxmox/config.env' \
        "$REPO_ROOT/" "${CI_USER}@${VM_IP}:/home/${CI_USER}/opensec-lab/"
    local ts; ts=$(date +%Y-%m-%d_%H%M%S)
    local report="$HERE/reports/${ts}.md"
    echo "[*] Iniciando muestreador de consumo en la VM..."
    guest_ssh "nohup bash -c 'for i in \$(seq 1 720); do echo \"\$(date +%s) \$(awk \"/MemTotal/{t=\\\$2}/MemAvailable/{a=\\\$2}END{print (t-a)/1024}\" /proc/meminfo) \$(nproc)\"; sleep 5; done > /tmp/metrics.log 2>&1 &' " || true
    echo "[*] Instalando el lab completo (headless)..."
    local start end
    start=$(guest_ssh 'date +%s')
    guest_ssh "cd /home/${CI_USER}/opensec-lab && sudo OPSN_NONINTERACTIVE=1 OPSN_PROFILES=all OPSN_SOURCE_DIR=\$PWD bash opensec-lab.sh" || true
    end=$(guest_ssh 'date +%s')
    generar_reporte "$report" "$start" "$end"
    echo "[*] Reporte: $report"
}
```

- [ ] **Step 2: `generar_reporte`.** Markdown con duración, RAM pico/promedio, delta de disco, `docker stats` y `docker ps`.

```bash
generar_reporte() {
    local out="$1" start="$2" end="$3"
    local dur=$(( end - start ))
    local rampeak ramavg
    rampeak=$(guest_ssh "awk 'NR>0{if(\$2>m)m=\$2}END{printf \"%d\", m}' /tmp/metrics.log" 2>/dev/null || echo "?")
    ramavg=$(guest_ssh "awk '{s+=\$2;n++}END{if(n)printf \"%d\", s/n}' /tmp/metrics.log" 2>/dev/null || echo "?")
    {
        echo "# Reporte de instalación — $(date)"
        echo ""
        echo "- Duración instalación: **${dur}s**"
        echo "- RAM pico: **${rampeak} MB** · promedio: **${ramavg} MB**"
        echo ""
        echo "## Disco"; echo '```'; guest_ssh 'df -h /'; echo '```'
        echo "## docker ps"; echo '```'; guest_ssh 'docker ps --format "{{.Names}}\t{{.Status}}"'; echo '```'
        echo "## docker stats (snapshot)"; echo '```'; guest_ssh 'docker stats --no-stream --format "{{.Name}}\t{{.MemUsage}}\t{{.CPUPerc}}"'; echo '```'
    } > "$out"
}
```

- [ ] **Step 3: Verificación en vivo (la prueba grande).** Run: `bash proxmox-test-lab.sh test`
Expected: revierte, instala los 12 servicios sin prompts, genera `reports/<ts>.md` con contenedores `running`. (Si Wazuh tarda, el reporte lo refleja; aceptable.)

- [ ] **Step 4: Commit.** `git commit -am "feat(harness): test (headless full install + metrics report)"`

---

## Task 9: `health` + `urls` + `hosts`

**Files:**
- Modify: `testing/proxmox/proxmox-test-lab.sh`

- [ ] **Step 1: `health_vm`** — corre los readiness del repo dentro de la VM.

```bash
health_vm() {
    for t in web-hacking api-breach phishing kill-chain; do
        echo "=== readiness: $t ==="
        guest_ssh "cd /home/${CI_USER}/opensec-lab && bash tests/${t}-readiness.sh" || true
    done
}
```

- [ ] **Step 2: `print_urls`** — imprime URLs por IP de la VM. (Puertos del compose, fuente de verdad CLAUDE.md.)

```bash
print_urls() {
    cat <<EOF
Portal:     https://${VM_IP}:8443
DVWA:       http://${VM_IP}:8080
Juice Shop: http://${VM_IP}:3000
WebGoat:    http://${VM_IP}:8081
API:        http://${VM_IP}:8025
GoPhish:    https://${VM_IP}:3333
Wazuh:      https://${VM_IP}:5601
Gitea:      http://${VM_IP}:3002
Docs:       http://${VM_IP}:4000
Roundcube:  http://${VM_IP}:8888
Webtop:     http://${VM_IP}:3100
EOF
}
```

- [ ] **Step 3: `update_hosts`** — agrega `*.opensec.lab → VM_IP` al `/etc/hosts` de la Mac (idempotente, requiere sudo).

```bash
update_hosts() {
    local marker="# opsn-harness"
    sudo sed -i '' "/${marker}/d" /etc/hosts 2>/dev/null || true
    for n in portal dvwa api gophish wazuh gitea docs mail webmail desktop; do
        echo "${VM_IP} ${n}.opensec.lab ${marker}" | sudo tee -a /etc/hosts >/dev/null
    done
    echo "[*] /etc/hosts actualizado (usa 'destroy' o edita para revertir)."
}
```

- [ ] **Step 4: Verificación.** Run: `bash proxmox-test-lab.sh urls` (Expected: lista de URLs) y `bash proxmox-test-lab.sh health` (Expected: corre los 4 readiness; degradan a warn donde falte algo).

- [ ] **Step 5: shellcheck final + commit.**
```bash
shellcheck testing/proxmox/proxmox-test-lab.sh testing/proxmox/lib/pve-api.sh
git commit -am "feat(harness): health, urls, hosts subcommands"
```

---

## Task 10: Validación final del harness completo

- [ ] **Step 1: Ciclo end-to-end desde cero.**
```bash
cd testing/proxmox
bash proxmox-test-lab.sh destroy || true
bash proxmox-test-lab.sh create
bash proxmox-test-lab.sh provision
bash proxmox-test-lab.sh snapshot
bash proxmox-test-lab.sh test
bash proxmox-test-lab.sh health
bash proxmox-test-lab.sh urls
```
Expected: cada paso OK; `reports/<ts>.md` generado; readiness mayormente verde.

- [ ] **Step 2: `make validate` + `make test-static`** del repo (asegurar que el modo headless no rompió nada).
Expected: PASS.

- [ ] **Step 3: Commit final + actualizar CLAUDE.md** (sección "Verificar en AMD64" → apuntar al harness).

---

## Notas de handoff (validación por navegador — fase manual posterior)

La validación por navegador (Claude-in-Chrome) del spec §7.3-7.4 (smoke de servicios + recorrido de los 4 talleres + guía de usuario con screenshots) **no es parte de este plan** — se ejecuta en sesión aparte, por taller, una vez que el `test` deja el lab arriba. El harness solo garantiza acceso (`urls`/`hosts`).

## Gotchas conocidos (de la memoria del proyecto, no re-descubrir)
- Disco de la VM Docker: si supera ~95%, Wazuh pasa a read-only. El `test` lo refleja en el reporte.
- Wazuh indexa con 1-3 min de retraso; los readiness reintentan ~2 min.
- Subred Docker dinámica: `detectar_interfaz_suricata` se ejecuta post-deploy automáticamente.
- `get.docker.com` en Kali rolling: si falla por codename, fallback a `apt-get install docker.io` (en README).
