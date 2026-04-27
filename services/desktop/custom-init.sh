#!/usr/bin/with-contenv bash

# Fix: bug en Selkies donde el handler de clicks usa window.isManualResolutionMode
# (camelCase) pero el servidor setea window.is_manual_resolution_mode (snake_case).
# En pantallas Retina (DPR=2) esto causa que las coordenadas se dupliquen.
# Solución: parchear el JS para que use ambas variables en el handler de clicks.
SELKIES_JS=$(find /usr/share/selkies/web/assets -name "index-*.js" 2>/dev/null | head -1)
if [ -n "$SELKIES_JS" ] && ! grep -q "opsn_patched" "$SELKIES_JS"; then
    sed -i \
        's/window\.isManualResolutionMode&&b/\(window.is_manual_resolution_mode||window.isManualResolutionMode\)\&\&(v||b)/g' \
        "$SELKIES_JS"
    echo "// opsn_patched" >> "$SELKIES_JS"
    # Añadir ?v=opsn1 al src del JS en index.html para forzar re-descarga y evitar caché del navegador
    SELKIES_HTML="/usr/share/selkies/web/index.html"
    JS_BASENAME=$(basename "$SELKIES_JS")
    if [ -f "$SELKIES_HTML" ] && ! grep -q "?v=opsn" "$SELKIES_HTML"; then
        sed -i "s|${JS_BASENAME}|${JS_BASENAME}?v=opsn1|g" "$SELKIES_HTML"
    fi
    echo "Selkies JS parcheado: fix click DPR aplicado"
fi

# Cambiar título de la pestaña del navegador: manifest.json es la fuente del título
SELKIES_MANIFEST="/usr/share/selkies/web/manifest.json"
if [ -f "$SELKIES_MANIFEST" ] && grep -q "Ubuntu XFCE" "$SELKIES_MANIFEST"; then
    sed -i 's/Ubuntu XFCE/OPSN Desktop/g' "$SELKIES_MANIFEST"
    echo "Selkies manifest parcheado: título cambiado a OPSN Desktop"
fi

# Variables de entorno con valores por defecto
OPSN_DOMAIN="${OPSN_DOMAIN:-opensec.lab}"
OPSN_MAIL_HOST="${OPSN_MAIL_HOST:-mail.opensec.lab}"
OPSN_MAIL_USER="${OPSN_MAIL_USER:-user}"
OPSN_MAIL_PASSWORD="${OPSN_MAIL_PASSWORD:-Password}"
OPSN_MAIL_SMTP_PORT="${OPSN_MAIL_SMTP_PORT:-587}"
OPSN_MAIL_IMAP_PORT="${OPSN_MAIL_IMAP_PORT:-143}"
# Display name: primera letra en mayúscula (ej: "user" → "User", "admin" → "Admin")
OPSN_MAIL_DISPLAY_NAME="${OPSN_MAIL_USER^}"

# Crear script de wallpaper (siempre, es rápido)
cat > /config/change-wallpaper.sh << 'EOL'
#!/bin/bash

NEW_WALLPAPER="/config/opsn-background.jpg"
LOG_FILE="/config/wallpaper_change.log"

log_message() {
    echo "$(date): $1" >> "$LOG_FILE"
}

if [ ! -f "$NEW_WALLPAPER" ]; then
    log_message "Error: El archivo $NEW_WALLPAPER no existe."
    exit 1
fi

# Esperar a que xfdesktop esté corriendo antes de intentar xfconf-query
for w in $(seq 1 30); do
    pgrep -x xfdesktop > /dev/null 2>&1 && break
    sleep 5
done

# Iterar hasta 24 veces (240s) para cubrir monitores que se inicializan tarde
# (ej: selkies-primary aparece después de screen en Selkies/XFCE)
applied=0
for i in $(seq 1 24); do
    sleep 10
    MONITORS=$(xfconf-query --channel xfce4-desktop --list 2>/dev/null | grep "last-image")
    [ -z "$MONITORS" ] && continue

    changed=0
    for PROP in $MONITORS; do
        current=$(xfconf-query --channel xfce4-desktop --property "$PROP" 2>/dev/null)
        if [ "$current" != "$NEW_WALLPAPER" ]; then
            xfconf-query --channel xfce4-desktop --property "$PROP" --set "$NEW_WALLPAPER" 2>/dev/null
            changed=$((changed + 1))
        fi
    done

    if [ "$changed" -gt 0 ]; then
        xfdesktop --reload 2>/dev/null || true
        log_message "Wallpaper aplicado en $changed monitor(es) (intento $i)"
        applied=$((applied + 1))
    fi

    # Salir al pasar al menos 4 intentos con wallpaper ya aplicado
    [ "$i" -ge 4 ] && [ "$applied" -gt 0 ] && break
