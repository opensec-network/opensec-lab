#!/bin/bash
# OpenSec Lab — Script de instalación y gestión
# Versión: 3.0
# Uso: /bin/bash -c "$(curl -fsSL https://lab.opensec.network/install)"

set -uo pipefail

# ─────────────────────────────────────────────────────────────────
# CONSTANTES DE RELEASE
# ─────────────────────────────────────────────────────────────────
VERSION="3.0"
GITHUB_ORG="opensec-network"
GITHUB_REPO="opensec-lab"
RELEASE_BASE="https://github.com/${GITHUB_ORG}/${GITHUB_REPO}/releases/download/v${VERSION}"

# ─────────────────────────────────────────────────────────────────
# DIRECTORIOS Y ARCHIVOS
# ─────────────────────────────────────────────────────────────────
LAB_DIR="$HOME/OpenSec_Lab"
DC_FILE="$LAB_DIR/docker-compose.yml"
ENV_FILE="$LAB_DIR/.env"
PROFILES_FILE="$LAB_DIR/.active_profiles"
LOG_FILE="$LAB_DIR/opensec-lab.log"

# ─────────────────────────────────────────────────────────────────
# SERVICIOS DISPONIBLES (orden = orden del menú)
# ─────────────────────────────────────────────────────────────────
# Formato: "nombre|descripción|necesita_archivos|dependencias"
declare -a SERVICES_CATALOG=(
    "opsn-dns|Servidor DNS (Technitium)|yes|"
    "opsn-mail|Servidor de correo + Roundcube webmail|yes|opsn-dns"
    "opsn-gophish|GoPhish — framework de phishing con campaña pre-configurada|yes|opsn-dns opsn-mail"
    "opsn-desktop|Escritorio XFCE con Thunderbird pre-configurado|yes|opsn-dns"
    "opsn-dvwa|DVWA — aplicación web vulnerable|no|"
    "opsn-juice-shop|OWASP Juice Shop|no|"
    "opsn-webgoat|WebGoat — plataforma de aprendizaje guiado OWASP|no|"
    "opsn-api|API vulnerable — OWASP API Security Top 10 (Flask)|no|"
    "opsn-gitea|Gitea — repos con código vulnerable para análisis estático|yes|"
    "opsn-docs|Documentacion guiada MkDocs Material|no|"
    "opsn-portal|Portal central — dashboard con links a todos los servicios|yes|"
    "opsn-wazuh|Wazuh SIEM + Suricata IDS — Blue Team (8+ GB RAM)|yes|opsn-dns opsn-suricata"
)

# ─────────────────────────────────────────────────────────────────
# COLORES
# ─────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# ─────────────────────────────────────────────────────────────────
# LOGGING
# ─────────────────────────────────────────────────────────────────
log_info()    { echo -e "${GREEN}[✓]${NC} $*"; echo "$(date +'%F %T') INFO: $*"    >> "$LOG_FILE" 2>/dev/null || true; }
log_warn()    { echo -e "${YELLOW}[!]${NC} $*"; echo "$(date +'%F %T') WARN: $*"   >> "$LOG_FILE" 2>/dev/null || true; }
log_error()   { echo -e "${RED}[✗]${NC} $*"; echo "$(date +'%F %T') ERROR: $*"    >> "$LOG_FILE" 2>/dev/null || true; }
log_step()    { echo -e "${BLUE}[→]${NC} $*"; }

# ─────────────────────────────────────────────────────────────────
# SUDO
# ─────────────────────────────────────────────────────────────────
SUDO_CMD=""

sudo_docker() {
    if docker info &>/dev/null; then
        SUDO_CMD=""
        return 0
    fi
    SUDO_CMD="sudo"
    if id -nG "$USER" | grep -qw docker; then
        log_warn "El usuario $USER está en el grupo docker pero necesita reiniciar la sesión."
    else
        log_warn "Agregando $USER al grupo docker..."
        sudo usermod -aG docker "$USER" || true
    fi
    log_warn "Usando sudo para comandos Docker en esta sesión."
}

# ─────────────────────────────────────────────────────────────────
# BANNER
# ─────────────────────────────────────────────────────────────────
banner() {
    echo -e "${BLUE}${BOLD}"
    echo "  ___                 ____            _          _     "
    echo " / _ \ _ __  ___ _ __|___ \ ___  ___  | |    __ _| |__  "
    echo "| | | | '_ \/ _ \ '_ \ __) / _ \/ __| | |   / _\` | '_ \ "
    echo "| |_| | |_) |  __/ | | / __/  __/ (__  | |__| (_| | |_) |"
    echo " \___/| .__/ \___|_| |_|_____\___|\___| |_____\__,_|_.__/ "
    echo "      |_|                                                  "
    echo -e "${NC}"
    echo -e "${CYAN}  OpenSec Network Lab  •  v${VERSION}  •  github.com/${GITHUB_ORG}/${GITHUB_REPO}${NC}"
    echo ""
}

# ─────────────────────────────────────────────────────────────────
# PREREQUISITOS
# ─────────────────────────────────────────────────────────────────
check_prerequisites() {
    local errors=0

    # Arquitectura soportada
    local arch
    arch=$(uname -m)
    if [[ "$arch" != "x86_64" && "$arch" != "aarch64" && "$arch" != "arm64" ]]; then
        log_warn "Arquitectura '$arch' no verificada. Soportadas: x86_64, aarch64/arm64."
    fi

    # Docker
    if ! command -v docker &>/dev/null; then
        log_warn "Docker no está instalado."
        echo -n "  ¿Instalar Docker ahora? [s/N]: "
        read -r answer
        if [[ "$answer" =~ ^[sS]$ ]]; then
            instalar_docker
        else
            log_error "Docker es requerido. Instálalo y vuelve a ejecutar el script."
            exit 1
        fi
    fi

    # docker compose (v2)
    if ! docker compose version &>/dev/null; then
        log_error "Docker Compose v2 no encontrado. Actualiza Docker Desktop o instala el plugin."
        exit 1
    fi

    # curl
    if ! command -v curl &>/dev/null; then
        log_error "curl es requerido. Instálalo con: sudo apt-get install curl"
        exit 1
    fi

    # RAM
    local ram_mb
    ram_mb=$(awk '/MemTotal/ {printf "%d", $2/1024}' /proc/meminfo 2>/dev/null || echo 0)
    if [[ "$ram_mb" -gt 0 && "$ram_mb" -lt 5120 ]]; then
        log_warn "RAM disponible: ${ram_mb}MB. Se recomiendan mínimo 6GB para el lab completo."
    fi

    return $errors
}

