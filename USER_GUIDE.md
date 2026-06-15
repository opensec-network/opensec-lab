# Guía de Usuario — OpenSec Lab v1

Laboratorio de ciberseguridad basado en Docker: practica ataques reales (web, API, phishing) y aprende a detectarlos en un SIEM real. Esta guía cubre los escenarios principales; el ejercicio de phishing es uno de ellos.

---

## API Vulnerable y el taller "API Breach to Detection"

La experiencia insignia del lab es el taller **API Breach to Detection**: explotas fallas de una API REST vulnerable (BOLA, mass assignment, broken function auth) y luego investigas la evidencia en Wazuh SIEM en tiempo real. Es el loop ataque→detección en un solo entorno.

El taller completo vive en `services/docs/docs/workshops/api-breach.md`. Cuando el servicio Docs está activo, accédelo en:
`http://localhost:4000/workshops/api-breach/`

> Para el catálogo completo de 12 servicios (API, Wazuh, Suricata, Portal, Docs, WebGoat, Gitea y más), consulta la tabla de servicios en el README.

---

## Índice

1. [Requisitos](#1-requisitos)
2. [Instalación](#2-instalación)
3. [Servicios y acceso](#3-servicios-y-acceso)
4. [GoPhish — Ejercicio de phishing](#4-gophish--ejercicio-de-phishing)
5. [Desktop — Víctima simulada](#5-desktop--víctima-simulada)
6. [Webmail (Roundcube)](#6-webmail-roundcube)
7. [DVWA — Aplicación web vulnerable](#7-dvwa--aplicación-web-vulnerable)
8. [Juice Shop — OWASP](#8-juice-shop--owasp)
9. [DNS — Technitium](#9-dns--technitium)
10. [Gestión del lab](#10-gestión-del-lab)
11. [Personalización](#11-personalización)
12. [Solución de problemas](#12-solución-de-problemas)

---

## 1. Requisitos

| Requisito | Mínimo |
|-----------|--------|
| Sistema operativo | Kali Linux, Ubuntu 22.04+ (AMD64 o ARM64) |
| Docker | 24.0+ con Docker Compose v2 |
| RAM | 6 GB disponibles |
| Disco | 20 GB libres |
| Red | Puerto 53, 80 y 443 libres en el host |

---

## 2. Instalación

Ejecuta el siguiente comando en tu terminal:

```bash
/bin/bash -c "$(curl -fsSL https://lab.opensec.network/install)"
```

El script guía la instalación paso a paso:

1. Verifica que Docker esté disponible
2. Descarga `docker-compose.yml` y la configuración base desde el último release
3. Presenta un menú para seleccionar los servicios a instalar
4. Descarga los archivos de cada servicio seleccionado
5. Levanta los contenedores con `docker compose up -d`
6. Muestra las credenciales de acceso

> **Dependencias automáticas:** GoPhish requiere DNS y Mail. Desktop y Mail también requieren DNS. El script los agrega automáticamente si seleccionas GoPhish o Desktop.

Después de la instalación, el lab queda en `~/OpenSec_Lab/`.

---

## 3. Servicios y acceso

| Servicio | URL | Usuario | Contraseña |
|----------|-----|---------|------------|
| GoPhish (admin) | https://localhost:3333 | `admin` | *(auto-generada — ver abajo)* |
| Desktop (Webtop) | http://localhost:3100 | `abc` | `abc` |
| Roundcube (webmail) | http://localhost:8888 | `admin` | `Password` |
| DVWA | http://localhost:8080 | `admin` | `password` |
| Juice Shop | http://localhost:3000 | — | *(es un reto)* |
| Technitium DNS | http://localhost:5380 | `admin` | `Password` |

> Esta tabla cubre los servicios del ejercicio de phishing. El lab incluye 12 servicios en total (WebGoat, API Vulnerable, Wazuh, Suricata, Gitea, Portal, Docs). Consulta la tabla completa en el [README](README.md).

### Obtener la contraseña de GoPhish

GoPhish genera una contraseña aleatoria al primer arranque. Para verla:

```bash
docker logs opsn-gophish 2>&1 | grep "Please login"
```

El script de instalación también la muestra al finalizar.

---

## 4. GoPhish — Ejercicio de phishing

GoPhish es el componente central del ejercicio. Al instalarse, el sidecar `opsn-gophish-init` configura automáticamente los siguientes recursos con branding de **Acme Corp**:

| Recurso | Nombre |
|---------|--------|
| Sending Profile | Acme Corp Mail Server |
| Email Template | Acme Corp Password Reset |
| Landing Page | Acme Corp Login Page |
| User Group | Acme Corp Lab Users |

Los destinatarios del grupo son `admin@opensec.lab` y `user@opensec.lab`.

### 4.1 Acceder a GoPhish

1. Abre https://localhost:3333 en tu navegador
2. Acepta el certificado autofirmado (es esperado)
3. Inicia sesión con `admin` y la contraseña obtenida en el paso anterior

### 4.2 Crear la campaña

1. En el menú lateral, ve a **Campaigns**
2. Haz clic en **+ New Campaign**
3. Completa los campos:

| Campo | Valor |
|-------|-------|
| **Name** | `Acme Corp - Campaña Demo` (o el nombre que prefieras) |
| **Email Template** | `Acme Corp Password Reset` |
| **Landing Page** | `Acme Corp Login Page` |
| **URL** | `http://gophish.opensec.lab` |
| **Launch Date** | Selecciona fecha y hora actuales (o cuando quieras iniciarla) |
| **Sending Profile** | `Acme Corp Mail Server` |
| **Groups** | `Acme Corp Lab Users` |

> **URL importante:** La URL de la landing page debe ser `http://gophish.opensec.lab`. Esta dirección resuelve correctamente dentro de la red del lab gracias al servidor DNS interno. El Desktop (Webtop) ya está configurado para usar ese DNS.

4. Haz clic en **Launch Campaign**

### 4.3 Seguir los resultados

Una vez lanzada la campaña, GoPhish registra en tiempo real:

- **Email Sent** — el correo fue entregado al servidor de mail
- **Email Opened** — el destinatario abrió el correo (pixel de rastreo)
- **Clicked Link** — el destinatario hizo clic en el enlace
- **Submitted Data** — el destinatario ingresó credenciales en la landing page

Para ver los detalles: en **Campaigns**, haz clic en el nombre de la campaña → **View Results**.

---

## 5. Desktop — Víctima simulada

El Desktop es un escritorio XFCE accesible desde el navegador. Simula el equipo de la víctima dentro de la red del lab.

**Acceso:** http://localhost:3100
**Contraseña:** `abc`

### Qué tiene preconfigurado

- **Thunderbird** listo para usar con la cuenta `admin@opensec.lab`
  - IMAP: `mail.opensec.lab:143`
  - SMTP: `mail.opensec.lab:587`
- **DNS interno** apuntando al servidor `opsn-dns` (resuelve `*.opensec.lab`)
- **Navegador** para acceder a las URLs internas del lab

### Flujo del ejercicio desde el Desktop

1. Abre el Desktop en http://localhost:3100
2. Lanza Thunderbird (ya está en el escritorio)
3. Espera el correo de phishing (llega de `admin@opensec.lab` con el asunto de contraseña expirada)
4. Abre el correo y haz clic en el enlace
5. El navegador abre la landing page de Acme Corp en `http://gophish.opensec.lab`
6. Ingresa cualquier usuario y contraseña en el formulario
7. Observa el mensaje de confirmación (o error simulado)
8. Regresa a GoPhish y verifica que el evento **Submitted Data** aparece en los resultados

---

## 6. Webmail (Roundcube)

Roundcube es el cliente de correo web del lab. Permite revisar los correos recibidos directamente desde el navegador, sin necesidad del Desktop.

**Acceso:** http://localhost:8888
**Usuario:** `admin` o `user`
**Contraseña:** `Password`

> Para usar la cuenta `user@opensec.lab`, inicia sesión con usuario `user` y contraseña `Password`.

---

## 7. DVWA — Aplicación web vulnerable

DVWA (Damn Vulnerable Web Application) es una aplicación PHP diseñada intencionalmente con vulnerabilidades para practicar técnicas de pentesting web.

**Acceso:** http://localhost:8080
**Usuario:** `admin`
**Contraseña:** `admin`

### Primer uso

1. Accede a http://localhost:8080
2. Ve a **DVWA Security** y selecciona el nivel de dificultad (Low, Medium, High, Impossible)
3. Practica en las categorías: SQL Injection, XSS, CSRF, File Upload, Command Injection, etc.

> Si la base de datos no está inicializada, ve a **Setup / Reset DB** y haz clic en **Create / Reset Database**.

---

## 8. Juice Shop — OWASP

OWASP Juice Shop es una aplicación web intencionalmente vulnerable con más de 100 desafíos distribuidos en múltiples categorías de OWASP Top 10.

**Acceso:** http://localhost:3000

No requiere credenciales para empezar. Incluye desafios internos para practicar de forma libre.

Categorías incluidas: Injection, Broken Authentication, XSS, Insecure Deserialization, Broken Access Control, y más.

---

## 9. DNS — Technitium

Technitium DNS Server gestiona la zona `opensec.lab` dentro de la red Docker.

**Acceso:** http://localhost:5380
**Usuario:** `admin`
**Contraseña:** `Password`

### Registros configurados automáticamente

| Tipo | Nombre | Valor |
|------|--------|-------|
| A | `mail.opensec.lab` | 172.18.0.7 |
| A | `webmail.opensec.lab` | 172.18.0.7 |
| A | `gophish.opensec.lab` | 172.18.0.5 |
| MX | `opensec.lab` | `mail.opensec.lab` |

Puedes agregar registros adicionales desde la interfaz si necesitas simular más dominios internos.

---

## 10. Gestión del lab

Después de la instalación, usa el mismo script para gestionar el lab:

```bash
~/OpenSec_Lab/opensec-lab.sh
```

### Opciones disponibles

| Opción | Descripción |
|--------|-------------|
| Instalar servicios | Agrega nuevos servicios al lab activo |
| Eliminar servicios | Detiene y elimina contenedores (opcionalmente borra datos) |
| Reinstalar servicios | Recrea los contenedores sin borrar datos |
| Borrar todo | Elimina todos los contenedores, volúmenes y la red |
| Actualizar definiciones | Descarga el `docker-compose.yml` y `.env` más recientes desde GitHub |

### Comandos útiles

```bash
# Ver logs de un servicio
docker logs opsn-gophish -f
docker logs opsn-gophish-init
docker logs opsn-mail -f

# Reiniciar un servicio
docker restart opsn-gophish

# Verificar que el DNS resuelve correctamente
docker exec opsn-desktop nslookup gophish.opensec.lab

# Reinicializar GoPhish (borra todos los recursos creados)
docker compose --profile gophish down -v
docker compose --profile gophish up -d
```

---

## 11. Personalización

Copia `.env.example` como `.env` en el directorio del lab:

```bash
cp ~/OpenSec_Lab/.env.example ~/OpenSec_Lab/.env
```

Edita los valores según necesites:

| Variable | Default | Descripción |
|----------|---------|-------------|
| `OPSN_DOMAIN` | `opensec.lab` | Dominio interno del lab |
| `OPSN_DNS_PASSWORD` | `Password` | Contraseña del panel DNS |
| `OPSN_MAIL_PASSWORD` | `Password` | Contraseña del servidor de mail |
| `OPSN_GOPHISH_COMPANY_NAME` | `Acme Corp` | Nombre de la empresa ficticia |
| `OPSN_GOPHISH_EMAIL_SUBJECT` | `Accion requerida: Restablece tu contrasena corporativa` | Asunto del correo de phishing |
| `OPSN_GOPHISH_FROM_NAME` | `Soporte IT` | Nombre del remitente visible |
| `OPSN_GOPHISH_SUPPORT_TEAM` | `Equipo de Seguridad IT` | Firma del correo |

Después de modificar el `.env`, reinicia el servicio correspondiente para aplicar los cambios:

```bash
docker compose --profile gophish down -v
docker compose --profile gophish up -d
```

> Al reiniciar con `-v` se borran los recursos de GoPhish y el sidecar los recrea con los nuevos valores.

---

## 12. Solución de problemas

### GoPhish no muestra los recursos pre-configurados

Verifica los logs del sidecar de inicialización:

```bash
docker logs opsn-gophish-init
```

Si el sidecar falló, vuelve a ejecutarlo:

```bash
docker compose --profile gophish restart opsn-gophish-init
```

### No llegan correos a Thunderbird

1. Verifica que `opsn-mail` esté corriendo: `docker ps | grep opsn-mail`
2. Comprueba que Thunderbird usa el servidor IMAP correcto: `mail.opensec.lab:143`
3. Revisa los logs del servidor de mail: `docker logs opsn-mail -f`

### La landing page no carga en el Desktop

1. Verifica que la URL de la campaña en GoPhish sea exactamente `http://gophish.opensec.lab`
2. Confirma que el DNS resuelve desde el Desktop:
   ```bash
   docker exec opsn-desktop nslookup gophish.opensec.lab
   ```
3. Verifica que GoPhish está corriendo y escucha en el puerto 80:
   ```bash
   docker ps | grep opsn-gophish
   ```

### GoPhish muestra "Invalid username/password" al iniciar sesión

La contraseña se genera aleatoriamente. Recupérala con:

```bash
docker logs opsn-gophish 2>&1 | grep "Please login"
```

### Puerto 53 ocupado (systemd-resolved en Ubuntu)

```bash
sudo systemctl stop systemd-resolved
sudo systemctl disable systemd-resolved
```

Luego vuelve a ejecutar el instalador.

---

## Flujo completo del ejercicio de phishing

1. **Levanta el lab** con DNS, Mail, GoPhish y Desktop
2. **Accede a GoPhish** en https://localhost:3333 y obtén la contraseña de los logs
3. **Crea la campaña** con los recursos pre-configurados (URL: `http://gophish.opensec.lab`)
4. **Lanza la campaña** haciendo clic en **Launch Campaign**
5. **Abre el Desktop** en http://localhost:3100 (contraseña: `abc`)
6. **Abre Thunderbird** en el Desktop — el correo de phishing debería llegar en segundos
7. **Haz clic en el enlace** del correo — se abre la landing page de Acme Corp
8. **Ingresa credenciales** falsas en el formulario — la página muestra una confirmación
9. **Revisa los resultados** en GoPhish → Campaigns → View Results

---

*OpenSec Lab v1 — Para uso en entornos de laboratorio controlados. No usar en redes de producción.*
