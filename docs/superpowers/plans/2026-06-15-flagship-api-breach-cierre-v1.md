# Cierre v1 — Flagship "API Breach to Detection" Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Llevar el flagship "API Breach to Detection" a estado de producción — verificado end-to-end, con el lado defensivo (Wazuh) al mismo nivel que el ofensivo, usable por las tres audiencias con un mismo artefacto, con la superficie de servicios congelada y la documentación reconciliada con el producto real.

**Architecture:** El flagship ya existe y es correcto (API vulnerable Flask + reglas Wazuh + guías + readiness script). Este plan NO construye servicios nuevos: verifica el camino ataque→detección en runtime, instrumenta el lado azul que hoy está sin verificar, integra un "modo taller" en el menú existente del script, y realinea la identidad de la documentación. Cada tarea produce algo verificable de forma independiente.

**Tech Stack:** Bash (opensec-lab.sh, tests/*.sh), Docker Compose (perfiles), Flask (services/api/app.py), Wazuh 4.9 (manager/indexer/dashboard) + Suricata, MkDocs (services/docs).

---

## Decisiones de alcance (resueltas con recomendación — confirmar antes de ejecutar)

Estas tres definen el alcance. El plan está escrito asumiendo la opción recomendada de cada una. Si cambias alguna, ajustar las tareas indicadas.

- **D1 — Profundidad del lado azul (por la elección de "ambos lados al 50%"):**
  **Recomendado:** verificar que las alertas se indexan en Wazuh *y* enriquecer el contenido de investigación de la guía (queries concretas, qué campos mirar, cómo leer una alerta). Afecta Tareas 2b y 2c.
  *Alternativa mínima:* solo verificar indexación (omitir 2c) — más rápido pero deja el lado azul como "busca esto" en vez de "investiga así".

- **D2 — Modo taller en el CLI:**
  **Recomendado:** una opción de menú **"Modo taller → API Breach"** en el flujo existente (`menu_instalacion`/`menu_gestion`) que instala el perfil correcto, advierte RAM, e imprime próximos pasos + URLs; más un check `doctor` que envuelve `tests/api-breach-readiness.sh`. Menor superficie, encaja con el patrón de menús actual. Afecta Tarea 3.
  *Alternativa:* subcomando `./opensec-lab.sh workshop api-breach` / `doctor api-breach`. Más "producto" pero más superficie de parsing de argumentos. *Alternativa mínima:* no tocar el CLI; documentar el readiness script (omitir Tarea 3).

- **D3 — Quién ejecuta la verificación runtime y dónde:**
  **Recomendado:** ejecutarla en este entorno (macOS Docker Desktop) para el camino ofensivo (Tarea 1, ligero: solo `api` + `docs`). Para el camino azul completo (Tarea 2a, ~12 GB con Wazuh) decidir en el handoff: ejecutar aquí si la máquina aguanta, o entregar los comandos para correrlos en el host AMD64 objetivo. La plataforma primaria es AMD64 (ARM es secundaria); cualquier hallazgo ARM-específico se anota, no bloquea.

---

## Estado verificado al 2026-06-15 (NO reconstruir — ya existe y es correcto)

- `services/api/app.py` implementa y registra: `bola_attempt`, `bola_write_attempt`, `mass_assignment_attempt`, `broken_function_auth`, `login_success`, `login_failed`. Escribe JSON a `/logs/api.log`. Puerto host `8025` (contenedor `5000`).
- `services/wazuh/rules/openseclab.xml`: reglas `100060` (base API), `100061` (bola_attempt), `100062` (bola_write), `100063` (mass_assignment_attempt), `100064` (broken_function_auth), `100065` (login_failed). Matchean por `<field name="event">`.
- `services/docs/docs/workshops/api-breach.md` (student) y `api-breach-instructor.md` (instructor): completas.
- `tests/api-breach-readiness.sh`: verifica health, login→token_alice, los 3 ataques, los 3 eventos en log, y que `opsn-wazuh-manager` corre. **No** verifica que las alertas se indexen (gap del lado azul).
- Perfiles compose: `api` (independiente), `docs`, `portal`, `dns`; `wazuh` agrupa `opsn-wazuh-{certs,indexer,manager,dashboard,init}`; `suricata` se instala con el bloque blue-team. El sidecar `opsn-wazuh-init` importa reglas y dashboards.
- Menú del script: `menu_instalacion()` (línea ~960), `menu_gestion()` (~991), `case "$option"` (~1013). **No** existe ninguna opción de taller.
- `make validate` y `make test-static` (155/155) pasan al inicio de este plan.

---

## File Structure

- `tests/api-breach-readiness.sh` — **modificar**: añadir sección que verifica alertas indexadas en Wazuh (Tarea 2b).
- `services/docs/docs/workshops/api-breach.md` — **modificar**: enriquecer la sección de investigación en Wazuh (Tarea 2c).
- `opensec-lab.sh` — **modificar**: nueva función `taller_api_breach()` + entrada de menú + check `doctor` (Tarea 3).
- `tests/static.sh` — **modificar**: aserciones para la nueva opción de menú y para la identidad de docs (Tareas 3 y 4).
- `README.md`, `USER_GUIDE.md`, `CLAUDE.md` (raíz del repo) — **modificar**: realinear identidad de "lab de phishing" a "lab de loop ataque→detección" (Tarea 4).
- `ROADMAP.md` — ya lleva el bloque de advertencia (hecho 2026-06-15); sin cambios aquí.

---

## Tarea 1: Verificar el camino ofensivo end-to-end (runtime ligero)

Cierra el gap crítico del lado rojo. Perfil ligero (`api` + `docs`), sin Wazuh. Es verificación operacional, no TDD.

**Files:**
- Run-only: `tests/api-breach-readiness.sh`, `services/api/app.py` (sin editar)

- [ ] **Step 1: Levantar el perfil mínimo**

Run:
```bash
cd ~/OpenSec_Lab 2>/dev/null || cd "$(git -C "$PWD" rev-parse --show-toplevel)"
docker compose --profile api --profile docs up -d
```
Expected: contenedores `opsn-api` y `opsn-docs` en estado `Up`.

- [ ] **Step 2: Confirmar health de la API**

Run: `curl -s http://localhost:8025/api/health`
Expected: `{"status":"ok","service":"opsn-api"}` (orden de campos puede variar).

- [ ] **Step 3: Ejecutar el readiness del camino ofensivo**

Run: `bash tests/api-breach-readiness.sh`
Expected: secciones API / Autenticacion / Eventos / Log de API todas en `pass`. La sección Wazuh emite `warn` (esperado — Wazuh no está en este perfil). `print_summary` sin fallos.

- [ ] **Step 4: Confirmar los eventos en el log crudo (evidencia directa)**

Run: `docker exec opsn-api sh -lc 'tail -n 20 /logs/api.log'`
Expected: líneas JSON con `"event": "bola_attempt"`, `"mass_assignment_attempt"`, `"broken_function_auth"`.

- [ ] **Step 5: Registrar el resultado**

Si todo pasó: el camino ofensivo está verificado end-to-end por primera vez. Anotar en el handoff. Si algo falló: detener el plan y abrir investigación con `superpowers:systematic-debugging` antes de continuar — no maquillar el plan alrededor de un flagship roto.

---

## Tarea 2: Lado azul a nivel del ofensivo (el equilibrio 50/50)

Hoy el ofensivo se verifica y el defensivo no. Esta tarea cierra eso: confirma que las alertas llegan al indexer y deja la verificación automatizada, más contenido de investigación real.

### 2a — Verificar indexación de alertas (runtime, ~12 GB)

**Files:** Run-only (Wazuh stack)

- [ ] **Step 1: Levantar API + blue-team**

Run:
```bash
docker compose --profile api --profile wazuh --profile suricata --profile dns up -d
```
Expected: `opsn-wazuh-{certs,indexer,manager,dashboard,init}`, `opsn-suricata`, `opsn-api`, `opsn-dns` levantan. El indexer puede tardar varios minutos (Rosetta en ARM es más lento).

- [ ] **Step 2: Esperar a que el indexer responda**

Run:
```bash
until docker exec opsn-wazuh-indexer curl -sk -u admin:"${OPSN_WAZUH_PASSWORD:-admin}" https://localhost:9200/_cluster/health >/dev/null 2>&1; do echo "esperando indexer..."; sleep 10; done; echo "indexer OK"
```
Expected: termina con `indexer OK`. (El indexer no expone puerto al host; se consulta vía `docker exec`, patrón ya usado por el init sidecar.)

- [ ] **Step 3: Generar los ataques**

Run: `bash tests/api-breach-readiness.sh`
Expected: eventos generados (los `pass` de la sección "Eventos del taller").

- [ ] **Step 4: Confirmar que las alertas se indexaron**

Run:
```bash
docker exec opsn-wazuh-indexer curl -sk -u admin:"${OPSN_WAZUH_PASSWORD:-admin}" \
  'https://localhost:9200/wazuh-alerts-*/_search' \
  -H 'Content-Type: application/json' \
  -d '{"query":{"terms":{"rule.id":["100061","100063","100064"]}},"size":0,"aggs":{"by_rule":{"terms":{"field":"rule.id"}}}}'
```
Expected: JSON con buckets para `100061`, `100063`, `100064` con `doc_count >= 1`. Wazuh puede tardar 1–3 min en indexar tras generar los eventos; reintentar si los buckets vienen vacíos. Anotar el tiempo real de indexación (alimenta la guía de instructor).

### 2b — Automatizar la verificación del lado azul (TDD)

**Files:**
- Modify: `tests/api-breach-readiness.sh`

- [ ] **Step 1: Escribir la verificación que falla**

Reemplazar la sección `Wazuh` actual (que solo comprueba que el manager corre) por una que también verifica indexación cuando el indexer está disponible. Añadir al final, antes de `print_summary`:

```bash
section "Wazuh — indexacion de alertas"

WAZUH_PASS="${OPSN_WAZUH_PASSWORD:-admin}"

if container_running "opsn-wazuh-indexer"; then
    # Da tiempo a Wazuh para indexar los eventos recien generados.
    indexed=0
    for _ in 1 2 3 4 5 6; do
        agg="$(docker exec opsn-wazuh-indexer curl -sk -u "admin:${WAZUH_PASS}" \
            'https://localhost:9200/wazuh-alerts-*/_search' \
            -H 'Content-Type: application/json' \
            -d '{"query":{"terms":{"rule.id":["100061","100063","100064"]}},"size":0,"aggs":{"by_rule":{"terms":{"field":"rule.id"}}}}' 2>/dev/null)"
        for rid in 100061 100063 100064; do
            printf '%s' "$agg" | grep -q "\"key\":\"${rid}\"" || { indexed=0; break; }
            indexed=1
        done
        [ "$indexed" = "1" ] && break
        sleep 20
    done

    if [ "$indexed" = "1" ]; then
        pass "Wazuh indexo las alertas 100061/100063/100064 (camino azul completo)"
    else
        fail "Wazuh no indexo las 3 alertas tras ~2 min. Revisa filebeat: docker exec opsn-wazuh-manager filebeat test output"
    fi
else
    warn "opsn-wazuh-indexer no esta corriendo; verificacion de indexacion omitida (camino solo-ofensivo)"
fi
```

- [ ] **Step 2: Ejecutar con Wazuh apagado — debe degradar a warn, no fallar**

Run (sin perfil wazuh activo): `bash tests/api-breach-readiness.sh`
Expected: la sección nueva emite `warn` y `print_summary` NO reporta fallo por Wazuh. Esto preserva el uso "solo ofensivo" del readiness.

- [ ] **Step 3: Ejecutar con Wazuh encendido — debe pasar**

Run (con el stack de 2a arriba): `bash tests/api-breach-readiness.sh`
Expected: `pass "Wazuh indexo las alertas..."`.

- [ ] **Step 4: Verificar sintaxis**

Run: `bash -n tests/api-breach-readiness.sh && echo OK`
Expected: `OK`.

- [ ] **Step 5: Commit**

```bash
git add tests/api-breach-readiness.sh
git commit -m "test: verify Wazuh indexes API breach alerts (close blue-side gap)"
```

### 2c — Enriquecer el contenido de investigación (lado azul de la guía)

**Files:**
- Modify: `services/docs/docs/workshops/api-breach.md` (sección "7. Relacionar eventos con Wazuh")

- [ ] **Step 1: Reemplazar la sección 7 por una guía de investigación real**

Sustituir el bloque actual de la sección 7 (que solo dice "busca rule.groups: openseclab_api") por contenido que enseñe a *investigar*, no solo a buscar:

```markdown
## 7. Investigar la detección en Wazuh

Cada ataque que disparaste dejó una alerta. Abre **Wazuh Dashboard** (`https://localhost:5601`, `admin`/`admin`) → **Discover**, selecciona el index pattern `wazuh-alerts-*`.

### 7.1 Encontrar tus alertas

Filtra por el grupo de reglas del lab:

```text
rule.groups: openseclab_api
```

Deberías ver tres alertas correspondientes a tus tres ataques:

| Regla | Nivel | Evento API | Qué significa la detección |
| --- | --- | --- | --- |
| `100061` | 10 | `bola_attempt` | Un usuario accedió a un objeto de otro usuario (IDOR). |
| `100063` | 12 | `mass_assignment_attempt` | Se intentó modificar un campo protegido (`role`). Nivel 12 = mayor severidad: implica posible escalada. |
| `100064` | 10 | `broken_function_auth` | Un usuario sin rol admin llamó un endpoint administrativo. |

### 7.2 Leer una alerta como analista

Abre la alerta `100063` (mass assignment) y observa estos campos:

- `rule.description` — qué detectó la regla y por qué importa.
- `data.user_id` y `data.attempted_fields` — quién y qué intentó modificar.
- `data.remote_ip`, `data.method`, `data.path` — el contexto del request.
- `rule.level` — la severidad asignada (12 aquí, vs 10 en BOLA: el lab prioriza la escalada de privilegios).

### 7.3 Preguntas de analista

- ¿Por qué `100063` tiene nivel 12 y `100061` nivel 10? ¿Estás de acuerdo con esa priorización?
- Si fueras el defensor, ¿qué campo te diría más rápido que esto es un ataque y no un usuario legítimo?
- ¿Qué *no* aparece en la alerta que te gustaría tener para investigar? (pista: la API no registra el user-agent.)

> Si las alertas no aparecen: Wazuh puede tardar 1–3 minutos en indexar tras generar los eventos. Confirma primero el log crudo (paso 6) y luego repite la búsqueda.
```

- [ ] **Step 2: Verificar que MkDocs no rompe la nav**

Run: `make validate`
Expected: `Compose: OK` y `opensec-lab.sh: OK` (validate no construye MkDocs, pero confirma que no rompiste el compose por error de edición de rutas).

- [ ] **Step 3: Confirmar que los tests estáticos siguen verdes**

Run: `make test-static`
Expected: 155/155 (la sección 7 no afecta aserciones existentes; si alguna aserción referenciaba el texto viejo, actualizarla aquí).

- [ ] **Step 4: Commit**

```bash
git add services/docs/docs/workshops/api-breach.md
git commit -m "docs: turn Wazuh step into real investigation content (50/50 blue side)"
```

---

## Tarea 3: Modo taller en el menú del script (envoltura de instructor)

Implementa D2 (recomendado: opción de menú + check `doctor`). Hace al instructor primera clase: un punto de entrada que instala lo correcto y dice qué sigue.

**Files:**
- Modify: `opensec-lab.sh` (nueva función + entradas de menú)
- Modify: `tests/static.sh` (aserción de la nueva opción)

- [ ] **Step 1: Escribir la aserción estática que falla**

En `tests/static.sh`, junto a las aserciones del script, añadir:

```bash
assert_file_contains \
    "script ofrece modo taller API Breach" \
    "opensec-lab.sh" \
    "taller_api_breach"

assert_file_contains \
    "script expone doctor del taller" \
    "opensec-lab.sh" \
    "api-breach-readiness.sh"
```

- [ ] **Step 2: Ejecutar — debe fallar**

Run: `make test-static`
Expected: FAIL en las dos aserciones nuevas (la función aún no existe).

- [ ] **Step 3: Implementar la función de taller**

En `opensec-lab.sh`, antes de `menu_gestion()`, añadir:

```bash
taller_api_breach() {
    log_step "Modo taller: API Breach to Detection"
    echo ""
    echo "Este taller instala el camino ataque→detección de APIs."
    echo "Perfil ofensivo (ligero):   api + docs + portal      (~6 GB RAM)"
    echo "Camino azul completo:       + wazuh + suricata + dns  (~12 GB RAM)"
    echo ""
    read -r -p "¿Incluir el lado azul (Wazuh)? Requiere ~12 GB [s/N]: " incluir_azul

    local perfiles=(--profile api --profile docs --profile portal)
    if [[ "$incluir_azul" =~ ^[sSyY]$ ]]; then
        estimar_ram "wazuh" || true
        perfiles+=(--profile dns --profile wazuh --profile suricata)
    fi

    ${SUDO_CMD} docker compose "${perfiles[@]}" up -d || {
        log_error "Falló el arranque del taller."
        return 1
    }

    echo ""
    log_info "Taller instalado. Próximos pasos:"
    echo "  1. Guía del estudiante:  http://localhost:${OPSN_DOCS_PORT:-4000}/workshops/api-breach/"
    echo "  2. Verifica el camino:   bash tests/api-breach-readiness.sh"
    echo "  3. Portal del lab:       http://localhost:${OPSN_PORTAL_PORT:-8443}"
    if [[ "$incluir_azul" =~ ^[sSyY]$ ]]; then
        echo "  4. Wazuh Dashboard:      https://localhost:${OPSN_WAZUH_DASH_PORT:-5601} (admin/admin)"
        echo "     (Wazuh tarda 1-3 min en indexar tras los primeros ataques)"
    fi
}

doctor_taller() {
    log_step "Doctor: verificando el camino del taller API Breach"
    bash "${SCRIPT_DIR:-.}/tests/api-breach-readiness.sh"
}
```

> Nota: si `estimar_ram` o `SCRIPT_DIR` no existen con esos nombres exactos en el script, ajustar a los identificadores reales (verificar con `grep -n 'estimar_ram\|SCRIPT_DIR\|LAB_DIR' opensec-lab.sh`). No inventar; usar los que ya estén definidos.

- [ ] **Step 4: Añadir las entradas al menú**

En `menu_gestion()` (y `menu_instalacion()` para primera instalación), añadir las opciones visibles y sus `case`. Ejemplo dentro del `case "$option"` de `menu_gestion`:

```bash
        "t"|"T")
            taller_api_breach
            ;;
        "d"|"D")
            doctor_taller
            ;;