done

[ "$applied" -eq 0 ] && log_message "AVISO: no se encontraron monitores para cambiar el wallpaper"
exit 0
EOL

chmod +x /config/change-wallpaper.sh

mkdir -p /config/.config/autostart
cat > /config/.config/autostart/change-wallpaper.desktop << 'EOL'
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

# Si Thunderbird ya está configurado, salir de inmediato
if [ -f "/config/.thunderbird_configured" ]; then
    echo "Thunderbird ya configurado, saltando setup"
    exit 0
fi

# Escribir script de instalación/configuración de Thunderbird
cat > /config/opsn-tb-setup.sh << SETUP_EOF
#!/bin/bash
set -e

OPSN_DOMAIN="${OPSN_DOMAIN}"
OPSN_MAIL_HOST="${OPSN_MAIL_HOST}"
OPSN_MAIL_USER="${OPSN_MAIL_USER}"
OPSN_MAIL_PASSWORD="${OPSN_MAIL_PASSWORD}"
OPSN_MAIL_SMTP_PORT="${OPSN_MAIL_SMTP_PORT}"
OPSN_MAIL_IMAP_PORT="${OPSN_MAIL_IMAP_PORT}"

THUNDER_PROFILE="/config/.thunderbird"
PROFILE_DIR="\$THUNDER_PROFILE/opsn.default-release"

echo "[\$(date)] Instalando Thunderbird..."
su abc -c "
  PROOT_APPS=\\\$HOME/.local/bin/proot-apps
  if [ -f \\\$PROOT_APPS ]; then
    if [ ! -f \\\$HOME/.thunderbird_installed ]; then
      installed=0
      for attempt in 1 2 3; do
        echo \"Intento \\\$attempt de instalar Thunderbird...\"
        if \\\$PROOT_APPS install thunderbird; then
          touch \\\$HOME/.thunderbird_installed
          echo 'Thunderbird instalado exitosamente.'
          installed=1
          break
        fi
        echo \"Intento \\\$attempt fallido, reintentando en 15s...\"
        sleep 15
      done
      if [ \\\$installed -eq 0 ]; then
        echo '======================================================'
        echo 'AVISO: Thunderbird no se pudo instalar.'
        echo 'Causa probable: sin acceso a internet en este equipo.'
        echo 'El Desktop funcionara normalmente, pero sin cliente de correo.'
        echo 'Para instalar manualmente: abrir terminal y ejecutar:'
        echo '  proot-apps install thunderbird'
        echo '======================================================'
        exit 1
      fi
    else
      echo 'Thunderbird ya está instalado.'
    fi
  else
    echo 'Error: proot-apps no encontrado'
    exit 1
  fi
"

echo "[\$(date)] Aplicando policies.json para suprimir wizard..."
TB_DIST=\$(find /config/proot-apps -name "thunderbird" -path "*/usr/lib/thunderbird/thunderbird" 2>/dev/null | head -1 | xargs -I{} dirname {})
if [ -n "\$TB_DIST" ]; then
    mkdir -p "\$TB_DIST/distribution"
    cat > "\$TB_DIST/distribution/policies.json" << 'POLICIESEOF'
{
  "policies": {
    "NoDefaultMailClient": true,
    "Preferences": {
      "mail.provider.enabled": { "Value": false, "Status": "default" },
      "mail.shell.checkDefaultClient": { "Value": false, "Status": "default" },
      "mailnews.start_page.enabled": { "Value": false, "Status": "default" },
      "datareporting.policy.dataSubmissionPolicyBypassNotification": { "Value": true, "Status": "default" }
    }
  }
}
POLICIESEOF
    echo "  policies.json escrito en: \$TB_DIST/distribution/"
else
    echo "  AVISO: no se encontró directorio de Thunderbird para policies.json"
fi

echo "[\$(date)] Configurando Thunderbird..."

apt-get update -qq && apt-get install -y -qq libnss3-tools python3 > /dev/null 2>&1

mkdir -p "\$PROFILE_DIR"

