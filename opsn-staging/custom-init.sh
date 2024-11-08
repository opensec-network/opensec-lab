#!/usr/bin/with-contenv bash

echo "Iniciando script personalizado de instalación y configuración"

# Instalar Thunderbird si no está instalado
su abc -c "
  PROOT_APPS=\$HOME/.local/bin/proot-apps
  if [ -f \$PROOT_APPS ]; then
    if [ ! -f \$HOME/.thunderbird_installed ]; then
      echo \"Instalando Thunderbird...\"
      if \$PROOT_APPS install thunderbird; then
        touch \$HOME/.thunderbird_installed
        echo \"Thunderbird instalado exitosamente.\"
      else
        echo \"Error al instalar Thunderbird.\"
      fi
    else
      echo \"Thunderbird ya está instalado.\"
    fi
  else
    echo \"Error: proot-apps no encontrado en \$PROOT_APPS\"
  fi
"

# Crear script para cambiar el wallpaper
cat > /config/change-wallpaper.sh << EOL
#!/bin/bash

NEW_WALLPAPER="/config/opsn-background.jpg"
LOG_FILE="/config/wallpaper_change.log"

log_message() {
    echo "\$(date): \$1" >> "\$LOG_FILE"
}

change_wallpaper() {
    if [ ! -f "\$NEW_WALLPAPER" ]; then
        log_message "Error: El archivo de wallpaper \$NEW_WALLPAPER no existe."
        return 1
    fi

    log_message "Intentando cambiar el wallpaper"

    qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "
        var allDesktops = desktops();
        for (i=0;i<allDesktops.length;i++) {
            d = allDesktops[i];
            d.wallpaperPlugin = 'org.kde.image';
            d.currentConfigGroup = Array('Wallpaper', 'org.kde.image', 'General');
            d.writeConfig('Image', 'file://\$NEW_WALLPAPER');
            d.writeConfig('FillMode', 2);
            d.writeConfig('PreserveAspectFit', true);
            d.writeConfig('SlidePaths', '/config');
        }
    "

    log_message "Comando para cambiar el wallpaper ejecutado"
}

# Esperar a que KDE esté completamente iniciado
sleep 15

# Intentar cambiar el wallpaper
change_wallpaper

# Forzar actualización del escritorio
qdbus org.kde.KWin /KWin org.kde.KWin.reconfigure

exit 0
EOL

chmod +x /config/change-wallpaper.sh

# Crear archivo .desktop para autostart
mkdir -p /config/.config/autostart
cat > /config/.config/autostart/change-wallpaper.desktop << EOL
[Desktop Entry]
Type=Application
Exec=/config/change-wallpaper.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name[en_US]=Change Wallpaper
Name=Change Wallpaper
Comment[en_US]=Changes the wallpaper on login
Comment=Changes the wallpaper on login
EOL

echo "Script personalizado de instalación y configuración completado"