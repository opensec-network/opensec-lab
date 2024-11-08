#!/usr/bin/with-contenv bash

# Función para registrar mensajes
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> /config/init_and_install.log
}

log "Iniciando script de inicialización y instalación"

# Crear y configurar /tmp/.X11-unix
log "Configurando /tmp/.X11-unix"
mkdir -p /tmp/.X11-unix
chmod 1777 /tmp/.X11-unix
chown root:root /tmp/.X11-unix
log "Directorio /tmp/.X11-unix creado y configurado"