cat > "\$THUNDER_PROFILE/profiles.ini" << 'PROFILES'
[Profile0]
Name=default-release
IsRelative=1
Path=opsn.default-release
Default=1

[General]
StartWithLastProfile=1
Version=2
PROFILES

mkdir -p "\$PROFILE_DIR/Mail/Local Folders"

cat > "\$PROFILE_DIR/user.js" << USERJS
// Cuentas: IMAP (account1) + Local Folders (account2, requerido por Thunderbird)
user_pref("mail.accountmanager.accounts", "account1,account2");
user_pref("mail.accountmanager.defaultaccount", "account1");
user_pref("mail.accountmanager.localfoldersserver", "server2");
user_pref("mail.account.account1.identities", "id1");
user_pref("mail.account.account1.server", "server1");
user_pref("mail.account.account2.server", "server2");

// Servidor IMAP
user_pref("mail.server.server1.hostname", "\${OPSN_MAIL_HOST}");
user_pref("mail.server.server1.port", \${OPSN_MAIL_IMAP_PORT});
user_pref("mail.server.server1.type", "imap");
user_pref("mail.server.server1.userName", "\${OPSN_MAIL_USER}");
user_pref("mail.server.server1.socketType", 0);
user_pref("mail.server.server1.authMethod", 3);
user_pref("mail.server.server1.name", "OpenSec Mail");

// Servidor Local Folders (requerido — sin él Thunderbird abre el wizard)
user_pref("mail.server.server2.hostname", "Local Folders");
user_pref("mail.server.server2.name", "Local Folders");
user_pref("mail.server.server2.type", "none");
user_pref("mail.server.server2.userName", "nobody");
user_pref("mail.server.server2.login_at_startup", false);
user_pref("mail.server.server2.directory-rel", "[ProfD]Mail/Local Folders");

// Identidad
user_pref("mail.identity.id1.fullName", "${OPSN_MAIL_DISPLAY_NAME}");
user_pref("mail.identity.id1.useremail", "\${OPSN_MAIL_USER}@\${OPSN_DOMAIN}");
user_pref("mail.identity.id1.smtpServer", "smtp1");
user_pref("mail.identity.id1.valid", true);

// Servidor SMTP
user_pref("mail.smtpservers", "smtp1");
user_pref("mail.smtpserver.smtp1.hostname", "\${OPSN_MAIL_HOST}");
user_pref("mail.smtpserver.smtp1.port", \${OPSN_MAIL_SMTP_PORT});
user_pref("mail.smtpserver.smtp1.authMethod", 3);
user_pref("mail.smtpserver.smtp1.socketType", 0);
user_pref("mail.smtpserver.smtp1.username", "\${OPSN_MAIL_USER}");
user_pref("mail.smtpserver.smtp1.description", "OpenSec Mail SMTP");
user_pref("mail.smtp.defaultserver", "smtp1");

// Desactivar wizard de primera ejecución y diálogos de bienvenida
user_pref("mail.provider.enabled", false);
user_pref("mail.shell.checkDefaultClient", false);
user_pref("mailnews.start_page.enabled", false);
user_pref("mail.rights.version", 1);
user_pref("app.normandy.enabled", false);
user_pref("datareporting.policy.dataSubmissionPolicyBypassNotification", true);
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("mail.tabs.autoHide", false);
USERJS

printf '\n\n' | certutil -N -d sql:"\$PROFILE_DIR" 2>/dev/null || true

MOZILLA_NSS=\$(find /config/proot-apps -name "libnss3.so" 2>/dev/null | head -1)

if [ -n "\$MOZILLA_NSS" ]; then
    MOZILLA_NSS_DIR=\$(dirname "\$MOZILLA_NSS")

    cat > /tmp/gen_logins.py << 'PYEOF'
import ctypes, base64, json, os, time, sys, glob

PROFILE_DIR = "/config/.thunderbird/opsn.default-release"
nss_path = os.environ["MOZILLA_NSS_LIB"]
nss_dir  = os.path.dirname(nss_path)

mail_host = os.environ.get("OPSN_MAIL_HOST", "mail.opensec.lab")
mail_user = os.environ.get("OPSN_MAIL_USER", "admin")
mail_pass = os.environ.get("OPSN_MAIL_PASSWORD", "Password")