instalar_docker() {
    log_step "Instalando Docker via get.docker.com..."
    curl -fsSL https://get.docker.com | sudo sh
    sudo systemctl enable --now docker || true
    log_info "Docker instalado."
}

# ─────────────────────────────────────────────────────────────────
# VERIFICAR PUERTO 53
# ─────────────────────────────────────────────────────────────────
verificar_puerto_53() {
    if command -v ss &>/dev/null; then
        if ss -tulpn 2>/dev/null | grep -q ':53 '; then
            log_warn "El puerto 53 está en uso (posiblemente systemd-resolved)."
            echo ""
            echo "  Si la instalación de DNS falla, ejecuta:"
            echo "  sudo systemctl stop systemd-resolved"
            echo "  sudo systemctl disable systemd-resolved"
            echo ""
            echo -n "  ¿Continuar de todas formas? [s/N]: "
            read -r answer
            if [[ ! "$answer" =~ ^[sS]$ ]]; then
                return 1
            fi
        fi
    fi
    return 0
}

# ─────────────────────────────────────────────────────────────────
# ESTIMACIÓN DE RAM
# ─────────────────────────────────────────────────────────────────
# RAM estimada por servicio (MB)
declare -A SERVICE_RAM_MB=(
    ["opsn-dns"]=200
    ["opsn-mail"]=300
    ["opsn-gophish"]=200
    ["opsn-desktop"]=500
    ["opsn-dvwa"]=200
    ["opsn-juice-shop"]=300
    ["opsn-webgoat"]=400
    ["opsn-api"]=150
    ["opsn-docs"]=50
    ["opsn-gitea"]=200
    ["opsn-portal"]=50
    ["opsn-wazuh"]=2500
)

estimar_ram() {
    local services=("$@")
    local total=0

    for svc in "${services[@]}"; do
        local mb="${SERVICE_RAM_MB[$svc]:-100}"
        total=$((total + mb))
    done
    echo "$total"
}

advertir_ram_si_necesario() {
    local services=("$@")
    local estimado
    estimado=$(estimar_ram "${services[@]}")
    local disponible
    disponible=$(awk '/MemTotal/ {printf "%d", $2/1024}' /proc/meminfo 2>/dev/null || echo 0)

    if [[ "$disponible" -gt 0 ]]; then
        local umbral=$(( disponible * 80 / 100 ))
        if [[ "$estimado" -gt "$umbral" ]]; then
            echo ""
            log_warn "Aviso de RAM:"
            log_warn "  RAM estimada para los servicios seleccionados: ~${estimado} MB"
            log_warn "  RAM disponible en el sistema:                  ${disponible} MB"
            log_warn "  Umbral recomendado (80%%):                     ${umbral} MB"
            echo ""
            echo -n "  ¿Continuar de todas formas? [s/N]: "
            read -r answer
            if [[ ! "$answer" =~ ^[sS]$ ]]; then
                log_warn "Instalación cancelada. Considera seleccionar menos servicios."
                return 1
            fi
        fi
    fi
    return 0
}

# ─────────────────────────────────────────────────────────────────
# VERIFICAR vm.max_map_count (requerido por Wazuh Indexer/OpenSearch)
# ─────────────────────────────────────────────────────────────────
verificar_vm_max_map_count() {
    # macOS Docker Desktop ya gestiona este parámetro en la VM interna
    [[ "$(uname)" == "Darwin" ]] && return 0
    local current
    current=$(cat /proc/sys/vm/max_map_count 2>/dev/null || echo 0)
    if [[ "$current" -lt 262144 ]]; then
        log_step "Ajustando vm.max_map_count a 262144 (requerido por OpenSearch)..."
        sudo sysctl -w vm.max_map_count=262144 2>/dev/null || {
            log_warn "No se pudo ajustar vm.max_map_count. El Indexer puede fallar."
            log_warn "  Ejecuta manualmente: sudo sysctl -w vm.max_map_count=262144"
            return 0
        }
        log_info "vm.max_map_count configurado a 262144."
    fi
}

# ─────────────────────────────────────────────────────────────────
# INICIALIZACIÓN POST-DEPLOY: DVWA
# Espera a que DVWA responda y crea la base de datos automáticamente.
# ─────────────────────────────────────────────────────────────────
inicializar_dvwa() {
    local port="${OPSN_DVWA_PORT:-8080}"
    log_step "Esperando DVWA..."
    local elapsed=0
    while [[ $elapsed -lt 60 ]]; do
        curl -sk -o /dev/null -w '%{http_code}' "http://localhost:${port}/setup.php" 2>/dev/null | grep -q "200" && break
        sleep 3; elapsed=$((elapsed + 3))
    done
    if [[ $elapsed -ge 60 ]]; then
        log_warn "DVWA no respondió — crea la BD manualmente en http://localhost:${port}/setup.php"
        return 0
    fi
    curl -s -o /dev/null -X POST "http://localhost:${port}/setup.php" \
        -d "create_db=Create+%2F+Reset+Database" 2>/dev/null
    log_info "DVWA: base de datos inicializada."

}


# ─────────────────────────────────────────────────────────────────
# DETECCIÓN DE INTERFAZ SURICATA (Linux solamente)
# Se llama después de compose up. Detecta el bridge de la red
# openseclab, actualiza .env y reinicia Suricata.
# ─────────────────────────────────────────────────────────────────
detectar_interfaz_suricata() {
    if [[ "$(uname)" == "Darwin" ]]; then
        log_info "macOS — Suricata usará interfaz por defecto (any)."
        return 0
    fi
    local net_id bridge
    net_id=$($SUDO_CMD docker network inspect openseclab -f '{{.Id}}' 2>/dev/null) || return 0
    bridge=$($SUDO_CMD docker network inspect openseclab \
        -f '{{index .Options "com.docker.network.bridge.name"}}' 2>/dev/null)
    [[ -z "$bridge" ]] && bridge="br-${net_id:0:12}"
    if ip link show "$bridge" &>/dev/null; then
        sed -i "s/^OPSN_SURICATA_INTERFACE=.*/OPSN_SURICATA_INTERFACE=${bridge}/" "$ENV_FILE"
        log_info "Suricata: interfaz detectada → $bridge"
        # Reiniciar Suricata con la interfaz correcta
        $SUDO_CMD docker compose -f "$DC_FILE" --env-file "$ENV_FILE" \
            up -d --no-deps --force-recreate opsn-suricata 2>/dev/null || true
    else
        log_warn "Interfaz bridge '$bridge' no encontrada. Suricata usará la configurada en .env."
    fi
}

