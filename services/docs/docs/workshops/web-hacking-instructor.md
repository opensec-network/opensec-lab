# Guia de instructor: Hacking Web y Deteccion por Firma de Red

Esta guia ayuda a facilitar el taller **Hacking Web y Deteccion por Firma de Red** para una clase, meetup, equipo interno o practica individual supervisada.

## Resumen

- Duracion estimada: 30 a 45 minutos.
- Nivel: principiante.
- Modo: practica guiada con comandos `curl` y navegador.
- Resultado: el estudiante explota cuatro vulnerabilidades web clasicas y relaciona el trafico malicioso con firmas de Suricata visibles en Wazuh.

## Servicios requeridos

Minimo:

- `opsn-dvwa`
- `opsn-docs`

Recomendado para la parte defensiva:

- `opsn-wazuh`
- `opsn-suricata`
- `opsn-portal`

## Preparacion

1. Inicia los servicios requeridos.
2. Espera a que DVWA responda en `http://localhost:8080`. El primer arranque puede tardar 30-60 segundos mientras el contenedor inicializa la base de datos.
3. Verifica que Suricata haya cargado sus reglas (ver seccion Troubleshooting).
4. Si usaras Wazuh, espera a que el dashboard responda en `https://localhost:5601` y el manager este indexando eventos.
5. Pide a los estudiantes que abran `http://localhost:8080/setup.php` y hagan clic en **Create / Reset Database** antes de empezar.

### Tiempo de calentamiento

Suricata tarda hasta 2 minutos en cargar las reglas al arrancar. Wazuh puede tardar 2-5 minutos adicionales en indexar las primeras alertas. Arranca los servicios con margen antes de la sesion.

## Credenciales

| Servicio | Usuario | Password | URL |
| --- | --- | --- | --- |
| DVWA | `admin` | `password` | http://localhost:8080 |
| Wazuh Dashboard | `admin` | `admin` | https://localhost:5601 |

> Nota: el archivo `services/docs/docs/services/dvwa.md` lista `admin`/`admin`, pero el contenedor DVWA upstream usa `admin`/`password` como credencial real. Usa siempre `admin`/`password`.

## Evidencia esperada

| Paso | Request | Firma Suricata | rule.id Wazuh |
| --- | --- | --- | --- |
| SQL Injection | `GET /vulnerabilities/sqli/?id=1' OR '1'='1` | `OpenSecLab - SQL Injection en DVWA` | `86601` |
| Command Injection | `POST /vulnerabilities/exec/` con `ip=127.0.0.1;id` | `OpenSecLab - Command Injection en DVWA` | `86601` |
| XSS Reflejado | `GET /vulnerabilities/xss_r/?name=<script>alert(1)</script>` | `OpenSecLab - XSS en DVWA` | `86601` |
| File Inclusion | `GET /vulnerabilities/fi/?page=../../../../etc/passwd` | `OpenSecLab - File Inclusion en DVWA` | `86601` |

Todas las alertas llegan como `rule.id: 86601` con grupos `[ids, suricata]`. El campo diferenciador es `data.alert.signature`.

## Temas de explicacion

### Deteccion por firma de red vs. por evento de aplicacion

El taller de APIs detecta ataques porque la API escribe eventos estructurados (JSON) que Wazuh lee directamente. Aqui, la aplicacion no escribe nada relevante. Suricata inspeccionara el trafico HTTP en la red Docker y disparara firmas al ver patrones sospechosos en la URL o el cuerpo del request.

Punto clave para la clase: **el IDS puede detectar ataques sin cooperacion de la aplicacion**. Esto es util cuando la app no tiene logging, esta comprometida, o cuando el equipo de defensa no controla el codigo.

### Evasion de firmas basadas en patron

Las firmas de Suricata buscan strings o secuencias especificas. Un atacante puede:

