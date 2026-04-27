#!/bin/bash

# Lee variables de entorno con valores por defecto
OPSN_DOMAIN="${OPSN_DOMAIN:-opensec.lab}"
OPSN_MAIL_PASSWORD="${OPSN_MAIL_PASSWORD:-Password}"

# Crear usuario vmail para Dovecot si no existe
if ! id "vmail" &>/dev/null; then
    groupadd -g 5000 vmail
    useradd -u 5000 -g vmail -s /usr/sbin/nologin -d /var/mail vmail
fi

# Crear directorios de correo
mkdir -p /var/mail
chown -R vmail:vmail /var/mail

# Crear archivo de usuarios de Dovecot
if [ ! -f /etc/dovecot/users ]; then
    printf 'admin:{PLAIN}%s\nuser:{PLAIN}%s\n' \
        "${OPSN_MAIL_PASSWORD}" "${OPSN_MAIL_PASSWORD}" > /etc/dovecot/users
    chown root:dovecot /etc/dovecot/users
    chmod 640 /etc/dovecot/users
fi

# Configurar mailname y postfix con el dominio correcto
echo "${OPSN_DOMAIN}" > /etc/mailname

# Aplicar variables al template de postfix/main.cf
export OPSN_DOMAIN
envsubst '${OPSN_DOMAIN}' \
    < /etc/postfix/main.cf.template \
    > /etc/postfix/main.cf

# Asegurar que el directorio de Postfix existe
mkdir -p /var/spool/postfix/private

# Asegurar permisos de Roundcube
chown -R www-data:www-data /var/www/html/roundcube/temp /var/www/html/roundcube/logs 2>/dev/null
mkdir -p /var/www/html/roundcube/config
chown -R www-data:www-data /var/www/html/roundcube/config

# Iniciar Supervisor
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
