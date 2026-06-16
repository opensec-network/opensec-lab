# Taller: Kill Chain y Correlacion de Señales

Este taller es el mas avanzado de la ruta. En lugar de detectar **un** ataque con **una** firma, ejecutas una cadena de ataque (kill chain) en dos fases —reconocimiento y explotacion— y aprendes a **correlacionarlas** en Wazuh como lo haria un analista de SOC: reconstruir la historia completa a partir de señales separadas que comparten un mismo origen.

La diferencia clave respecto a los talleres anteriores:

- El [taller de Hacking Web](web-hacking.md) y el de [Phishing](phishing.md) detectan un evento aislado.
- Aqui cada señal por separado dice poco. Un escaneo de puertos puede ser ruido; un ataque SQLi puede ser un falso positivo. **Juntos, del mismo origen y en secuencia, cuentan una historia: alguien hizo reconocimiento y despues ataco el servicio que encontro.** Esa correlacion es la habilidad central.

## Requisitos

- Servicio `opsn-dvwa` iniciado (el servicio que vas a escanear y explotar).
- Servicio `opsn-desktop` iniciado: es tu maquina atacante dentro del lab (trae `nc`).
- Servicio `opsn-docs` iniciado para leer esta guia dentro del lab.
- Recomendado para deteccion: `opsn-wazuh` y `opsn-suricata`.
- Terminal con `nc` (netcat) y `curl`.

> **Por que desde el Desktop o desde Kali, y no `localhost`:** Suricata inspecciona el trafico de la red Docker interna. Un escaneo a `localhost` viaja por el loopback y Suricata **no lo ve**. Debes escanear la **IP interna** del contenedor objetivo. En Kali Linux el host alcanza esas IPs directamente; en cualquier sistema, la terminal de `opsn-desktop` siempre puede.

## Objetivos

Al terminar, debes poder explicar:

- Las fases de un kill chain simple: reconocimiento → explotacion.
- Como un escaneo de puertos se ve en la red y por que un IDS lo detecta por umbral (muchos SYN de un mismo origen).
- Por que una sola alerta rara vez es concluyente y como la correlacion eleva la confianza.
- Como reconstruir una cadena de ataque en Wazuh filtrando por origen y ordenando por tiempo.
- Que mitigaciones (segmentacion, rate-limiting, deteccion temprana de recon) rompen la cadena.

## 1. Identificar el objetivo

Tu maquina atacante es `opsn-desktop`. El objetivo es `opsn-dvwa`. Obten su IP interna:

```bash
docker inspect opsn-dvwa -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'
```

Anota esa IP (por ejemplo `172.21.0.6`). En los comandos siguientes la llamaremos `$TARGET`.

## 2. Fase 1 — Reconocimiento (port scan)

El primer movimiento de un atacante es descubrir que servicios expone el objetivo. Un escaneo de puertos abre muchas conexiones TCP en poco tiempo: un patron que el IDS reconoce.

Desde la terminal de `opsn-desktop` (o desde Kali, contra la IP interna):

```bash
TARGET=172.21.0.6   # sustituye por la IP que obtuviste
for p in $(seq 1 200); do
  nc -z -w1 "$TARGET" "$p" 2>/dev/null && echo "puerto $p abierto"
done
```

Observacion esperada:

- El escaneo reporta el puerto `80` abierto (el servidor web de DVWA).
- Cada intento de conexion envia un paquete SYN. Suricata cuenta los SYN por origen y, al superar el umbral (30 en 5 segundos), dispara la firma `OpenSecLab - Escaneo de puertos SYN detectado`.

> Si tienes `nmap` disponible, el equivalente es `nmap -sS -T4 $TARGET`. El lab no incluye `nmap` por defecto; `nc` no requiere instalar nada.

## 3. Fase 2 — Explotacion (atacar el servicio hallado)

El reconocimiento revelo un servidor web en el puerto 80. El atacante lo explota. Usamos la misma SQL Injection del [taller de Hacking Web](web-hacking.md):

```bash
curl -s -o /dev/null \
  "http://${TARGET}/vulnerabilities/sqli/?id=1%27+OR+%271%27%3D%271&Submit=Submit"
```