# ─────────────────────────────────────────────────────────────────
# META-PROFILES: conjuntos de servicios preconfigurados
# ─────────────────────────────────────────────────────────────────
declare -A META_PROFILES=(
    ["B"]="opsn-wazuh opsn-suricata"
    ["V"]="opsn-dvwa opsn-juice-shop opsn-webgoat opsn-api"
    ["C"]="opsn-dvwa opsn-juice-shop opsn-webgoat opsn-api opsn-portal opsn-docs"
    ["F"]="opsn-dns opsn-mail opsn-gophish opsn-desktop opsn-dvwa opsn-juice-shop opsn-webgoat opsn-api opsn-gitea opsn-portal opsn-docs opsn-wazuh opsn-suricata"
)

# ─────────────────────────────────────────────────────────────────
# GESTIÓN DE PROFILES ACTIVOS
# ─────────────────────────────────────────────────────────────────
profiles_get() {
    if [[ -f "$PROFILES_FILE" ]]; then
        grep -v '^#' "$PROFILES_FILE" | grep -v '^$' || true
    fi
}

profiles_add() {
    local profile="$1"
    if ! grep -qx "$profile" "$PROFILES_FILE" 2>/dev/null; then
        echo "$profile" >> "$PROFILES_FILE"
    fi
}

profiles_remove() {
    local profile="$1"
    if [[ -f "$PROFILES_FILE" ]]; then
        grep -v "^${profile}$" "$PROFILES_FILE" > "${PROFILES_FILE}.tmp" && mv "${PROFILES_FILE}.tmp" "$PROFILES_FILE"
    fi
}

profiles_to_flags() {
    local flags=""
    while IFS= read -r p; do
        [[ -n "$p" ]] && flags="$flags --profile $p"
    done <<< "$(profiles_get)"
    echo "$flags"
}

# ─────────────────────────────────────────────────────────────────
# ESTADO DE CONTENEDORES
# ─────────────────────────────────────────────────────────────────
container_running() {
    $SUDO_CMD docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$1"
}

container_exists() {
    $SUDO_CMD docker ps -a --format '{{.Names}}' 2>/dev/null | grep -qx "$1"
}

service_installed() {
    # Un servicio está instalado si su profile está en .active_profiles
    # Acepta tanto "opsn-dns" como "dns"
    local profile="${1#opsn-}"
    grep -qx "$profile" "$PROFILES_FILE" 2>/dev/null
}

# ─────────────────────────────────────────────────────────────────
# DEPENDENCIAS
# ─────────────────────────────────────────────────────────────────
resolve_dependencies() {
    # Dado un conjunto de servicios seleccionados, agrega sus dependencias
    local selected=("$@")
    local resolved=()

    for svc in "${selected[@]}"; do
        # Buscar dependencias en el catálogo
        for entry in "${SERVICES_CATALOG[@]}"; do
            local name
            name=$(echo "$entry" | cut -d'|' -f1)
            local deps
            deps=$(echo "$entry" | cut -d'|' -f4)
            if [[ "$name" == "$svc" && -n "$deps" ]]; then
                for dep in $deps; do
                    if [[ ! " ${selected[*]} " =~ " ${dep} " ]] && \
                       [[ ! " ${resolved[*]} " =~ " ${dep} " ]]; then
                        log_info "Agregando dependencia: $dep (requerido por $svc)" >&2
                        resolved+=("$dep")
                    fi
                done
            fi
        done
        resolved+=("$svc")
    done

    echo "${resolved[@]}"
}

# ─────────────────────────────────────────────────────────────────
# DESCARGA DE PAQUETES DE SERVICIO
# ─────────────────────────────────────────────────────────────────
descargar_paquete_servicio() {
    local service="$1"
    # Extraer "nombre_sin_prefijo" (opsn-dns → dns)
    local short="${service#opsn-}"
    local tarball="opsn-${short}.tar.gz"
    local dest="$LAB_DIR/services/$short"
    local url="${RELEASE_BASE}/${tarball}"

    # Si el directorio ya existe, no redownloear
    if [[ -d "$dest" ]]; then
        log_info "Archivos de $service ya presentes."
        return 0
    fi

    log_step "Descargando archivos de $service..."
    mkdir -p "$dest"

    local status_code
    status_code=$(curl -s -o /dev/null -w "%{http_code}" --head "$url")
    if [[ "$status_code" == "200" || "$status_code" == "302" ]]; then
        curl -fsSL "$url" | tar -xz -C "$dest" --strip-components=1
        log_info "Paquete $tarball descargado y extraído."
    else
        log_error "No se encontró el paquete $tarball en ${RELEASE_BASE}."
        log_error "  URL: $url (HTTP $status_code)"
        return 1
    fi
}

servicio_necesita_archivos() {
    local svc="$1"
    for entry in "${SERVICES_CATALOG[@]}"; do
        if [[ "$(echo "$entry" | cut -d'|' -f1)" == "$svc" ]]; then
            [[ "$(echo "$entry" | cut -d'|' -f3)" == "yes" ]] && return 0
        fi
    done
    return 1
}

# ─────────────────────────────────────────────────────────────────
# DESCARGA INICIAL (docker-compose.yml + .env + script)
# ─────────────────────────────────────────────────────────────────
descargar_archivos_base() {
    log_step "Descargando archivos base del lab (v${VERSION})..."

    # docker-compose.yml
    curl -fsSL "${RELEASE_BASE}/docker-compose.yml" -o "$DC_FILE"
    log_info "docker-compose.yml descargado."

    # .env (solo si no existe, para no sobreescribir cambios del usuario)
    if [[ ! -f "$ENV_FILE" ]]; then
        curl -fsSL "${RELEASE_BASE}/defaults.env" -o "$ENV_FILE"
        log_info ".env creado desde defaults.env."
    else
        log_info ".env ya existe. No se sobreescribe (cambios del usuario preservados)."
    fi

    # Guardar copia del script en el lab para gestión futura
    if [[ ! -f "$LAB_DIR/opensec-lab.sh" ]]; then
        curl -fsSL "${RELEASE_BASE}/opensec-lab.sh" -o "$LAB_DIR/opensec-lab.sh"
        chmod +x "$LAB_DIR/opensec-lab.sh"
        log_info "Script guardado en $LAB_DIR/opensec-lab.sh para gestión futura."
    fi
}

