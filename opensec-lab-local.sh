#!/bin/bash
# opensec-lab-local.sh — Versión para pruebas locales
#
# Usa los archivos del repo directamente en lugar de descargarlos
# desde un GitHub Release. Solo sobreescribe las funciones de descarga
# y el banner; toda la lógica del script principal se hereda intacta.
#
# Uso:
#   bash opensec-lab-local.sh
#
# Requiere estar ejecutado desde el directorio opensec-lab-v1/ o
# ajustar LOCAL_REPO abajo.

set -uo pipefail

# ─────────────────────────────────────────────────────────────────
# RUTA AL REPO LOCAL
# ─────────────────────────────────────────────────────────────────
# Apunta al directorio opensec-lab-v1 (donde vive este script)
LOCAL_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Directorio de instalación separado para no mezclar con producción
LAB_DIR="${HOME}/OpenSec_Lab_Test"

# ─────────────────────────────────────────────────────────────────
# CARGAR EL SCRIPT PRINCIPAL SIN EJECUTARLO
# Se elimina la línea "main "$@"" antes de hacer source para evitar
# que se ejecute dos veces.
# ─────────────────────────────────────────────────────────────────
source <(grep -v '^main "\$@"$' "${LOCAL_REPO}/opensec-lab.sh")

# El source sobreescribe LAB_DIR con el valor de producción — restablecerlo
LAB_DIR="${HOME}/OpenSec_Lab_Test"
DC_FILE="$LAB_DIR/docker-compose.yml"
ENV_FILE="$LAB_DIR/.env"
PROFILES_FILE="$LAB_DIR/.active_profiles"
LOG_FILE="$LAB_DIR/opensec-lab.log"

# ─────────────────────────────────────────────────────────────────
# OVERRIDE: banner
# Agrega el aviso de modo local al banner estándar.
# ─────────────────────────────────────────────────────────────────
eval "$(declare -f banner | sed 's/^banner/_opsn_banner/')"

banner() {
    _opsn_banner
    echo -e "${YELLOW}${BOLD}  [MODO LOCAL] Usando archivos de: ${LOCAL_REPO}${NC}"
    echo -e "${YELLOW}  Directorio de instalación:        ${LAB_DIR}${NC}"
    echo ""
}

# ─────────────────────────────────────────────────────────────────
# OVERRIDE: descargar_archivos_base
# Copia docker-compose.yml y defaults.env desde el repo local
# en lugar de descargarlos desde GitHub Release.
# ─────────────────────────────────────────────────────────────────
descargar_archivos_base() {
    log_step "[LOCAL] Copiando archivos base desde ${LOCAL_REPO}..."

    cp "${LOCAL_REPO}/docker-compose.yml" "$DC_FILE"
    log_info "docker-compose.yml copiado."

    if [[ ! -f "$ENV_FILE" ]]; then
        cp "${LOCAL_REPO}/config/defaults.env" "$ENV_FILE"
        log_info ".env creado desde config/defaults.env."
    else
        log_info ".env ya existe. No se sobreescribe."
    fi

    # Guardar copia del script local para gestión futura
    if [[ ! -f "$LAB_DIR/opensec-lab.sh" ]]; then
        cp "${LOCAL_REPO}/opensec-lab-local.sh" "$LAB_DIR/opensec-lab.sh"
        chmod +x "$LAB_DIR/opensec-lab.sh"
        log_info "Script guardado en $LAB_DIR/opensec-lab.sh para gestión futura."
    fi
}

# ─────────────────────────────────────────────────────────────────
# OVERRIDE: descargar_paquete_servicio
# Copia el directorio services/<nombre> desde el repo local
# en lugar de descargar y extraer un tarball.
# ─────────────────────────────────────────────────────────────────
descargar_paquete_servicio() {
    local service="$1"
    local short="${service#opsn-}"
    local src="${LOCAL_REPO}/services/${short}"
    local dest="$LAB_DIR/services/${short}"

    if [[ -d "$dest" ]]; then
        log_info "Archivos de $service ya presentes."
        return 0
    fi

    if [[ ! -d "$src" ]]; then
        log_error "[LOCAL] No se encontró services/${short} en ${LOCAL_REPO}"
        return 1
    fi

    log_step "[LOCAL] Copiando archivos de $service desde el repo..."
    cp -r "$src" "$dest"
    log_info "Archivos de $service copiados."
}

# ─────────────────────────────────────────────────────────────────
# PUNTO DE ENTRADA
# ─────────────────────────────────────────────────────────────────
main "$@"