- Usar URL encoding alternativo (p. ej. `%27` en lugar de `'` para la comilla de SQLi).
- Fragmentar el payload en multiples paquetes TCP.
- Usar variantes del payload que logran el mismo efecto pero no coinciden con la firma.

Esto motiva la deteccion por comportamiento (anomaly-based) como complemento a las firmas.

### Diferencia entre vulnerabilidades

- **SQLi**: el problema es la construccion de consultas. La mitigacion es parametrizacion, no filtrado.
- **Command Injection**: el problema es delegar al shell del SO. La mitigacion es evitar el shell o usar allowlists estrictas.
- **XSS**: el problema es confiar la salida al navegador sin codificar. La mitigacion es output encoding + CSP.
- **File Inclusion**: el problema es usar parametros de usuario como rutas. La mitigacion es allowlist de archivos + restriccion de filesystem.

## Troubleshooting

### DVWA muestra error de base de datos al navegar las vulnerabilidades

El estudiante no completo el paso de Setup. Indica que navegue a `http://localhost:8080/setup.php` y haga clic en **Create / Reset Database**.

### DVWA no acepta la credencial

Verifica que el contenedor esta corriendo:

```bash
docker ps --format '{{.Names}}' | grep -x opsn-dvwa
```

Si esta corriendo pero no acepta `admin`/`password`, el contenedor puede estar en medio de la inicializacion. Espera 30 segundos y reintenta.

### Las firmas de Suricata no se disparan

Verifica cuantas reglas cargo Suricata al iniciar:

```bash
docker logs opsn-suricata 2>&1 | grep "rules loaded"
```

La salida esperada incluye algo similar a:

```text
13 rules loaded, 0 rules failed
```

Si dice `0 rules loaded`, las reglas de OpenSec Lab no estan montadas correctamente. Verifica que el volumen `services/suricata/rules/` este mapeado en el compose.

Si las reglas estan cargadas pero no se disparan, verifica que la interfaz de red configurada en Suricata (`SURICATA_INTERFACE` en `defaults.env`) coincide con la interfaz de la red Docker:

```bash
docker network inspect openseclab | grep -i gateway
ip route show | grep 172.18
```

### No aparecen alertas en Wazuh

Primero confirma que Suricata esta generando alertas en su log local:

```bash
docker exec opsn-suricata tail -n 20 /var/log/suricata/eve.json 2>/dev/null \
  | grep signature
```

Si hay firmas en el log de Suricata pero no en Wazuh, el problema esta en la ingesta. Confirma que Wazuh manager esta corriendo:

```bash
docker ps --format '{{.Names}}' | grep -x opsn-wazuh-manager
```

Wazuh puede tardar varios minutos en indexar eventos despues del arranque. Filtra en Discover con `rule.groups: suricata` y ajusta el rango de tiempo al ultimo intervalo conocido.

### El nivel de seguridad de DVWA no es Low

El nivel se resetea al reiniciar el contenedor. Guialo a `http://localhost:8080/security.php`, seleccionar **Low** y guardar antes de cada sesion.

## Reset antes de repetir

Usa la opcion **15) Reset del taller** del menu (`~/OpenSec_Lab/opensec-lab.sh`):
reinicia DVWA, limpia las alertas del taller en Wazuh y deja el ejercicio listo
para el siguiente grupo.

Equivalente manual del lado ofensivo (resetear solo DVWA):

```bash
docker exec opsn-dvwa bash -c \
  "mysql -u root -p\${MYSQL_ROOT_PASSWORD} dvwa -e 'DROP DATABASE IF EXISTS dvwa; CREATE DATABASE dvwa;'" 2>/dev/null \
  || docker restart opsn-dvwa
```

O, mas simple, pide al estudiante que navegue a `http://localhost:8080/setup.php` y haga clic en **Create / Reset Database**.

> Wazuh indexa con 1-3 min de retraso. Resetea entre grupos con margen, o corre el
> reset dos veces si lo haces inmediatamente tras la ultima corrida.