# ─────────────────────────────────────────────────────────────────
# MENÚ DE SELECCIÓN DE SERVICIOS
# ─────────────────────────────────────────────────────────────────
seleccionar_servicios() {
    local mode="${1:-install}"  # install | remove
    local available=()
    local labels=()

    echo ""
    if [[ "$mode" == "install" ]]; then
        echo -e "${BOLD}Servicios disponibles para instalar:${NC}"
        echo ""
        for entry in "${SERVICES_CATALOG[@]}"; do
            local name desc
            name=$(echo "$entry" | cut -d'|' -f1)
            desc=$(echo "$entry" | cut -d'|' -f2)
            if ! service_installed "$name"; then
                available+=("$name")
                labels+=("$desc")
            fi
        done
    else
        echo -e "${BOLD}Servicios instalados:${NC}"
        echo ""
        for entry in "${SERVICES_CATALOG[@]}"; do
            local name desc
            name=$(echo "$entry" | cut -d'|' -f1)
            desc=$(echo "$entry" | cut -d'|' -f2)
            if service_installed "$name"; then
                available+=("$name")
                labels+=("$desc")
            fi
        done
    fi

    if [[ ${#available[@]} -eq 0 ]]; then
        if [[ "$mode" == "install" ]]; then
            log_info "No hay servicios adicionales disponibles para instalar."
        else
            log_info "No hay servicios instalados."
        fi
        SELECTED_SERVICES=()
        return
    fi

    # Meta-profiles (solo en modo install)
    if [[ "$mode" == "install" ]]; then
        echo -e "  ${CYAN}Paquetes rápidos:${NC}"
        echo "  B) Blue Team   — Wazuh SIEM + Suricata IDS ${YELLOW}(requiere 12+ GB RAM)${NC}"
        echo -e "  V) Vuln Targets — DVWA + Juice Shop + WebGoat"
        echo -e "  C) Vuln + Portal — DVWA + Juice Shop + WebGoat + Portal"
        echo -e "  F) Full Lab    — Todos los servicios ${YELLOW}(excluye Wazuh)${NC}"
        echo ""
        echo -e "  ${CYAN}Servicios individuales:${NC}"
    fi

    for i in "${!available[@]}"; do
        local status=""
        if service_installed "${available[$i]}"; then
            status=" ${GREEN}[instalado]${NC}"
        fi
        printf "  %d) %s — %s%b\n" "$((i+1))" "${available[$i]}" "${labels[$i]}" "$status"
    done
    echo "  a) Todos"
    echo "  0) Cancelar"
    echo ""
    echo -n "  Selección (ej: 1 3, 'a', o meta-profile B/V/C/F): "

    read -r -a raw_selection

    SELECTED_SERVICES=()

    if [[ "${raw_selection[*]:-}" == "0" ]]; then
        return
    elif [[ "${raw_selection[*]:-}" =~ ^[aA]$ ]]; then
        SELECTED_SERVICES=("${available[@]}")
    elif [[ "$mode" == "install" && "${raw_selection[*]:-}" =~ ^[BbVvCcFf]$ ]]; then
        local meta_key
        meta_key=$(echo "${raw_selection[0]}" | tr '[:lower:]' '[:upper:]')
        local meta_services="${META_PROFILES[$meta_key]:-}"
        if [[ -n "$meta_services" ]]; then
            read -r -a SELECTED_SERVICES <<< "$meta_services"
            log_info "Meta-profile '$meta_key' seleccionado: ${SELECTED_SERVICES[*]}"
        fi
    else
        for idx in "${raw_selection[@]}"; do
            if [[ "$idx" =~ ^[0-9]+$ ]] && (( idx >= 1 && idx <= ${#available[@]} )); then
                SELECTED_SERVICES+=("${available[$((idx-1))]}")
            fi
        done
    fi
}

# ─────────────────────────────────────────────────────────────────
# INSTALAR SERVICIOS
# ─────────────────────────────────────────────────────────────────
instalar_servicios() {
    local selected=("$@")

    if [[ ${#selected[@]} -eq 0 ]]; then
        log_warn "No se seleccionaron servicios."
        return 0
    fi

    # Verificar puerto 53 si se instala DNS
    for svc in "${selected[@]}"; do
        if [[ "$svc" == "opsn-dns" ]]; then
            verificar_puerto_53 || return 1
        fi
    done

    # Verificar vm.max_map_count si se instala Wazuh
    for svc in "${selected[@]}"; do
        if [[ "$svc" == "opsn-wazuh" ]]; then
            verificar_vm_max_map_count
            break
        fi
    done

    # Resolver dependencias
    local with_deps
    with_deps=$(resolve_dependencies "${selected[@]}")
    read -r -a all_services <<< "$with_deps"

    echo ""
    log_step "Servicios a instalar: ${all_services[*]}"

    # Advertir si la RAM estimada supera el 80% de la disponible
    advertir_ram_si_necesario "${all_services[@]}" || return 1

    # Descargar paquetes necesarios
    for svc in "${all_services[@]}"; do
        if servicio_necesita_archivos "$svc"; then
            descargar_paquete_servicio "$svc" || return 1
        fi
    done

    # Actualizar .active_profiles
    for svc in "${all_services[@]}"; do
        local profile="${svc#opsn-}"
        profiles_add "$profile"
    done

    # Ejecutar docker compose con los profiles activos
    local profile_flags
    profile_flags=$(profiles_to_flags)

    # Asegurar que la red external existe antes de compose up
    $SUDO_CMD docker network inspect openseclab >/dev/null 2>&1 || \
        $SUDO_CMD docker network create openseclab

    echo ""
    log_step "Iniciando contenedores..."
    # shellcheck disable=SC2086
    $SUDO_CMD docker compose -f "$DC_FILE" --env-file "$ENV_FILE" $profile_flags up -d --build

    echo ""
    log_info "Contenedores iniciados."

    # Post-deploy: inicializaciones automáticas por servicio
    local instala_wazuh=false instala_dvwa=false
    for svc in "${all_services[@]}"; do
        [[ "$svc" == "opsn-wazuh" ]]  && instala_wazuh=true
        [[ "$svc" == "opsn-dvwa" ]]   && instala_dvwa=true
    done
    [[ "$instala_dvwa" == "true" ]]  && inicializar_dvwa
    if [[ "$instala_wazuh" == "true" ]]; then
        detectar_interfaz_suricata
    fi

    # Health checks y credenciales
    sleep 3
    health_checks "${all_services[@]}"
    mostrar_credenciales
}

# ─────────────────────────────────────────────────────────────────
# DETENER SERVICIOS (sin borrar volúmenes ni imágenes)
# ─────────────────────────────────────────────────────────────────
detener_servicios() {
    local selected=("$@")
    for svc in "${selected[@]}"; do
        local profile="${svc#opsn-}"
        log_step "Deteniendo $svc..."
        $SUDO_CMD docker compose -f "$DC_FILE" --env-file "$ENV_FILE" \
            --profile "$profile" stop 2>/dev/null || true
        log_info "$svc detenido."
    done
}

# ─────────────────────────────────────────────────────────────────
# REANUDAR SERVICIOS (iniciar contenedores detenidos)
# ─────────────────────────────────────────────────────────────────
reanudar_servicios() {
    local selected=("$@")
    for svc in "${selected[@]}"; do
        local profile="${svc#opsn-}"
        log_step "Reanudando $svc..."
        $SUDO_CMD docker compose -f "$DC_FILE" --env-file "$ENV_FILE" \
            --profile "$profile" start 2>/dev/null || true
        log_info "$svc reanudado."
    done
}

# ─────────────────────────────────────────────────────────────────
# ELIMINAR SERVICIOS
# ─────────────────────────────────────────────────────────────────
eliminar_servicios() {
    local selected=("$@")

    for svc in "${selected[@]}"; do
        local profile="${svc#opsn-}"
        log_step "Eliminando $svc..."
        $SUDO_CMD docker compose -f "$DC_FILE" --env-file "$ENV_FILE" \
            --profile "$profile" down --volumes 2>/dev/null || true
        profiles_remove "$profile"
        log_info "$svc eliminado."
    done
}

# ─────────────────────────────────────────────────────────────────
# REINSTALAR SERVICIOS
# Recrea los contenedores y rebuilds las imágenes sin tocar volúmenes.
# ─────────────────────────────────────────────────────────────────
reinstalar_servicios() {
    local selected=("$@")

    if [[ ${#selected[@]} -eq 0 ]]; then
        log_warn "No se seleccionaron servicios."
        return 0
    fi

    local profile_flags=""
    for svc in "${selected[@]}"; do
        local profile="${svc#opsn-}"
        profile_flags="$profile_flags --profile $profile"
    done

    echo ""
    log_step "Reinstalando: ${selected[*]}"
    # shellcheck disable=SC2086
    $SUDO_CMD docker compose -f "$DC_FILE" --env-file "$ENV_FILE" $profile_flags up -d --build --force-recreate

    echo ""
    log_info "Reinstalación completada."
    sleep 3
    health_checks "${selected[@]}"
    mostrar_credenciales
}

# ─────────────────────────────────────────────────────────────────
# BORRAR TODO
# ─────────────────────────────────────────────────────────────────
borrar_todo() {
    echo -e "${RED}${BOLD}"
    echo "  ¡ATENCIÓN! Esto eliminará TODOS los contenedores, volúmenes,"
    echo "  la red Docker y el directorio $LAB_DIR."
    echo -e "${NC}"
    echo -n "  ¿Confirmar? Escribe 'BORRAR' para continuar: "
    read -r confirm
    if [[ "$confirm" != "BORRAR" ]]; then
        log_info "Operación cancelada."
        return
    fi

    log_step "Eliminando todos los servicios..."
    if [[ -f "$DC_FILE" ]]; then
        $SUDO_CMD docker compose -f "$DC_FILE" --env-file "$ENV_FILE" \
            --profile all down --volumes --remove-orphans 2>/dev/null || true
    fi

    # Forzar eliminación de contenedores opsn-*
    for ctr in $(docker ps -a --format '{{.Names}}' | grep '^opsn-' 2>/dev/null || true); do
        $SUDO_CMD docker rm -f "$ctr" 2>/dev/null || true
    done

    $SUDO_CMD docker network rm openseclab 2>/dev/null || true

    rm -rf "$LAB_DIR"
    log_info "Desinstalación completa. El directorio $LAB_DIR fue eliminado."
}

# ─────────────────────────────────────────────────────────────────
# HEALTH CHECKS
# Servicios con healthcheck en compose: opsn-mail, opsn-desktop
# Para el resto basta con verificar que el contenedor esté corriendo
# ─────────────────────────────────────────────────────────────────

# Devuelve el estado de salud de un contenedor:
#   "healthy" | "unhealthy" | "starting" | "running" | "stopped" | "missing"
container_health() {
    local name="$1"
    local info
    info=$(docker inspect --format '{{.State.Status}}|{{if .State.Health}}{{.State.Health.Status}}{{end}}' "$name" 2>/dev/null) || { echo "missing"; return; }
    local state health
    state=$(echo "$info" | cut -d'|' -f1)
    health=$(echo "$info" | cut -d'|' -f2)

    if [[ "$state" != "running" ]]; then
        echo "stopped"
    elif [[ "$health" == "healthy" ]]; then
        echo "healthy"
    elif [[ "$health" == "unhealthy" ]]; then
        echo "unhealthy"
    elif [[ "$health" == "starting" ]]; then
        echo "starting"
    else
        # Sin healthcheck — basta con que el contenedor esté corriendo
        echo "running"
    fi
}

# Imprime la tabla de estado para los servicios recibidos como argumentos
_print_status_table() {
    for svc in "$@"; do
        local h
        h=$(container_health "$svc")
        local icon label
        case "$h" in
            healthy)   icon="${GREEN}✓${NC}";  label="${GREEN}listo${NC}" ;;
            running)   icon="${GREEN}✓${NC}";  label="${GREEN}corriendo${NC}" ;;
            starting)  icon="${YELLOW}⟳${NC}"; label="${YELLOW}configurando...${NC}" ;;
            unhealthy) icon="${RED}✗${NC}";    label="${RED}error${NC}" ;;
            stopped)   icon="${YELLOW}!${NC}"; label="${YELLOW}detenido${NC}" ;;
            *)         icon="${RED}✗${NC}";    label="${RED}no encontrado${NC}" ;;
        esac
        printf "    %-30s " "$svc"
        echo -e "[ $icon $label ]"
    done
}

health_checks() {
    local services=("$@")

    # Filtrar efímeros y expandir servicios compuestos a sus contenedores reales
    local watch=()
    for svc in "${services[@]}"; do
        [[ "$svc" == *"-init" || "$svc" == *"-certs" ]] && continue
        if [[ "$svc" == "opsn-wazuh" ]]; then
            watch+=(opsn-wazuh-indexer opsn-wazuh-manager opsn-wazuh-dashboard opsn-suricata)
        else
            watch+=("$svc")
        fi
    done

    # Servicios que tienen healthcheck o necesitan espera extra
    local needs_wait=false
    for svc in "${watch[@]}"; do
        [[ "$svc" == "opsn-mail" || "$svc" == "opsn-desktop" || "$svc" == "opsn-wazuh-dashboard" ]] && { needs_wait=true; break; }
    done

    if [[ "$needs_wait" == "false" ]]; then
        echo ""
        echo -e "${BOLD}Verificando contenedores:${NC}"
        _print_status_table "${watch[@]}"
        return
    fi

    echo ""
    echo -e "${BOLD}  Espera un momento — los servicios se están configurando...${NC}"
    echo -e "  ${CYAN}(el correo y el escritorio tardan ~30-60s en estar listos)${NC}"
    echo ""

    local timeout=180
    local elapsed=0
    local interval=4
    local line_count=${#watch[@]}
    local first=true

    while true; do
        # Contar cuántos ya están listos
        local done_count=0
        for svc in "${watch[@]}"; do
            local h
            h=$(container_health "$svc")
            [[ "$h" == "healthy" || "$h" == "running" ]] && ((done_count++))
        done

        # Borrar las líneas anteriores (excepto en la primera pasada)
        if [[ "$first" == "false" ]]; then
            for (( i=0; i<line_count; i++ )); do
                printf "\033[1A\033[2K"
            done
        fi
        first=false

        _print_status_table "${watch[@]}"

        # Todos listos o timeout
        if [[ "$done_count" -eq "${#watch[@]}" ]]; then
            echo ""
            echo -e "  ${GREEN}${BOLD}✓ Todos los servicios están listos.${NC}"
            break
        fi

        if [[ "$elapsed" -ge "$timeout" ]]; then
            echo ""
            echo -e "  ${YELLOW}! Tiempo de espera agotado. Algunos servicios aún pueden estar iniciando.${NC}"
            echo -e "  Revisa con: ${CYAN}docker ps${NC}"
            break
        fi

        sleep "$interval"
        elapsed=$((elapsed + interval))
    done
}

# ─────────────────────────────────────────────────────────────────
# TABLA DE CREDENCIALES
# ─────────────────────────────────────────────────────────────────
mostrar_credenciales() {
    # Leer puerto del .env si existe
    local env_file="${ENV_FILE:-/dev/null}"
    _port() { grep "^$1=" "$env_file" 2>/dev/null | cut -d= -f2 | tr -d '"' || echo "$2"; }

    echo ""
    echo -e "${BOLD}─────────────────────────────────────────────────────────────${NC}"
    echo -e "${BOLD}  Credenciales del lab${NC}"
    echo -e "${BOLD}─────────────────────────────────────────────────────────────${NC}"

    service_installed "opsn-dns" && \
        printf "  %-18s %-22s %-14s %s\n" "OPSN DNS" "admin" "Password" "http://localhost:$(_port OPSN_DNS_CONSOLE_PORT 5380)"

    service_installed "opsn-mail" && {
        printf "  %-18s %-22s %-14s %s\n" "OPSN Mail" "admin@opensec.lab" "Password" "http://localhost:$(_port OPSN_MAIL_WEBMAIL_PORT 8888)"
        printf "  %-18s %-22s %-14s %s\n" "" "user@opensec.lab" "Password" "(Thunderbird pre-configurado)"
    }

    service_installed "opsn-gophish" && \
        printf "  %-18s %-22s %-14s %s\n" "OPSN GoPhish" "admin" "$(_port OPSN_GOPHISH_PASSWORD Password)" "https://localhost:$(_port OPSN_GOPHISH_ADMIN_PORT 3333)"

    service_installed "opsn-desktop" && \
        printf "  %-18s %-22s %-14s %s\n" "OPSN Desktop" "abc" "abc" "http://localhost:$(_port OPSN_DESKTOP_PORT 3100)"

    service_installed "opsn-dvwa" && \
        printf "  %-18s %-22s %-14s %s\n" "OPSN DVWA" "admin" "admin" "http://localhost:$(_port OPSN_DVWA_PORT 8080)"

    service_installed "opsn-juice-shop" && \
        printf "  %-18s %-22s %-14s %s\n" "OPSN Juice Shop" "(reto)" "(reto)" "http://localhost:$(_port OPSN_JUICE_PORT 3000)"

    service_installed "opsn-webgoat" && \
        printf "  %-18s %-22s %-14s %s\n" "OPSN WebGoat" "guest" "(sin auth)" "http://localhost:$(_port OPSN_WEBGOAT_PORT 8081)/WebGoat"

    service_installed "opsn-api" && \
        printf "  %-18s %-22s %-14s %s\n" "OPSN API" "(ver /api/health)" "(abierta)" "http://localhost:$(_port OPSN_API_PORT 8025)"

    service_installed "opsn-gitea" && \
        printf "  %-18s %-22s %-14s %s\n" "OPSN Gitea" "$(_port OPSN_GITEA_ADMIN_USER admin)" "$(_port OPSN_GITEA_PASSWORD Password)" "http://localhost:$(_port OPSN_GITEA_PORT 3002)"

    service_installed "opsn-docs" && \
        printf "  %-18s %-22s %-14s %s\n" "OPSN Docs" "(documentacion)" "(abierta)" "http://localhost:$(_port OPSN_DOCS_PORT 4000)"

    service_installed "opsn-portal" && \
        printf "  %-18s %-22s %-14s %s\n" "OPSN Portal" "(dashboard)" "(abierto)" "http://localhost:$(_port OPSN_PORTAL_PORT 8443)"

    service_installed "opsn-wazuh" && {
        printf "  %-18s %-22s %-14s %s\n" "Wazuh Dashboard" "admin" "$(_port OPSN_WAZUH_PASSWORD Password1.)" "https://localhost:$(_port OPSN_WAZUH_DASH_PORT 5601)"
        printf "  %-18s %-22s %-14s %s\n" "Wazuh API" "wazuh-wui" "$(_port OPSN_WAZUH_API_PASSWORD WazuhApiP4ss.)" "https://localhost:$(_port OPSN_WAZUH_API_PORT 55000)"
    }

    echo -e "${BOLD}─────────────────────────────────────────────────────────────${NC}"
    echo ""
    echo "  Para gestionar el lab: $LAB_DIR/opensec-lab.sh"
    echo ""
}

# ─────────────────────────────────────────────────────────────────
# ESTADO ACTUAL
# ─────────────────────────────────────────────────────────────────
mostrar_estado() {
    echo ""
    echo -e "${BOLD}Estado actual del lab:${NC}"
    echo ""

    local any=false
    for entry in "${SERVICES_CATALOG[@]}"; do
        local name desc
        name=$(echo "$entry" | cut -d'|' -f1)
        desc=$(echo "$entry" | cut -d'|' -f2)
        if service_installed "$name"; then
            any=true
            # opsn-wazuh agrupa varios contenedores; basta con que el manager corra
            local check_name="$name"
            [[ "$name" == "opsn-wazuh" ]] && check_name="opsn-wazuh-manager"
            if container_running "$check_name"; then
                echo -e "  ${GREEN}●${NC} $name — $desc"
            else
                echo -e "  ${YELLOW}○${NC} $name — $desc ${YELLOW}(detenido)${NC}"
            fi
        fi
    done

    if [[ "$any" == "false" ]]; then
        echo "  No hay servicios instalados."
    fi
    echo ""
}

# ─────────────────────────────────────────────────────────────────
# MENÚ PRINCIPAL — PRIMERA INSTALACIÓN
# ─────────────────────────────────────────────────────────────────
menu_instalacion() {
    banner
    echo "  Bienvenido a OpenSec Lab."
    echo "  Este asistente instalará los servicios que selecciones."
    echo ""

    check_prerequisites
    sudo_docker

    # Crear directorio del lab
    mkdir -p "$LAB_DIR/services"
    touch "$LOG_FILE"
    touch "$PROFILES_FILE"

    # Descargar archivos base
    descargar_archivos_base

    # Seleccionar servicios
    seleccionar_servicios "install"

    if [[ ${#SELECTED_SERVICES[@]} -eq 0 ]]; then
        log_warn "No se seleccionaron servicios. Saliendo."
        exit 0
    fi

    instalar_servicios "${SELECTED_SERVICES[@]}"
}

# ─────────────────────────────────────────────────────────────────
# MODO TALLER — API Breach to Detection
# ─────────────────────────────────────────────────────────────────
taller_api_breach() {
    log_step "Modo taller: API Breach to Detection"
    echo ""
    echo "  Este taller instala el camino ataque-deteccion de APIs."
    echo "  Perfil ofensivo (ligero):   api + docs + portal      (~6 GB RAM)"
    echo "  Camino azul completo:       + wazuh + suricata + dns  (~12 GB RAM)"
    echo ""
    read -r -p "  Incluir el lado azul (Wazuh)? Requiere ~12 GB [s/N]: " incluir_azul

    # Construir la lista de servicios y rutear por instalar_servicios, que ya
    # descarga los tarballs, verifica vm.max_map_count (Wazuh), resuelve
    # dependencias (wazuh→dns+suricata), persiste .active_profiles y crea la red.
    local servicios=(opsn-api opsn-docs opsn-portal)
    if [[ "$incluir_azul" =~ ^[sSyY]$ ]]; then
        servicios+=(opsn-wazuh)
    fi

    instalar_servicios "${servicios[@]}" || {
        log_error "Fallo la instalacion del taller."
        return 1
    }

    echo ""
    log_info "Taller listo. Proximos pasos:"
    local docs_port portal_port wazuh_port
    docs_port=$(grep "^OPSN_DOCS_PORT=" "$ENV_FILE" 2>/dev/null | cut -d= -f2 | tr -d '"'); docs_port=${docs_port:-4000}
    portal_port=$(grep "^OPSN_PORTAL_PORT=" "$ENV_FILE" 2>/dev/null | cut -d= -f2 | tr -d '"'); portal_port=${portal_port:-8443}
    wazuh_port=$(grep "^OPSN_WAZUH_DASH_PORT=" "$ENV_FILE" 2>/dev/null | cut -d= -f2 | tr -d '"'); wazuh_port=${wazuh_port:-5601}
    echo "  1. Guia del estudiante:  http://localhost:${docs_port}/workshops/api-breach/"
    echo "  2. Verifica el camino:   vuelve al menu y elige [13] Doctor"
    echo "  3. Portal del lab:       http://localhost:${portal_port}"
    if [[ "$incluir_azul" =~ ^[sSyY]$ ]]; then
        echo "  4. Wazuh Dashboard:      https://localhost:${wazuh_port} (admin/admin)"
        echo "     (Wazuh tarda 1-3 min en indexar tras los primeros ataques)"
    fi
}

# Verificacion autocontenida del taller (no depende de tests/, que no se
# empaqueta en el release). Dispara los 3 ataques y confirma sus eventos.
doctor_taller() {
    log_step "Doctor: verificando el camino del taller API Breach"
    local api_port api_base token
    api_port=$(grep "^OPSN_API_PORT=" "$ENV_FILE" 2>/dev/null | cut -d= -f2 | tr -d '"'); api_port=${api_port:-8025}
    api_base="http://localhost:${api_port}"

    if curl -s --max-time 8 "${api_base}/api/health" | grep -q '"status": *"ok"'; then
        log_info "API responde en ${api_base}"
    else
        log_error "La API no responde en ${api_base}. Instala el taller con la opcion 12."
        return 1
    fi

    token=$(curl -s --max-time 8 -X POST "${api_base}/api/auth/login" \
        -H 'Content-Type: application/json' \
        -d '{"username":"alice","password":"alice123"}' \
        | sed -n 's/.*"token"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
    if [[ "$token" == "token_alice" ]]; then
        log_info "Login de alice OK"
    else
        log_error "Login de alice fallo."
        return 1
    fi

    # Reset de rol (reejecutable) y disparo de los 3 ataques en el orden correcto.
    curl -s --max-time 8 -X PUT "${api_base}/api/users/1/profile" -H "Authorization: Bearer ${token}" -H 'Content-Type: application/json' -d '{"role":"user"}' >/dev/null
    curl -s --max-time 8 "${api_base}/api/users/2/profile" -H "Authorization: Bearer ${token}" >/dev/null
    curl -s --max-time 8 "${api_base}/api/admin/users" -H "Authorization: Bearer ${token}" >/dev/null
    curl -s --max-time 8 -X PUT "${api_base}/api/users/1/profile" -H "Authorization: Bearer ${token}" -H 'Content-Type: application/json' -d '{"email":"alice+lab@opensec.lab","role":"admin"}' >/dev/null

    local ok=true
    for ev in bola_attempt mass_assignment_attempt broken_function_auth; do
        if $SUDO_CMD docker exec opsn-api sh -lc "grep -q '\"event\": \"${ev}\"' /logs/api.log 2>/dev/null || grep -q '\"event\":\"${ev}\"' /logs/api.log 2>/dev/null"; then
            log_info "Evento ${ev} registrado"
        else
            log_warn "Evento ${ev} no encontrado en el log de la API"
            ok=false
        fi
    done

    if $SUDO_CMD docker ps --format '{{.Names}}' 2>/dev/null | grep -qx opsn-wazuh-indexer; then
        log_info "Wazuh activo — revisa el dashboard (filtro rule.groups: openseclab_api)"
    else
        log_warn "Wazuh no activo — camino solo-ofensivo (sin deteccion en SIEM)"
    fi

    if [[ "$ok" == "true" ]]; then
        log_info "Doctor: camino del taller OK"
    else
        log_warn "Doctor: faltan eventos — revisa que opsn-api este corriendo"
        return 1
    fi
}

# ─────────────────────────────────────────────────────────────────
# MENÚ PRINCIPAL — GESTIÓN (instalación existente)
# ─────────────────────────────────────────────────────────────────
menu_gestion() {
    while true; do
        banner
        mostrar_estado

        echo -e "${BOLD}¿Qué deseas hacer?${NC}"
        echo ""
        echo "  1) Instalar más servicios"
        echo "  2) Reinstalar servicios"
        echo "  3) Detener servicios (seleccionar)"
        echo "  4) Detener todos los servicios"
        echo "  5) Reanudar servicios (seleccionar)"
        echo "  6) Reanudar todos los servicios"
        echo "  7) Reiniciar todos los servicios"
        echo "  8) Eliminar servicios"
        echo "  9) Ver credenciales"
        echo " 10) Borrar todo (desinstalar)"
        echo " 11) Salir"
        echo ""
        echo " 12) Modo taller — API Breach to Detection"
        echo " 13) Doctor — verificar el camino del taller"
        echo ""
        echo -n "  Opción: "
        read -r option

        case "$option" in
            1)
                seleccionar_servicios "install"
                if [[ ${#SELECTED_SERVICES[@]} -gt 0 ]]; then
                    instalar_servicios "${SELECTED_SERVICES[@]}"
                fi
                ;;
            2)
                seleccionar_servicios "remove"
                if [[ ${#SELECTED_SERVICES[@]} -gt 0 ]]; then
                    reinstalar_servicios "${SELECTED_SERVICES[@]}"
                fi
                ;;
            3)
                seleccionar_servicios "remove"
                if [[ ${#SELECTED_SERVICES[@]} -gt 0 ]]; then
                    detener_servicios "${SELECTED_SERVICES[@]}"
                fi
                ;;
            4)
                log_step "Deteniendo todos los servicios..."
                local flags
                flags=$(profiles_to_flags)
                # shellcheck disable=SC2086
                $SUDO_CMD docker compose -f "$DC_FILE" --env-file "$ENV_FILE" $flags stop
                log_info "Todos los servicios detenidos."
                ;;
            5)
                seleccionar_servicios "remove"
                if [[ ${#SELECTED_SERVICES[@]} -gt 0 ]]; then
                    reanudar_servicios "${SELECTED_SERVICES[@]}"
                fi
                ;;
            6)
                log_step "Reanudando todos los servicios..."
                local flags
                flags=$(profiles_to_flags)
                # shellcheck disable=SC2086
                $SUDO_CMD docker compose -f "$DC_FILE" --env-file "$ENV_FILE" $flags start
                log_info "Todos los servicios reanudados."
                ;;
            7)
                log_step "Reiniciando servicios..."
                local flags
                flags=$(profiles_to_flags)
                # shellcheck disable=SC2086
                $SUDO_CMD docker compose -f "$DC_FILE" --env-file "$ENV_FILE" $flags restart
                log_info "Servicios reiniciados."
                ;;
            8)
                seleccionar_servicios "remove"
                if [[ ${#SELECTED_SERVICES[@]} -gt 0 ]]; then
                    echo -n "  ¿Confirmar eliminación de ${SELECTED_SERVICES[*]}? [s/N]: "
                    read -r confirm
                    if [[ "$confirm" =~ ^[sS]$ ]]; then
                        eliminar_servicios "${SELECTED_SERVICES[@]}"
                        log_info "Servicios eliminados."
                    fi
                fi
                ;;
            9)
                mostrar_credenciales
                echo -n "  Presiona Enter para continuar..."
                read -r
                ;;
            10)
                borrar_todo
                exit 0
                ;;
            11)
                echo ""
                log_info "Hasta pronto."
                exit 0
                ;;
            12)
                taller_api_breach
                ;;
            13)
                doctor_taller
                ;;
            *)
                log_warn "Opción inválida."
                ;;
        esac
    done
}

# ─────────────────────────────────────────────────────────────────
# PUNTO DE ENTRADA
# ─────────────────────────────────────────────────────────────────
main() {
    # Si ya existe una instalación previa, ir al menú de gestión
    if [[ -f "$PROFILES_FILE" && -f "$DC_FILE" ]]; then
        sudo_docker
        menu_gestion
    else
        menu_instalacion
    fi
}

main "$@"
