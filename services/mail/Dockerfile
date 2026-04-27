FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Instalar dependencias
RUN apt-get update && \
    apt-get install -y \
        postfix \
        dovecot-core \
        dovecot-imapd \
        dovecot-pop3d \
        dovecot-lmtpd \
        supervisor \
        nginx \
        php-fpm \
        php-cli \
        php-mbstring \
        php-xml \
        php-intl \
        php-curl \
        php-sqlite3 \
        wget \
        gettext-base \
    && rm -rf /var/lib/apt/lists/*

# Instalar Roundcube 1.6.9
RUN wget -q https://github.com/roundcube/roundcubemail/releases/download/1.6.9/roundcubemail-1.6.9-complete.tar.gz && \
    tar -xzf roundcubemail-1.6.9-complete.tar.gz -C /var/www/html && \
    mv /var/www/html/roundcubemail-1.6.9 /var/www/html/roundcube && \
    rm roundcubemail-1.6.9-complete.tar.gz && \
    chown -R www-data:www-data /var/www/html/roundcube

# Copiar archivos de configuración
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY postfix/main.cf.template /etc/postfix/main.cf.template
COPY postfix/master.cf /etc/postfix/master.cf
COPY dovecot/dovecot.conf /etc/dovecot/dovecot.conf
COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY nginx/sites-available/roundcube.conf /etc/nginx/sites-available/roundcube.conf
COPY roundcube/config.inc.php /var/www/html/roundcube/config/config.inc.php
COPY entrypoint.sh /entrypoint.sh

# Configurar Nginx: quitar default site y habilitar Roundcube
RUN rm -f /etc/nginx/sites-enabled/default && \
    ln -sf /etc/nginx/sites-available/roundcube.conf /etc/nginx/sites-enabled/roundcube.conf

RUN chmod +x /entrypoint.sh

EXPOSE 25 143 587 80

VOLUME ["/var/mail", "/var/www/html/roundcube/config"]

ENTRYPOINT ["/entrypoint.sh"]