class SECItem(ctypes.Structure):
    _fields_ = [("type", ctypes.c_uint), ("data", ctypes.POINTER(ctypes.c_ubyte)), ("len", ctypes.c_uint)]

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

enc_user = encrypt(mail_user)
enc_pass = encrypt(mail_pass)
now = int(time.time() * 1000)

logins = {"nextId": 3, "logins": [
    {"id":1,"hostname":f"imap://{mail_host}","httpRealm":mail_host,
     "formSubmitURL":None,"usernameField":"","passwordField":"",
     "encryptedUsername":enc_user,"encryptedPassword":enc_pass,
     "guid":"{opsn-imap-0001}","encType":1,
     "timeCreated":now,"timeLastUsed":now,"timePasswordChanged":now,"timesUsed":1},
    {"id":2,"hostname":f"smtp://{mail_host}","httpRealm":mail_host,
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

    MOZILLA_NSS_LIB="\$MOZILLA_NSS" \
    LD_LIBRARY_PATH="\$MOZILLA_NSS_DIR:\${LD_LIBRARY_PATH:-}" \
    OPSN_MAIL_HOST="\$OPSN_MAIL_HOST" \
    OPSN_MAIL_USER="\$OPSN_MAIL_USER" \
    OPSN_MAIL_PASSWORD="\$OPSN_MAIL_PASSWORD" \
        python3 /tmp/gen_logins.py \
        && echo "  Contraseña pre-configurada correctamente" \
        || echo "  AVISO: contraseña no guardada (Thunderbird la pedirá: \${OPSN_MAIL_PASSWORD})"
else
    echo "  AVISO: NSS Mozilla no encontrada — contraseña no guardada"
fi

chown -R abc:abc "\$THUNDER_PROFILE"

# Verificar que todo lo crítico existe antes de marcar como configurado
TB_BIN=\$(find /config/proot-apps -name "thunderbird" -path "*/bin/thunderbird" 2>/dev/null | head -1)
LOGINS_OK=\$([ -f "\$PROFILE_DIR/logins.json" ] && echo "yes" || echo "no")
USERJS_OK=\$([ -f "\$PROFILE_DIR/user.js" ] && echo "yes" || echo "no")

if [ -z "\$TB_BIN" ] || [ "\$LOGINS_OK" = "no" ] || [ "\$USERJS_OK" = "no" ]; then
    echo "[\$(date)] SETUP FALLIDO — TB_BIN=\$TB_BIN LOGINS=\$LOGINS_OK USERJS=\$USERJS_OK"
    echo "[\$(date)] El próximo restart reintentará la configuración"
    exit 1
fi

touch /config/.thunderbird_configured
echo "[\$(date)] Thunderbird configurado: \${OPSN_MAIL_USER}@\${OPSN_DOMAIN}"

# Monitor en background: cuando Thunderbird cree su perfil real via installs.ini,
# copia user.js ahí para que los prefs queden activos desde el primer arranque.
(
    for i in \$(seq 1 120); do
        sleep 5
        INSTALLS="\$THUNDER_PROFILE/installs.ini"
        [ -f "\$INSTALLS" ] || continue
        REAL_PROFILE=\$(grep "^Default=" "\$INSTALLS" | head -1 | cut -d= -f2)
        REAL_DIR="\$THUNDER_PROFILE/\$REAL_PROFILE"
        [ -n "\$REAL_PROFILE" ] && [ -d "\$REAL_DIR" ] && [ "\$REAL_PROFILE" != "opsn.default-release" ] || continue
        if ! grep -q "mail.provider.enabled" "\$REAL_DIR/user.js" 2>/dev/null; then
            cp "\$PROFILE_DIR/user.js" "\$REAL_DIR/user.js"
            chown abc:abc "\$REAL_DIR/user.js"
            mkdir -p "\$REAL_DIR/Mail/Local Folders"
            chown -R abc:abc "\$REAL_DIR/Mail"
            echo "[\$(date)] user.js aplicado al perfil real: \$REAL_PROFILE"
        fi
        break
    done
) >> /config/opsn-setup.log 2>&1 &
SETUP_EOF

chmod +x /config/opsn-tb-setup.sh

# Lanzar instalación en segundo plano y salir inmediatamente
nohup /config/opsn-tb-setup.sh > /config/opsn-setup.log 2>&1 &
disown

echo "Instalación de Thunderbird iniciada en segundo plano (ver /config/opsn-setup.log)"
exit 0