```

Y en el texto del menú, añadir las líneas:
```bash
    echo "  [t] Modo taller — API Breach to Detection"
    echo "  [d] Doctor — verificar el camino del taller"
```

- [ ] **Step 5: Verificar sintaxis y aserciones**

Run: `bash -n opensec-lab.sh && make test-static`
Expected: `opensec-lab.sh` sin errores de sintaxis; 157/157 (155 previos + 2 nuevos).

- [ ] **Step 6: Commit**

```bash
git add opensec-lab.sh tests/static.sh
git commit -m "feat: add API Breach workshop mode and doctor to the menu"
```

---

## Tarea 4: Reconciliar la identidad de la documentación (Capa 2)

Ahora desbloqueada por el rumbo. Realinea README/USER_GUIDE/CLAUDE de "lab de phishing" al producto real (loop ataque→detección, flagship API Breach). NO reescribir todo: corregir la identidad y completar lo que falta.

**Files:**
- Modify: `README.md` (encabezado), `USER_GUIDE.md` (encabezado + servicios faltantes), `CLAUDE.md` (raíz repo)
- Modify: `tests/static.sh` (aserción de identidad, opcional)

- [ ] **Step 1: Corregir el encabezado del README**

Reemplazar:
```markdown
Laboratorio de ciberseguridad basado en Docker para simulaciones de phishing y entrenamiento en seguridad web.
```
por:
```markdown
Laboratorio de ciberseguridad basado en Docker: practica ataques reales (web, API, phishing) y aprende a **detectarlos** en un SIEM real. Instala solo lo que necesitas, con un comando.