Observacion esperada:

- Suricata detecta el patron de inyeccion y dispara `OpenSecLab - SQL Injection en DVWA`.
- Para la **deteccion** no necesitas iniciar sesion en DVWA: el patron viaja en la URL y Suricata lo ve igual. (Para ver la respuesta explotada de DVWA si necesitarias sesion; aqui nos interesa la señal de red.)

Ahora tienes dos señales de un mismo origen: un escaneo seguido de un ataque al servicio escaneado.

## 4. Correlacionar la cadena en Wazuh (la habilidad clave)

Abre **Wazuh Dashboard** (`https://localhost:5601`, `admin`/`admin`) → **Discover**, index pattern `wazuh-alerts-*`.

### 4.1 Ver todas las señales del atacante

Filtra por el origen del ataque (la IP de tu maquina atacante) y el grupo de Suricata:

```text
data.src_ip: <IP_del_atacante> and rule.groups: suricata
```

Ordena por tiempo ascendente. Veras la cadena en orden:

| Orden | Firma | Fase del kill chain |
| --- | --- | --- |
| 1 | `OpenSecLab - Escaneo de puertos SYN detectado` | Reconocimiento |
| 2 | `OpenSecLab - SQL Injection en DVWA` | Explotacion |

### 4.2 Leer la historia como analista

La correlacion convierte señales sueltas en un incidente:

- **Mismo origen** (`data.src_ip`): no son eventos de usuarios distintos; es un solo actor.
- **Secuencia temporal**: primero reconocimiento, despues explotacion. El orden importa.
- **Mismo objetivo** (`data.dest_ip`): el atacante exploto justo el servicio que descubrio.

Esa narrativa —un origen escanea y luego ataca lo que encontro— es mucho mas accionable que cualquiera de las dos alertas por separado.

### 4.3 Preguntas de analista

- ¿Por que un escaneo de puertos por si solo no justifica una respuesta agresiva, pero seguido de un ataque al mismo objetivo si?
- El IDS detecta el escaneo por **umbral** (30 SYN en 5 s). ¿Como evadiria un atacante esa deteccion? (pista: escaneo lento, "low and slow".)
- Si vieras el escaneo en tiempo real, ¿que accion tomarias **antes** de que llegue la fase de explotacion? Aqui es donde la deteccion temprana de recon rompe la cadena.
- ¿Como cambiaria tu confianza si el origen del escaneo fuera una maquina interna que normalmente no escanea (posible movimiento lateral)?

> Si las alertas no aparecen: Suricata puede tardar 1–2 minutos en cargar sus reglas al iniciar. Wazuh puede tardar 1–3 minutos en indexar. Repite la busqueda despues de esperar.

## Mitigaciones

### Romper la fase de reconocimiento

- **Segmentacion de red:** limita que hosts pueden alcanzar que servicios; un atacante segmentado no puede escanear libremente.
- **Deteccion temprana de recon:** alertar y responder al escaneo *antes* de la explotacion corta la cadena en su fase mas barata de detener.
- **Rate-limiting de conexiones:** dificulta el escaneo rapido y lo hace mas ruidoso.

### Romper la fase de explotacion

- Aplicar las mitigaciones del servicio explotado (para SQLi: consultas parametrizadas; ver el [taller de Hacking Web](web-hacking.md)).

### Del lado defensivo (correlacion)

- Crear reglas de correlacion en el SIEM que eleven la severidad cuando un mismo origen genera recon **y** explotacion en una ventana de tiempo.
- Priorizar la investigacion de origenes que escalan de reconocimiento a ataque.

## Reset rapido

La forma mas simple: en el menu del lab (`~/OpenSec_Lab/opensec-lab.sh`), elige la
opcion **15) Reset del taller**. Reinicia los componentes del lado azul y limpia
las alertas del taller en Wazuh.

> Wazuh indexa con 1-3 min de retraso. Si reseteas justo despues de atacar, alguna
> alerta "en vuelo" puede sobrevivir; vuelve a correr el reset (opcion 15) para barrerla.
