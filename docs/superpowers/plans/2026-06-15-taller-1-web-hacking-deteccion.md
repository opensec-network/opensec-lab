# Taller 1 — Web Hacking → Detección Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Crear el segundo taller de la ruta — "Web Hacking → Detección" (DVWA, principiante) — que enseña detección por **firma/IDS** (Suricata), después de arreglar las reglas de detección web que hoy están rotas.

**Architecture:** Primero se arregla el motor (reglas Suricata de DVWA, hoy no detectan), se verifica end-to-end que un ataque genera alerta en Suricata→Wazuh, y solo entonces se escribe la guía sobre lo que realmente dispara. Reusa el esqueleto del flagship API (`api-breach.md`). Detección por Suricata (tráfico de red), distinta del taller API (eventos estructurados de app).

**Tech Stack:** Suricata (reglas `services/suricata/rules/openseclab.rules`), DVWA, Wazuh, `curl`, MkDocs.

---

## Estado verificado en el spike (2026-06-15)

- Suricata **captura** el HTTP a DVWA: el `eve.json` registra los GET/POST a `/vulnerabilities/{sqli,exec,xss_r,fi}`. La captura funciona (598 eventos http).
- Suricata carga **11/13 reglas; 2 fallan**: `sid:9000001` (SQLi) y `sid:9000002` (CMDi) por PCRE mal escapado (`\'` y `` ` ``).
- Bug adicional descubierto: varias reglas miran `http.request_body`, pero los ataques DVWA de SQLi/XSS/FI van por **GET** (payload en la URI), no en el body → aunque cargaran, no matchearían.
  - SQLi (`?id=`) → GET → debe mirar `http.uri`
  - Command Injection (`ip=...`) → POST → `http.request_body` es correcto
  - XSS reflected (`?name=`) → GET → debe mirar `http.uri`
  - File Inclusion (`?page=`) → GET → ya mira `http.uri` (pero declara `http.uri` dos veces → warning)
- El ataque para **detección** no requiere login completo de DVWA: el patrón viaja en la URL y Suricata lo ve. (El ataque *funcional* en DVWA sí requiere login; el taller cubre ambos, pero el readiness solo necesita generar el tráfico.)

## File Structure

- `services/suricata/rules/openseclab.rules` — **modificar**: arreglar las 4 reglas DVWA (Tarea 1).
- `services/docs/docs/workshops/web-hacking.md` — **crear**: guía del estudiante (Tarea 3).
- `services/docs/docs/workshops/web-hacking-instructor.md` — **crear**: guía del instructor (Tarea 4).
- `tests/web-hacking-readiness.sh` — **crear**: readiness ataque→detección (Tarea 5).
- `services/docs/mkdocs.yml` — **modificar**: nav (Tarea 6).
- `services/portal/generate_portal.sh` — **modificar**: CTA del taller (Tarea 6).
- `tests/static.sh` — **modificar**: aserciones (Tarea 6).

---

## Tarea 1: Arreglar las reglas Suricata de DVWA

**Files:**
- Modify: `services/suricata/rules/openseclab.rules`

- [ ] **Step 1: Arreglar la regla SQLi (sid:9000001)**

Reemplazar (campo body→uri + PCRE):
```
    http.uri; content:"/vulnerabilities/sqli"; \
    http.request_body; pcre:"/(\'|%27|--|;|UNION|SELECT|DROP|INSERT|OR\s+1)/i"; \
```
por:
```
    http.uri; content:"/vulnerabilities/sqli"; \
    pcre:"/(%27|\x27|--|;|union|select|drop|insert|or\s+1)/i"; \
```

- [ ] **Step 2: Arreglar la regla Command Injection (sid:9000002)**

Reemplazar (PCRE; mantiene `http.request_body` porque CMDi es POST):
```
    http.request_body; pcre:"/(;|\||&&|` |\$\()/"; \
```
por:
```
    http.request_body; pcre:"/(;|\||&&|\x60|\$\()/i"; \
```

- [ ] **Step 3: Arreglar la regla XSS (sid:9000003)**

Reemplazar (body→uri, GET):
```
    http.uri; content:"/vulnerabilities/xss"; \
    http.request_body; pcre:"/<script|javascript:|on\w+\s*=/i"; \
```
por:
```
    http.uri; content:"/vulnerabilities/xss"; \
    pcre:"/(<script|javascript:|on\w+\s*=)/i"; \
```

- [ ] **Step 4: Arreglar la regla File Inclusion (sid:9000004)**

Reemplazar (quitar `http.uri` duplicado):
```
    http.uri; content:"/vulnerabilities/fi"; \
    http.uri; pcre:"/(\.\.|\/etc\/|c:\\\\windows)/i"; \
```
por:
```
    http.uri; content:"/vulnerabilities/fi"; \
    pcre:"/(\.\.|\/etc\/|c:\\\\windows)/i"; \
```

- [ ] **Step 5: Recargar Suricata y verificar que cargan 13/13**

Run:
```bash
docker restart opsn-suricata && sleep 8
docker logs opsn-suricata 2>&1 | grep -E 'rules successfully loaded|rules failed'
```
Expected: `13 rules successfully loaded, 0 rules failed`. Si alguna falla, ajustar el escaping del PCRE de esa regla (Suricata delimita el pcre con `/.../` dentro de comillas dobles; usar `\xNN` para caracteres conflictivos) y repetir.

- [ ] **Step 6: Verificar detección en vivo (las 4)**

Run (DVWA debe estar arriba en `127.0.0.1:8080`):
```bash
B=http://127.0.0.1:8080
curl -s -o /dev/null "$B/vulnerabilities/sqli/?id=1%27+OR+%271%27%3D%271&Submit=Submit"
curl -s -o /dev/null "$B/vulnerabilities/exec/" -d "ip=127.0.0.1;id&Submit=Submit"
curl -s -o /dev/null "$B/vulnerabilities/xss_r/?name=<script>alert(1)</script>"
curl -s -o /dev/null "$B/vulnerabilities/fi/?page=../../../../etc/passwd"
sleep 8
docker exec opsn-suricata sh -c 'grep -o "\"signature\":\"OpenSecLab - [^\"]*\"" /var/log/suricata/eve.json | sort | uniq -c'
```
Expected: aparecen las 4 firmas `OpenSecLab - {SQL Injection, Command Injection, XSS, File Inclusion} en DVWA`. Si falta alguna, revisar esa regla (campo uri/body según GET/POST, y el PCRE).

- [ ] **Step 7: Commit**

```bash
git add services/suricata/rules/openseclab.rules
git commit -m "fix: repair DVWA Suricata rules (PCRE escaping + GET vs body field)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Tarea 2: Verificar el camino Suricata → Wazuh

Confirma que las alertas de Suricata llegan a Wazuh (las reglas Wazuh de Suricata ya existen: grupo `openseclab` lee `eve.json`). Verificación, no código nuevo.

**Files:** Run-only

- [ ] **Step 1: Generar los ataques y esperar indexación**

Run: repetir los 4 `curl` de la Tarea 1 Step 6, luego `sleep 90` (Wazuh indexa con retraso).

- [ ] **Step 2: Confirmar alertas en Wazuh**

Run:
```bash
WP=$(grep '^OPSN_WAZUH_PASSWORD=' config/defaults.env | cut -d= -f2); WP=${WP:-admin}
docker exec opsn-wazuh-indexer curl -sk -u "admin:${WP}" \
  'https://localhost:9200/wazuh-alerts-*/_search' -H 'Content-Type: application/json' \
  -d '{"query":{"match_phrase":{"data.alert.signature":"OpenSecLab"}},"size":0}' | grep -oE '"value":[0-9]+' | head -1
```
Expected: `"value":N` con N>0 (alertas de Suricata indexadas). Si es 0, confirmar que Wazuh manager lee `eve.json` (módulo localfile en `ossec.conf`) — anotar como hallazgo y, si falta, añadir el `localfile` apuntando al `eve.json` compartido. Documentar el resultado para la guía.

- [ ] **Step 3: Anotar la fuente de detección confirmada**

Si las alertas llegan a Wazuh, la guía investiga en Wazuh Dashboard. Si solo están en `eve.json` (no en Wazuh), la guía investiga el `eve.json` directamente. Escribir la Tarea 3 sobre lo confirmado aquí.

---

## Tarea 3: Guía del estudiante (web-hacking.md)

**Files:**
- Create: `services/docs/docs/workshops/web-hacking.md`

- [ ] **Step 1: Escribir la guía siguiendo el esqueleto del flagship**

Crear `services/docs/docs/workshops/web-hacking.md` con la MISMA estructura que `services/docs/docs/workshops/api-breach.md`, contenido para DVWA. Secciones (en español, sin acentos en los `log`/títulos como el resto del repo):

1. **Intro**: explica que aquí se ataca una web app clásica (DVWA) y se detecta por **firma de red** (Suricata IDS) — contrasta con el taller de API (eventos de app). Enlace a la guía de servicio si existe.
2. **Requisitos**: servicios `opsn-dvwa`, recomendado `opsn-wazuh` + `opsn-suricata` para la parte azul; `curl`; puerto `8080`.
3. **Objetivos**: explicar SQLi, Command Injection, XSS reflejado, File Inclusion; y cómo un IDS los detecta por patrón en el tráfico.
4. **Preparar DVWA**: login `admin`/`password` (verificar la credencial real del lab — el README dice `admin`/`admin`; confirmar en el spike de implementación cuál funciona), `Setup/Reset Database`, security level `Low`.
5. **Ataque 1 — SQL Injection** (`/vulnerabilities/sqli/?id=1' OR '1'='1`): payload, qué devuelve DVWA, observación.
6. **Ataque 2 — Command Injection** (`/vulnerabilities/exec`, `ip=127.0.0.1;id`).
7. **Ataque 3 — XSS reflejado** (`/vulnerabilities/xss_r/?name=<script>...`).
8. **Ataque 4 — File Inclusion** (`/vulnerabilities/fi/?page=../../../../etc/passwd`).
9. **Investigar la detección** (según Tarea 2): tabla request → firma Suricata → significado. Queries concretas (en Wazuh Dashboard `data.alert.signature: OpenSecLab` o en `eve.json`). Preguntas de analista: ¿por qué un IDS detecta esto sin leer los logs de la app? ¿qué evade la firma?
10. **Mitigaciones**: prepared statements, validación/allowlist de entrada, output encoding (XSS), no concatenar rutas (FI).
11. **Reset rápido**: `Setup/Reset Database` en DVWA; apuntar a opción 15 del menú para el lado azul.

Usar los comandos `curl` EXACTOS verificados en la Tarea 1 Step 6.

- [ ] **Step 2: Commit**

```bash
git add services/docs/docs/workshops/web-hacking.md
git commit -m "docs: add Web Hacking to Detection student workshop

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Tarea 4: Guía del instructor (web-hacking-instructor.md)

**Files:**
- Create: `services/docs/docs/workshops/web-hacking-instructor.md`

- [ ] **Step 1: Escribir la guía de instructor**

Crear con la estructura de `api-breach-instructor.md`: resumen (duración ~30 min, nivel principiante), servicios requeridos, preparación (incl. recordar que Suricata tarda en cargar y Wazuh en indexar), tabla de evidencia esperada (4 ataques → firmas Suricata), temas de explicación (detección por firma vs por evento de app; evasión de firmas), troubleshooting (DVWA sin DB, Suricata sin reglas cargadas → `docker logs opsn-suricata | grep loaded`), y reset.

- [ ] **Step 2: Commit**

```bash
git add services/docs/docs/workshops/web-hacking-instructor.md
git commit -m "docs: add Web Hacking instructor guide

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Tarea 5: Readiness del taller (web-hacking-readiness.sh)

**Files:**
- Create: `tests/web-hacking-readiness.sh`

- [ ] **Step 1: Escribir el readiness siguiendo el patrón de api-breach-readiness.sh**

Crear `tests/web-hacking-readiness.sh` modelado en `tests/api-breach-readiness.sh` (mismo `helpers.sh`, mismas secciones `section`/`pass`/`fail`/`warn`/`print_summary`). Debe:
1. Resolver el puerto DVWA (`OPSN_DVWA_PORT`, default 8080) y confirmar que `/login.php` responde 200.
2. Generar los 4 ataques (los `curl` verificados de la Tarea 1 Step 6).
3. Verificar que el `eve.json` de Suricata contiene las 4 firmas (`docker exec opsn-suricata grep ...`), degradando a `warn` si `opsn-suricata` no corre.
4. Verificar indexación en Wazuh (igual que la sección Wazuh de `api-breach-readiness.sh`, pero filtrando por `data.alert.signature: OpenSecLab`), degradando a `warn` sin Wazuh.

- [ ] **Step 2: Ejecutar y verificar**

Run: `bash -n tests/web-hacking-readiness.sh && bash tests/web-hacking-readiness.sh`
Expected: secciones DVWA/Suricata en `pass` con el stack arriba; resumen sin fallos.

- [ ] **Step 3: Commit**

```bash
git add tests/web-hacking-readiness.sh
git commit -m "test: add web-hacking workshop readiness helper

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Tarea 6: Nav, portal y tests estáticos

**Files:**
- Modify: `services/docs/mkdocs.yml`, `services/portal/generate_portal.sh`, `tests/static.sh`

- [ ] **Step 1: Añadir el taller al nav de MkDocs**

En `services/docs/mkdocs.yml`, bajo la sección "Talleres" (donde está `workshops/api-breach.md`), añadir `workshops/web-hacking.md` y `workshops/web-hacking-instructor.md`.

- [ ] **Step 2: Aserciones estáticas (TDD)**

En `tests/static.sh`, junto a las aserciones de `workshops/api-breach.md`, añadir:
```bash
assert_file_exists "docs workshops/web-hacking.md" "services/docs/docs/workshops/web-hacking.md"
assert_file_exists "docs workshops/web-hacking-instructor.md" "services/docs/docs/workshops/web-hacking-instructor.md"
assert_file_contains "mkdocs nav incluye web-hacking" "services/docs/mkdocs.yml" "workshops/web-hacking.md"
```

- [ ] **Step 3: CTA en el portal**

En `services/portal/generate_portal.sh`, donde se enlaza el taller de API, añadir un enlace al taller de Web Hacking (`/workshops/web-hacking/`). Mantener el estilo existente, sin gamificación. Si `tests/static.sh` tiene una aserción del label del portal, alinearla.

- [ ] **Step 4: Verificar**

Run: `make test-static && make validate`
Expected: todos los tests pasan (incluye las 3 aserciones nuevas).

- [ ] **Step 5: Commit**

```bash
git add services/docs/mkdocs.yml services/portal/generate_portal.sh tests/static.sh
git commit -m "feat: wire web-hacking workshop into nav, portal and static tests

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Tarea 7: Verificación final

**Files:** Run-only

- [ ] **Step 1: Suite + readiness end-to-end**

Run: `make validate && make test-static && bash tests/web-hacking-readiness.sh`
Expected: validate OK, tests estáticos en verde, readiness con DVWA+Suricata+Wazuh en `pass`.

- [ ] **Step 2: Recorrido manual**

Abrir `http://localhost:4000/workshops/web-hacking/`, seguir los 4 ataques, y confirmar las 4 firmas en Wazuh Dashboard (`data.alert.signature: OpenSecLab`).

---

## Self-Review

- **Cobertura del spec:** taller Web Hacking (dominio web, principiante, detección por firma/IDS) ✓; esqueleto del flagship ✓; readiness end-to-end ✓; nav + portal ✓; reglas nuevas solo si faltan — aquí se **arreglan** las existentes (Tarea 1), no se inventan ✓.
- **Sin placeholders:** los fixes de reglas son exactos (old→new). El contenido de las guías da estructura + comandos verificados; la credencial de DVWA y la fuente de detección (Wazuh vs eve.json) se confirman en Tareas 2/3 Step (marcado explícito, no TBD oculto).
- **Riesgo conocido:** la credencial real de DVWA (`admin/admin` vs `admin/password`) y si Wazuh lee `eve.json` se resuelven en ejecución (Tareas verifican en vivo). El plan es verificable porque el spike ya probó que Suricata captura el tráfico y qué está roto.