**Experiencia insignia:** el taller *API Breach to Detection* — explotas fallas de API (BOLA, mass assignment, broken function auth) y luego investigas la evidencia en Wazuh. Atacar y defender en un mismo loop.
```

- [ ] **Step 2: Corregir el encabezado del USER_GUIDE**

Reemplazar la línea 3 de `USER_GUIDE.md` por el mismo posicionamiento (loop ataque→detección, no solo phishing). Mantener el resto de la guía de phishing como una sección válida (sigue siendo un escenario real), pero ya no como *la* identidad del producto.

- [ ] **Step 3: Añadir al USER_GUIDE las secciones de los servicios omitidos**

El USER_GUIDE ignora API, Wazuh, Suricata, Portal, Docs, WebGoat, Gitea. Como mínimo, añadir una sección "API Vulnerable y el taller API Breach" que enlace a `services/docs/docs/workshops/api-breach.md`, y una tabla de servicios alineada con la del README (12 servicios). No duplicar el contenido del workshop — enlazarlo.

- [ ] **Step 4: Actualizar el CLAUDE.md de la raíz del repo**

Corregir los puntos desactualizados: la estructura menciona `services/ctfd` y `services/wiki` (no existen); "opsn-mail recién integrado / build local"; tabla de red de 7 servicios. Alinear con los 12 servicios reales y la dirección de producto vigente (`docs/product-direction/`).

- [ ] **Step 5: Verificar que no se reintrodujo terminología de scoring**

Run: `make test-static`
Expected: la sección "terminologia de scoring ausente" sigue en `pass` (no añadir puntos/badges/leaderboards en las ediciones). 155/157 según corresponda.

- [ ] **Step 6: Commit**

```bash
git add README.md USER_GUIDE.md CLAUDE.md
git commit -m "docs: realign product identity to attack-to-detection loop"
```

---

## Tarea 5: Verificación final integral

**Files:** Run-only

- [ ] **Step 1: Suite estática y validación**

Run: `make validate && make test-static`
Expected: Compose OK, script OK, todos los tests estáticos en verde.

- [ ] **Step 2: Smoke test con el lab corriendo (si aplica)**

Run: `bash tests/smoke.sh`
Expected: pasa para los servicios levantados; anotar cualquier `warn` esperado.

- [ ] **Step 3: Readiness del flagship completo**

Run: `bash tests/api-breach-readiness.sh` (con el stack azul de la Tarea 2a arriba)
Expected: todas las secciones en `pass`, incluida la indexación de Wazuh.

- [ ] **Step 4: Recorrido manual de las tres audiencias**

Confirmar a mano, una vez:
- Autoguiado: abrir la guía del estudiante en `http://localhost:4000/workshops/api-breach/` y seguir los 7 pasos.
- Instructor: seguir la guía de instructor + `doctor` desde el menú.
- Demo: `taller_api_breach` con lado azul, mostrar una alerta en Wazuh Dashboard.

