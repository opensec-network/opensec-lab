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

# Configurar perfil de Thunderbird para opsn-mail
THUNDER_PROFILE="/config/.thunderbird"
PROFILE_DIR="$THUNDER_PROFILE/opsn.default-release"

if [ ! -f "/config/.thunderbird_configured" ]; then
    echo "Configurando Thunderbird para opsn-mail..."

    # Instalar dependencias
    apt-get update -qq && apt-get install -y -qq libnss3-tools python3 > /dev/null 2>&1

    mkdir -p "$PROFILE_DIR"

    # 1. profiles.ini — perfil con nombre fijo
    cat > "$THUNDER_PROFILE/profiles.ini" << 'PROFILES'
[Profile0]
Name=default-release
IsRelative=1
Path=opsn.default-release
Default=1

[General]
StartWithLastProfile=1
Version=2
PROFILES

    # 2. user.js — configuración de cuenta IMAP/SMTP (se aplica en cada inicio de Thunderbird)
    cat > "$PROFILE_DIR/user.js" << 'USERJS'
// Cuenta IMAP - mail.opensec.lab
user_pref("mail.accountmanager.accounts", "account1");
user_pref("mail.accountmanager.defaultaccount", "account1");
user_pref("mail.account.account1.identities", "id1");
user_pref("mail.account.account1.server", "server1");

// Servidor IMAP
user_pref("mail.server.server1.hostname", "mail.opensec.lab");
user_pref("mail.server.server1.port", 143);
user_pref("mail.server.server1.type", "imap");
user_pref("mail.server.server1.userName", "admin");
user_pref("mail.server.server1.socketType", 0);
user_pref("mail.server.server1.authMethod", 3);
user_pref("mail.server.server1.name", "OpenSec Mail");

// Identidad
user_pref("mail.identity.id1.fullName", "Admin");
user_pref("mail.identity.id1.useremail", "admin@opensec.lab");
user_pref("mail.identity.id1.smtpServer", "smtp1");
user_pref("mail.identity.id1.valid", true);

// Servidor SMTP
user_pref("mail.smtpservers", "smtp1");
user_pref("mail.smtpserver.smtp1.hostname", "mail.opensec.lab");
user_pref("mail.smtpserver.smtp1.port", 587);
user_pref("mail.smtpserver.smtp1.authMethod", 3);
user_pref("mail.smtpserver.smtp1.socketType", 0);
user_pref("mail.smtpserver.smtp1.username", "admin");
user_pref("mail.smtpserver.smtp1.description", "OpenSec Mail SMTP");
user_pref("mail.smtp.defaultserver", "smtp1");

// Desactivar wizard de primera ejecución
user_pref("mail.provider.enabled", false);
user_pref("mail.shell.checkDefaultClient", false);
user_pref("mailnews.start_page.enabled", false);
user_pref("mail.rights.version", 1);
USERJS

    # 3. Generar key4.db con certutil
    certutil -N -d sql:"$PROFILE_DIR" --empty-password

    # 4. Generar logins.json usando la NSS bundleada de Thunderbird (no la del sistema Ubuntu)
    # proot-apps instala Thunderbird con sus propias libs Mozilla NSS en /config/proot-apps/
    MOZILLA_NSS=$(find /config/proot-apps -name "libnss3.so" 2>/dev/null | head -1)

    if [ -n "$MOZILLA_NSS" ]; then
        MOZILLA_NSS_DIR=$(dirname "$MOZILLA_NSS")
        echo "  NSS Mozilla encontrada en: $MOZILLA_NSS_DIR"

        cat > /tmp/gen_logins.py << 'PYEOF'
import ctypes, base64, json, os, time, sys, glob

PROFILE_DIR = "/config/.thunderbird/opsn.default-release"
nss_path = os.environ["MOZILLA_NSS_LIB"]
nss_dir  = os.path.dirname(nss_path)

class SECItem(ctypes.Structure):
    _fields_ = [("type", ctypes.c_uint), ("data", ctypes.POINTER(ctypes.c_ubyte)), ("len", ctypes.c_uint)]

# Precargar libs Mozilla (freebl, softokn) antes de libnss3
for pat in ["libfreebl*.so*", "libsoftokn*.so*"]:
    for lib in sorted(glob.glob(os.path.join(nss_dir, pat))):
        try: ctypes.CDLL(lib, ctypes.RTLD_GLOBAL)
        except: pass

nss = ctypes.CDLL(nss_path)
nss.NSS_Init.restype = ctypes.c_int
if nss.NSS_Init(("sql:" + PROFILE_DIR).encode()) != 0:
    print("NSS_Init fallo", file=sys.stderr)
    sys.exit(1)

def encrypt(text):
    data = text.encode()
    inp = SECItem(0, (ctypes.c_ubyte * len(data))(*data), len(data))
    out = SECItem()
    if nss.PK11SDR_Encrypt(None, ctypes.byref(inp), ctypes.byref(out), None) != 0:
        raise RuntimeError("PK11SDR_Encrypt fallo")
    return base64.b64encode(bytes(out.data[:out.len])).decode()

enc_user = encrypt("admin")
enc_pass = encrypt("Password")
now = int(time.time() * 1000)

logins = {"nextId": 3, "logins": [
    {"id":1,"hostname":"imap://mail.opensec.lab","httpRealm":"mail.opensec.lab",
     "formSubmitURL":None,"usernameField":"","passwordField":"",
     "encryptedUsername":enc_user,"encryptedPassword":enc_pass,
     "guid":"{opsn-imap-0001}","encType":1,
     "timeCreated":now,"timeLastUsed":now,"timePasswordChanged":now,"timesUsed":1},
    {"id":2,"hostname":"smtp://mail.opensec.lab","httpRealm":"mail.opensec.lab",
     "formSubmitURL":None,"usernameField":"","passwordField":"",
     "encryptedUsername":enc_user,"encryptedPassword":enc_pass,
     "guid":"{opsn-smtp-0001}","encType":1,
     "timeCreated":now,"timeLastUsed":now,"timePasswordChanged":now,"timesUsed":1}
], "potentiallyVulnerablePasswords":[], "dismissedBreachAlertsByLoginGUID":{}, "version":3}

with open(os.path.join(PROFILE_DIR, "logins.json"), "w") as f:
    json.dump(logins, f, indent=2)
nss.NSS_Shutdown()
print("logins.json generado")
PYEOF

        MOZILLA_NSS_LIB="$MOZILLA_NSS" \
            LD_LIBRARY_PATH="$MOZILLA_NSS_DIR:${LD_LIBRARY_PATH:-}" \
            python3 /tmp/gen_logins.py \
            && echo "  Contraseña pre-configurada correctamente" \
            || echo "  AVISO: contraseña no guardada — Thunderbird la pedira la primera vez (escribir: Password)"
    else
        echo "  AVISO: NSS Mozilla no encontrada — contraseña no guardada. Thunderbird la pedira la primera vez (escribir: Password)"
    fi

    # 5. Permisos correctos para usuario abc (UID 1000)
    chown -R abc:abc "$THUNDER_PROFILE"
    touch /config/.thunderbird_configured

    echo "Thunderbird configurado: admin@opensec.lab"
fi

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