- [ ] **Step 5: Documentar el estado de "done"**

Actualizar `docs/product-direction/README.md` con una nota: el flagship está verificado end-to-end al <fecha>, en <plataforma>, con/ sin notas ARM. Cerrar el ciclo.

---

## Self-Review

- **Cobertura del rumbo:** flagship impecable (T1, T2, T5) ✓ · ambos lados al 50% (T2 completa) ✓ · multi-audiencia mismo artefacto (T3 + T5.4) ✓ · superficie congelada (ninguna tarea añade servicios) ✓ · docs reconciliados (T4, + Capa 1 ya hecha) ✓ · RAM documentada/diferida (D3, T5.5) ✓.
- **Sin placeholders:** cada paso de código tiene el contenido real. Las dos notas de "verificar identificadores reales" (estimar_ram/SCRIPT_DIR) son salvaguardas explícitas, no TODOs: el ejecutor debe grep-ear y usar los nombres existentes.
- **Consistencia de nombres:** eventos (`bola_attempt`, `mass_assignment_attempt`, `broken_function_auth`) y reglas (`100061/100063/100064`) usados igual en T1, T2 y T3, y coinciden con `app.py` y `openseclab.xml` verificados.
- **Riesgo conocido:** T2a/T5.3 dependen de levantar Wazuh (~12 GB) y pueden ser lentos/frágiles en ARM. Mitigación: el readiness degrada a `warn` sin Wazuh (T2b.2), así que el camino ofensivo es verificable sin el stack pesado.
