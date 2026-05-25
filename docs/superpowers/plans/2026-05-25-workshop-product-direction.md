# OpenSec Lab Workshop Product Direction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prove the new OpenSec Lab direction by preserving free exploration while adding the first guided workshop, **Taller: Ataque y deteccion en APIs**, with docs, portal entry points, readiness checks, and validation.

**Architecture:** This is a thin vertical slice across MkDocs, the generated portal, shell-based validation, and existing API/Wazuh telemetry. The CLI remains the setup/control surface for this slice; the portal becomes the post-install learning and navigation surface. The final portal visual redesign, scoring systems, and broad new services are out of scope.

**Tech Stack:** Bash, Docker Compose profiles, Flask `opsn-api`, MkDocs Material, nginx static portal, Wazuh localfile ingestion, repo shell tests.

---

## Source Specs

Read these before executing any task:

- `docs/superpowers/specs/2026-05-25-workshop-product-direction-design.md`
- `docs/product-direction/README.md`
- `docs/product-direction/api-breach-workshop-plan.md`
- `docs/product-direction/next-session-prompt.md`

The approved direction is:

- Free exploration stays first-class.
- Guided workshops are optional.
- User-facing shipped copy is Spanish.
- Do not reintroduce points, badges, leaderboards, scoring, or competitive mechanics.
- Do not build the final portal visual redesign in this slice.
- Do not hide direct service access behind workshop flows.

## Phase Status Ledger

Update this ledger when a phase is complete. Each phase has an explicit final commit step that marks its row complete.

| Phase | Status | Completion commit |
| --- | --- | --- |
| Phase 0: Baseline Cleanup | Done | `test: align static portal expectations with current Spanish copy` |
| Phase 1: Spanish Workshop Docs | Done | `docs: add api breach workshop guides` |
| Phase 2: Portal Structure Update | Done | `feat: expose free exploration and guided workshops in portal` |
| Phase 3: API Breach Readiness Helper | Not started | |
| Phase 4: Final Validation and Handoff | Not started | |

Status values: `Not started`, `In progress`, `Done`, `Blocked`.

## Fresh-Session Handoff Rule

Each phase is a separate execution session. When a phase is complete:

1. Run that phase's validation commands.
2. Update the Phase Status Ledger.
3. Commit only that phase's intended files.
4. Stop work.
5. Send the user the copyable "Next session prompt" for the next phase.

Do not continue into the next phase in the same session unless the user explicitly overrides this rule. The goal is to avoid carrying implementation context, accidental assumptions, and stale local state from one phase into the next.

## File Map

**Create:**

- `services/docs/docs/workshops/api-breach.md` - student guide for the API workshop.
- `services/docs/docs/workshops/api-breach-instructor.md` - instructor/community facilitation guide.
- `tests/api-breach-readiness.sh` - Spanish readiness helper for API health and attack/log event behavior.

**Modify:**

- `docs/superpowers/plans/2026-05-25-workshop-product-direction.md` - update phase status after each completed phase.
- `tests/static.sh` - align current portal assertions, add workshop docs/nav/portal assertions, add no-scoring assertions, add readiness script syntax check.
- `services/docs/mkdocs.yml` - add Spanish `Talleres` navigation.
- `services/portal/generate_portal.sh` - add Spanish free-exploration and guided-workshop structure while keeping service cards prominent.

**Read only unless a task explicitly says otherwise:**

- `services/api/app.py` - source of API endpoints and expected event names.
- `services/wazuh/rules/openseclab.xml` - source of Wazuh rule IDs and event mappings.
- `services/wazuh/config/ossec.conf` - confirms Wazuh reads `/var/ossec/logs/api/api.log`.
- `docker-compose.yml` - confirms `opsn_api_logs` is shared between `opsn-api` and Wazuh manager.
- `config/defaults.env` - source of default ports.
- `README.md`, `ROADMAP.md`, `USER_GUIDE.md` - current-facing docs to inspect during Phase 0; do not broaden edits unless current-facing drift blocks validation.

## Current Known Branch State

- Branch: `feat/product-direction-workshops`.
- Known dirty files existed before this plan; preserve unrelated changes.
- Do not stage `docs/superpowers/.DS_Store`.
- Known issue: `make test-static` fails because `tests/static.sh` expects literal `DEFENSA`, while `services/portal/generate_portal.sh` currently says `Blue Team - Defensa y Aprendizaje`.

## Phase 0: Baseline Cleanup

**Goal:** Make the branch coherent before adding workshop features.

**Atomic commit:** `test: align static portal expectations with current Spanish copy`

**Files:**

- Modify: `tests/static.sh`
- Modify: `docs/superpowers/plans/2026-05-25-workshop-product-direction.md`

- [ ] **Step 1: Confirm the current failure**

Run:

```bash
make test-static
```

Expected before the fix: one failure for the portal defense label assertion looking for `DEFENSA`.

- [ ] **Step 2: Update the portal label assertion**

In `tests/static.sh`, replace the current defense assertion:

```bash
assert_file_contains \
    "portal tiene seccion DEFENSA" \
    "services/portal/generate_portal.sh" \
    "DEFENSA"
```

with:

```bash
assert_file_contains \
    "portal tiene seccion Blue Team - Defensa y Aprendizaje" \
    "services/portal/generate_portal.sh" \
    "Blue Team"
```

Use `Blue Team` instead of the full string because the current shell source contains a Unicode dash. Do not change portal copy in Phase 0.

- [ ] **Step 3: Add no-scoring static guards**

Add this block near the portal assertions in `tests/static.sh`:

```bash
# La nueva direccion del producto no usa puntos, insignias ni rankings.
for forbidden in leaderboard leaderboards ranking rankings badge badges puntos puntaje insignias; do
    if rg -i "$forbidden" README.md ROADMAP.md USER_GUIDE.md services/docs/docs services/portal/generate_portal.sh docs/product-direction docs/superpowers/specs >/dev/null 2>&1; then
        fail "terminologia de scoring reintroducida: ${forbidden}"
    else
        pass "terminologia de scoring ausente: ${forbidden}"
    fi
done
```

- [ ] **Step 4: Run static validation**

Run:

```bash
make test-static
```

Expected: PASS. If this still fails, fix only assertions that are directly stale against the current supported product.

- [ ] **Step 5: Run full validation**

Run:

```bash
make validate
```

Expected: PASS.

- [ ] **Step 6: Mark Phase 0 complete in this plan**

Update the ledger row:

```markdown
| Phase 0: Baseline Cleanup | Done | `test: align static portal expectations with current Spanish copy` |
```

- [ ] **Step 7: Commit Phase 0**

Run:

```bash
git add tests/static.sh docs/superpowers/plans/2026-05-25-workshop-product-direction.md
git commit -m "test: align static portal expectations with current Spanish copy"
```

Do not stage `docs/superpowers/.DS_Store`.

- [ ] **Step 8: Stop and send this next-session prompt**

After the commit succeeds, stop work and send this prompt to the user:

```text
We are in /Users/anegron/Desktop/In_Progress/OSN/opensec-lab-v1 on branch feat/product-direction-workshops.

Continue the OpenSec Lab workshop product direction from:
- docs/superpowers/plans/2026-05-25-workshop-product-direction.md
- docs/superpowers/specs/2026-05-25-workshop-product-direction-design.md

Phase 0 is complete. Start Phase 1: Spanish Workshop Docs.

Rules:
- Use the plan task-by-task.
- Do not continue beyond Phase 1 in this session.
- When Phase 1 is done, update the plan ledger, commit only Phase 1 files, and give me the next-session prompt for Phase 2.
- Preserve unrelated dirty worktree changes.
- Do not stage docs/superpowers/.DS_Store.
- Do not push or open a PR unless I explicitly ask.

Expected Phase 1 commit:
docs: add api breach workshop guides
```

## Phase 1: Spanish Workshop Docs

**Goal:** Add the first guided workshop to MkDocs without weakening free exploration.

**Atomic commit:** `docs: add api breach workshop guides`

**Files:**

- Create: `services/docs/docs/workshops/api-breach.md`
- Create: `services/docs/docs/workshops/api-breach-instructor.md`
- Modify: `services/docs/mkdocs.yml`
- Modify: `tests/static.sh`
- Modify: `docs/superpowers/plans/2026-05-25-workshop-product-direction.md`

- [ ] **Step 1: Add failing static assertions for workshop docs and nav**

Add these file assertions after the scenario docs assertions in `tests/static.sh`:

```bash
# Docs - talleres guiados
assert_file_exists "docs workshops/api-breach.md" "services/docs/docs/workshops/api-breach.md"
assert_file_exists "docs workshops/api-breach-instructor.md" "services/docs/docs/workshops/api-breach-instructor.md"
```

Add these MkDocs assertions after the existing MkDocs nav checks:

```bash
assert_file_contains \
    "mkdocs.yml tiene nav de talleres" \
    "services/docs/mkdocs.yml" \
    "Talleres"

assert_file_contains \
    "mkdocs.yml enlaza taller api-breach" \
    "services/docs/mkdocs.yml" \
    "workshops/api-breach.md"

assert_file_contains \
    "mkdocs.yml enlaza guia de instructor api-breach" \
    "services/docs/mkdocs.yml" \
    "workshops/api-breach-instructor.md"
```

- [ ] **Step 2: Verify the new assertions fail**

Run:

```bash
make test-static
```

Expected: FAIL for missing workshop docs and nav entries.

- [ ] **Step 3: Add the student workshop guide**

Create `services/docs/docs/workshops/api-breach.md` with this content:

```markdown
# Taller: Ataque y deteccion en APIs

Este taller guia una practica completa: explotar fallas comunes en una API vulnerable, generar eventos reales y revisar la evidencia defensiva que queda para Wazuh.

Tambien puedes usar la API sin seguir el taller. Para explorar libremente, abre la guia general de [API Vulnerable](../services/api.md) y prueba tus propios requests.

## Requisitos

- Servicio `opsn-api` iniciado.
- Servicio `opsn-docs` iniciado para leer esta guia dentro del lab.
- Recomendado para deteccion: `opsn-wazuh` y `opsn-suricata`.
- Terminal con `curl`.
- Puerto API por defecto: `8025`.

## Objetivos

Al terminar, debes poder explicar:

- Que es BOLA y como aparece en una API vulnerable.
- Como un mass assignment cambia campos que el usuario no deberia controlar.
- Como un endpoint administrativo puede fallar por autorizacion de funcion.
- Que eventos JSON genera la API.
- Que reglas de Wazuh se relacionan con esos eventos.
- Que mitigaciones reducen el riesgo.

## 1. Confirmar que la API responde

```bash
curl -s http://localhost:8025/api/health
```

Salida esperada:

```json
{"service":"opsn-api","status":"ok"}
```

## 2. Iniciar sesion como alice

```bash
curl -s -X POST http://localhost:8025/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"alice","password":"alice123"}'
```

Salida esperada:

```json
{"note":"Este token nunca expira -- API2:2023 Broken Authentication","token":"token_alice"}
```

Usa este token en los siguientes pasos:

```bash
TOKEN="token_alice"
```

## 3. Disparar BOLA

Alice consulta el perfil de Bob:

```bash
curl -s http://localhost:8025/api/users/2/profile \
  -H "Authorization: Bearer ${TOKEN}"
```

Observacion esperada:

- La API responde con datos de Bob.
- La respuesta incluye campos sensibles como `credit_card`, `ssn` y `salary`.
- La API escribe un evento `bola_attempt`.

## 4. Disparar mass assignment

Alice actualiza su perfil y cambia el campo `role`:

```bash
curl -s -X PUT http://localhost:8025/api/users/1/profile \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"email":"alice+lab@opensec.lab","role":"admin"}'
```

Observacion esperada:

- La API acepta el cambio.
- La respuesta muestra `role` modificado.
- La API escribe un evento `mass_assignment_attempt`.

## 5. Disparar broken function authorization

Alice llama un endpoint administrativo:

```bash
curl -s http://localhost:8025/api/admin/users \
  -H "Authorization: Bearer ${TOKEN}"
```

Observacion esperada:

- La API devuelve la lista de usuarios.
- La API escribe un evento `broken_function_auth`.

## 6. Revisar eventos de la API

Si tienes acceso al host Docker, revisa el log compartido:

```bash
docker exec opsn-api sh -lc 'tail -n 20 /logs/api.log'
```

Eventos esperados:

```text
bola_attempt
mass_assignment_attempt
broken_function_auth
```

## 7. Relacionar eventos con Wazuh

Las reglas del lab usan estos eventos:

| Evento API | Regla Wazuh | Significado |
| --- | --- | --- |
| `bola_attempt` | `100061` | Un usuario accedio a recursos de otro usuario. |
| `mass_assignment_attempt` | `100063` | El request intento modificar campos protegidos. |
| `broken_function_auth` | `100064` | Un usuario no administrador llamo un endpoint administrativo. |

En Wazuh Dashboard busca eventos recientes con:

```text
rule.groups: openseclab_api
```

Si Wazuh sigue iniciando, espera unos minutos y repite la busqueda.

## Mitigaciones

- Validar autorizacion por objeto en cada request.
- No devolver campos sensibles por defecto.
- Usar allowlists de campos actualizables.
- Separar autenticacion de autorizacion.
- Rechazar endpoints administrativos para usuarios sin rol permitido.
- Registrar eventos con suficiente contexto para investigacion.

## Reset rapido

La API usa datos en memoria. Para volver al estado inicial:

```bash
docker restart opsn-api
```

Si tambien quieres limpiar eventos previos:

```bash
docker exec opsn-api sh -lc ': > /logs/api.log'
```
```

- [ ] **Step 4: Add the instructor guide**

Create `services/docs/docs/workshops/api-breach-instructor.md` with this content:

```markdown
# Guia de instructor: Ataque y deteccion en APIs

Esta guia ayuda a facilitar el taller **Ataque y deteccion en APIs** para una clase, meetup, equipo interno o practica individual supervisada.

## Resumen

- Duracion estimada: 45 a 75 minutos.
- Nivel: principiante-intermedio.
- Modo: practica guiada con comandos `curl`.
- Resultado: el estudiante explota tres fallas y relaciona los eventos con reglas de Wazuh.

## Servicios requeridos

Minimo:

- `opsn-api`
- `opsn-docs`

Recomendado para la parte defensiva:

- `opsn-wazuh`
- `opsn-suricata`
- `opsn-portal`

## Preparacion

1. Inicia los servicios requeridos.
2. Espera a que `opsn-api` responda en `http://localhost:8025/api/health`.
3. Si usaras Wazuh, espera a que el dashboard responda en `https://localhost:5601`.
4. Ejecuta el readiness helper cuando exista:

```bash
bash tests/api-breach-readiness.sh
```

## Credenciales y tokens

| Usuario | Password | Token esperado |
| --- | --- | --- |
| `alice` | `alice123` | `token_alice` |
| `bob` | `bob456` | `token_bob` |
| `admin` | `admin_secret` | `token_admin` |

## Evidencia esperada

| Paso | Request | Evento esperado | Regla Wazuh |
| --- | --- | --- | --- |
| BOLA | `GET /api/users/2/profile` con token de Alice | `bola_attempt` | `100061` |
| Mass assignment | `PUT /api/users/1/profile` con campo `role` | `mass_assignment_attempt` | `100063` |
| Broken function auth | `GET /api/admin/users` con token de Alice | `broken_function_auth` | `100064` |

## Puntos de explicacion

- BOLA ocurre cuando el servidor confia en el identificador del objeto solicitado sin validar propiedad o permiso.
- Excessive data exposure aparece cuando la API devuelve mas datos de los necesarios.
- Mass assignment ocurre cuando el servidor aplica campos enviados por el cliente sin una lista permitida.
- Broken function authorization ocurre cuando el servidor autentica al usuario pero no valida si puede ejecutar esa funcion.
- La deteccion depende de eventos con nombres estables, contexto de usuario, endpoint y metodo HTTP.

## Troubleshooting

### La API no responde

Verifica que el contenedor exista:

```bash
docker ps --format '{{.Names}}' | grep -x opsn-api
```

Si no aparece, inicia el perfil de API.

### El token no es `token_alice`

Verifica el usuario y password:

```bash
curl -s -X POST http://localhost:8025/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"alice","password":"alice123"}'
```

### No aparecen eventos en Wazuh

Primero confirma que el log de API tiene eventos:

```bash
docker exec opsn-api sh -lc 'tail -n 20 /logs/api.log'
```

Luego confirma que Wazuh manager esta corriendo:

```bash
docker ps --format '{{.Names}}' | grep -x opsn-wazuh-manager
```

Wazuh puede tardar varios minutos en indexar eventos despues del arranque.

## Reset antes de repetir

```bash
docker restart opsn-api
docker exec opsn-api sh -lc ': > /logs/api.log'
```
```

- [ ] **Step 5: Add the MkDocs Talleres nav**

Modify `services/docs/mkdocs.yml` so the nav includes this block after `Escenarios`:

```yaml
  - Talleres:
    - Ataque y deteccion en APIs: workshops/api-breach.md
    - Guia de instructor: workshops/api-breach-instructor.md
```

- [ ] **Step 6: Run static validation**

Run:

```bash
make test-static
```

Expected: PASS.

- [ ] **Step 7: Run MkDocs build through validation**

Run:

```bash
make validate
```

Expected: PASS.

- [ ] **Step 8: Mark Phase 1 complete in this plan**

Update the ledger row:

```markdown
| Phase 1: Spanish Workshop Docs | Done | `docs: add api breach workshop guides` |
```

- [ ] **Step 9: Commit Phase 1**

Run:

```bash
git add services/docs/docs/workshops/api-breach.md services/docs/docs/workshops/api-breach-instructor.md services/docs/mkdocs.yml tests/static.sh docs/superpowers/plans/2026-05-25-workshop-product-direction.md
git commit -m "docs: add api breach workshop guides"
```

- [ ] **Step 10: Stop and send this next-session prompt**

After the commit succeeds, stop work and send this prompt to the user:

```text
We are in /Users/anegron/Desktop/In_Progress/OSN/opensec-lab-v1 on branch feat/product-direction-workshops.

Continue the OpenSec Lab workshop product direction from:
- docs/superpowers/plans/2026-05-25-workshop-product-direction.md
- docs/superpowers/specs/2026-05-25-workshop-product-direction-design.md

Phase 1 is complete. Start Phase 2: Portal Structure Update.

Rules:
- Use the plan task-by-task.
- Do not continue beyond Phase 2 in this session.
- Keep this as a structural portal update, not the final visual redesign.
- Keep direct service cards prominent and free exploration first-class.
- When Phase 2 is done, update the plan ledger, commit only Phase 2 files, and give me the next-session prompt for Phase 3.
- Preserve unrelated dirty worktree changes.
- Do not stage docs/superpowers/.DS_Store.
- Do not push or open a PR unless I explicitly ask.

Expected Phase 2 commit:
feat: expose free exploration and guided workshops in portal
```

## Phase 2: Portal Structure Update

**Goal:** Expose both product modes in Spanish without doing the final portal redesign.

**Atomic commit:** `feat: expose free exploration and guided workshops in portal`

**Files:**

- Modify: `services/portal/generate_portal.sh`
- Modify: `tests/static.sh`
- Modify: `docs/superpowers/plans/2026-05-25-workshop-product-direction.md`

- [ ] **Step 1: Add failing static assertions for the portal product modes**

Add these assertions near the existing portal assertions in `tests/static.sh`:

```bash
assert_file_contains \
    "portal muestra exploracion libre" \
    "services/portal/generate_portal.sh" \
    "Explorar libremente"

assert_file_contains \
    "portal muestra talleres guiados" \
    "services/portal/generate_portal.sh" \
    "Talleres guiados"

assert_file_contains \
    "portal enlaza taller de APIs" \
    "services/portal/generate_portal.sh" \
    "Taller: Ataque y deteccion en APIs"

assert_file_contains \
    "portal conserva acceso directo a servicios" \
    "services/portal/generate_portal.sh" \
    "Acceso directo a servicios"
```

- [ ] **Step 2: Verify the portal assertions fail**

Run:

```bash
make test-static
```

Expected: FAIL for the new portal copy assertions.

- [ ] **Step 3: Add portal hero/mode CSS**

In `services/portal/generate_portal.sh`, add this CSS before the `/* -- SECTION LABELS -- */` comment:

```css
    .mode-panel {
      display: grid;
      grid-template-columns: minmax(0, 1.2fr) minmax(260px, 0.8fr);
      gap: 1px;
      background: var(--border);
      border: 1px solid var(--border);
      border-radius: 10px;
      overflow: hidden;
      margin-bottom: 1.6rem;
    }

    .mode-block {
      background: var(--bg-card);
      padding: 1rem 1.2rem;
    }

    .mode-kicker {
      font-family: var(--font-mono);
      font-size: 0.62rem;
      color: var(--cyan);
      text-transform: uppercase;
      letter-spacing: 0.12em;
      margin-bottom: 0.45rem;
    }

    .mode-block h1,
    .mode-block h2 {
      font-size: 1.05rem;
      line-height: 1.25;
      margin-bottom: 0.45rem;
    }

    .mode-block p {
      color: var(--text-secondary);
      font-family: 'Segoe UI', system-ui, sans-serif;
      font-size: 0.78rem;
      line-height: 1.55;
      margin-bottom: 0.75rem;
    }

    .mode-actions {
      display: flex;
      flex-wrap: wrap;
      gap: 0.55rem;
    }
```

Also add this line inside the existing mobile media query:

```css
      .mode-panel { grid-template-columns: 1fr; }
```

- [ ] **Step 4: Add the Spanish mode panel above service cards**

In `services/portal/generate_portal.sh`, replace:

```html
  <div id="servicios"></div>
```

with:

```html
  <section class="mode-panel" aria-label="Modos de uso de OpenSec Lab">
    <div class="mode-block">
      <div class="mode-kicker">Explorar libremente</div>
      <h1>Acceso directo a servicios</h1>
      <p>Abre targets, herramientas, documentacion y paneles del lab sin seguir una secuencia obligatoria.</p>
      <div class="mode-actions">
        <a class="btn btn-primary" href="#servicios">Ver servicios</a>
        <a class="btn btn-secondary" href="http://localhost:${PORT_DOCS}" target="_blank">Abrir documentacion</a>
      </div>
    </div>
    <div class="mode-block">
      <div class="mode-kicker">Talleres guiados</div>
      <h2>Taller: Ataque y deteccion en APIs</h2>
      <p>Practica BOLA, mass assignment y autorizacion rota; luego revisa eventos y reglas defensivas.</p>
      <div class="mode-actions">
        <a class="btn btn-primary" href="http://localhost:${PORT_DOCS}/workshops/api-breach/" target="_blank">Abrir taller</a>
      </div>
    </div>
  </section>

  <div id="servicios"></div>
```

- [ ] **Step 5: Keep service cards prominent**

Confirm the existing service sections remain immediately after the mode panel:

```bash
rg -n "Ataque -- Targets Vulnerables|API Vulnerable|Wazuh|Gu|Servicios" services/portal/generate_portal.sh
```

Expected: all patterns are present.

- [ ] **Step 6: Run static validation**

Run:

```bash
make test-static
```

Expected: PASS.

- [ ] **Step 7: Run full validation**

Run:

```bash
make validate
```

Expected: PASS.

- [ ] **Step 8: Mark Phase 2 complete in this plan**

Update the ledger row:

```markdown
| Phase 2: Portal Structure Update | Done | `feat: expose free exploration and guided workshops in portal` |
```

- [ ] **Step 9: Commit Phase 2**

Run:

```bash
git add services/portal/generate_portal.sh tests/static.sh docs/superpowers/plans/2026-05-25-workshop-product-direction.md
git commit -m "feat: expose free exploration and guided workshops in portal"
```

- [ ] **Step 10: Stop and send this next-session prompt**

After the commit succeeds, stop work and send this prompt to the user:

```text
We are in /Users/anegron/Desktop/In_Progress/OSN/opensec-lab-v1 on branch feat/product-direction-workshops.

Continue the OpenSec Lab workshop product direction from:
- docs/superpowers/plans/2026-05-25-workshop-product-direction.md
- docs/superpowers/specs/2026-05-25-workshop-product-direction-design.md

Phase 2 is complete. Start Phase 3: API Breach Readiness Helper.

Rules:
- Use the plan task-by-task.
- Do not continue beyond Phase 3 in this session.
- Keep readiness output Spanish and focused on the API workshop.
- The helper should prove API health, alice login, BOLA, mass assignment, broken function auth, and expected API log events when services are running.
- When Phase 3 is done, update the plan ledger, commit only Phase 3 files, and give me the next-session prompt for Phase 4.
- Preserve unrelated dirty worktree changes.
- Do not stage docs/superpowers/.DS_Store.
- Do not push or open a PR unless I explicitly ask.

Expected Phase 3 commit:
test: add api breach readiness helper
```

## Phase 3: API Breach Readiness Helper

**Goal:** Add a focused Spanish readiness helper that proves API availability and API attack/log event behavior.

**Atomic commit:** `test: add api breach readiness helper`

**Files:**

- Create: `tests/api-breach-readiness.sh`
- Modify: `tests/static.sh`
- Modify: `docs/superpowers/plans/2026-05-25-workshop-product-direction.md`

- [ ] **Step 1: Add a failing static assertion for the helper**

Add this file assertion after the main test file assertions in `tests/static.sh`:

```bash
assert_file_exists "api breach readiness helper" "tests/api-breach-readiness.sh"
```

Add `tests/api-breach-readiness.sh` to the shell syntax loop:

```bash
    tests/api-breach-readiness.sh \
```

- [ ] **Step 2: Verify the new assertion fails**

Run:

```bash
make test-static
```

Expected: FAIL because `tests/api-breach-readiness.sh` does not exist.

- [ ] **Step 3: Create the readiness helper**

Create `tests/api-breach-readiness.sh` with this content:

```bash
#!/usr/bin/env bash
# tests/api-breach-readiness.sh
# Verifica el camino minimo del taller "Ataque y deteccion en APIs".

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

. tests/lib/helpers.sh

ENV_FILE="${OPSN_ENV:-}"
[ -z "$ENV_FILE" ] && [ -f "$HOME/OpenSec_Lab/.env" ] && ENV_FILE="$HOME/OpenSec_Lab/.env"
[ -z "$ENV_FILE" ] && ENV_FILE="config/defaults.env"

# shellcheck disable=SC1090
. "$ENV_FILE" 2>/dev/null || true

PORT_API="${OPSN_API_PORT:-8025}"
API_BASE="${OPSN_API_BASE_URL:-http://localhost:${PORT_API}}"

echo ""
printf "${BOLD}OpenSec Lab - Readiness Taller API Breach${NC}\n"
printf "API: %s\n" "$API_BASE"

api_request() {
    local method="$1"
    local path="$2"
    local token="${3:-}"
    local payload="${4:-}"

    if [ -n "$payload" ] && [ -n "$token" ]; then
        curl -sk --connect-timeout 5 --max-time 10 \
            -X "$method" "$API_BASE$path" \
            -H "Authorization: Bearer ${token}" \
            -H "Content-Type: application/json" \
            -d "$payload"
    elif [ -n "$payload" ]; then
        curl -sk --connect-timeout 5 --max-time 10 \
            -X "$method" "$API_BASE$path" \
            -H "Content-Type: application/json" \
            -d "$payload"
    elif [ -n "$token" ]; then
        curl -sk --connect-timeout 5 --max-time 10 \
            -X "$method" "$API_BASE$path" \
            -H "Authorization: Bearer ${token}"
    else
        curl -sk --connect-timeout 5 --max-time 10 \
            -X "$method" "$API_BASE$path"
    fi
}

container_running() {
    docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$1"
}

log_contains() {
    local event="$1"

    if container_running "opsn-api"; then
        docker exec opsn-api sh -lc "grep -q '\"event\": \"${event}\"' /logs/api.log 2>/dev/null || grep -q '\"event\":\"${event}\"' /logs/api.log 2>/dev/null"
        return $?
    fi

    warn "No se puede verificar el log porque el contenedor opsn-api no esta disponible"
    return 1
}

section "API"

health="$(api_request GET /api/health)"
if printf '%s' "$health" | grep -q '"status":"ok"\|"status": "ok"'; then
    pass "API health responde correctamente"
else
    fail "API health no responde. Inicia opsn-api y revisa ${API_BASE}/api/health"
fi

section "Autenticacion"

login_body="$(api_request POST /api/auth/login "" '{"username":"alice","password":"alice123"}')"
token="$(printf '%s' "$login_body" | sed -n 's/.*"token"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"

if [ "$token" = "token_alice" ]; then
    pass "Login de alice devuelve token_alice"
else
    fail "Login de alice no devolvio token_alice. Respuesta: ${login_body}"
fi

section "Eventos del taller"

bola_body="$(api_request GET /api/users/2/profile "$token")"
if printf '%s' "$bola_body" | grep -q '"username":"bob"\|"username": "bob"'; then
    pass "BOLA responde con perfil de bob"
else
    fail "BOLA no devolvio perfil de bob"
fi

mass_body="$(api_request PUT /api/users/1/profile "$token" '{"email":"alice+lab@opensec.lab","role":"admin"}')"
if printf '%s' "$mass_body" | grep -q '"role":"admin"\|"role": "admin"'; then
    pass "Mass assignment modifica role"
else
    fail "Mass assignment no mostro role admin"
fi

admin_body="$(api_request GET /api/admin/users "$token")"
if printf '%s' "$admin_body" | grep -q '"username":"admin"\|"username": "admin"'; then
    pass "Broken function auth devuelve lista administrativa"
else
    fail "Broken function auth no devolvio lista administrativa"
fi

section "Log de API"

for event in bola_attempt mass_assignment_attempt broken_function_auth; do
    if log_contains "$event"; then
        pass "Log contiene evento ${event}"
    else
        fail "Log no contiene evento ${event}. Revisa docker exec opsn-api sh -lc 'tail -n 20 /logs/api.log'"
    fi
done

section "Wazuh"

if container_running "opsn-wazuh-manager"; then
    pass "Wazuh manager esta corriendo; busca rule.groups: openseclab_api en el dashboard"
else
    warn "Wazuh manager no esta corriendo; la parte de dashboard queda como verificacion manual"
fi

print_summary
```

- [ ] **Step 4: Make the helper executable**

Run:

```bash
chmod +x tests/api-breach-readiness.sh
```

- [ ] **Step 5: Run static validation**

Run:

```bash
make test-static
```

Expected: PASS.

- [ ] **Step 6: Run syntax validation directly**

Run:

```bash
bash -n tests/api-breach-readiness.sh
```

Expected: no output and exit code 0.

- [ ] **Step 7: Run readiness helper when API is available**

If `opsn-api` is running, run:

```bash
bash tests/api-breach-readiness.sh
```

Expected:

- API health passes.
- Login returns `token_alice`.
- BOLA, mass assignment, and broken function auth checks pass.
- Log contains `bola_attempt`, `mass_assignment_attempt`, and `broken_function_auth`.

If API is not running, document that runtime readiness was not executed in the final handoff and keep the static/syntax validation as the completed gate.

- [ ] **Step 8: Mark Phase 3 complete in this plan**

Update the ledger row:

```markdown
| Phase 3: API Breach Readiness Helper | Done | `test: add api breach readiness helper` |
```

- [ ] **Step 9: Commit Phase 3**

Run:

```bash
git add tests/api-breach-readiness.sh tests/static.sh docs/superpowers/plans/2026-05-25-workshop-product-direction.md
git commit -m "test: add api breach readiness helper"
```

- [ ] **Step 10: Stop and send this next-session prompt**

After the commit succeeds, stop work and send this prompt to the user:

```text
We are in /Users/anegron/Desktop/In_Progress/OSN/opensec-lab-v1 on branch feat/product-direction-workshops.

Continue the OpenSec Lab workshop product direction from:
- docs/superpowers/plans/2026-05-25-workshop-product-direction.md
- docs/superpowers/specs/2026-05-25-workshop-product-direction-design.md

Phase 3 is complete. Start Phase 4: Final Validation and Handoff.

Rules:
- Use the plan task-by-task.
- Do not add new product scope in this session.
- Run final validation exactly as documented.
- Run the readiness helper if services are available; if not, document that runtime readiness was not executed.
- Update the plan ledger, commit only Phase 4 files, and summarize the final validation state.
- Preserve unrelated dirty worktree changes.
- Do not stage docs/superpowers/.DS_Store.
- Do not push or open a PR unless I explicitly ask.

Expected Phase 4 commit:
docs: finalize workshop direction implementation status
```

## Phase 4: Final Validation and Handoff

**Goal:** Prove the slice is coherent and leave a clear continuation record.

**Atomic commit:** `docs: finalize workshop direction implementation status`

**Files:**

- Modify: `docs/superpowers/plans/2026-05-25-workshop-product-direction.md`
- Optionally modify: `docs/product-direction/next-session-prompt.md` if the current prompt becomes stale after implementation.

- [ ] **Step 1: Run required validation**

Run:

```bash
make validate
make test-static
```

Expected: both pass.

- [ ] **Step 2: Run targeted readiness if services are available**

Run:

```bash
bash tests/api-breach-readiness.sh
```

Expected when services are running: PASS, with only a Wazuh warning allowed if Wazuh is intentionally not running.

- [ ] **Step 3: Confirm forbidden scoring terms are absent**

Run:

```bash
rg -i "leaderboard|leaderboards|ranking|rankings|badge|badges|puntos|puntaje|insignias" README.md ROADMAP.md USER_GUIDE.md services/docs/docs services/portal/generate_portal.sh docs/product-direction docs/superpowers/specs
```

Expected: no matches.

- [ ] **Step 4: Confirm worktree excludes `.DS_Store`**

Run:

```bash
git status --short
```

Expected: `docs/superpowers/.DS_Store` is not staged.

- [ ] **Step 5: Update next-session prompt if needed**

If `docs/product-direction/next-session-prompt.md` still says implementation has not started or references the old static-test failure, update it to say:

```markdown
Current implementation state:
- Phase 0 through Phase 3 of `docs/superpowers/plans/2026-05-25-workshop-product-direction.md` are complete.
- `make validate` passes.
- `make test-static` passes.
- Runtime readiness is available at `bash tests/api-breach-readiness.sh`.
- Do not push or PR unless explicitly asked.
```

- [ ] **Step 6: Mark Phase 4 complete in this plan**

Update the ledger row:

```markdown
| Phase 4: Final Validation and Handoff | Done | `docs: finalize workshop direction implementation status` |
```

- [ ] **Step 7: Commit Phase 4**

Run:

```bash
git add docs/superpowers/plans/2026-05-25-workshop-product-direction.md docs/product-direction/next-session-prompt.md
git commit -m "docs: finalize workshop direction implementation status"
```

If `docs/product-direction/next-session-prompt.md` did not need edits, omit it from `git add`.

- [ ] **Step 8: Stop and send this completion prompt**

After the commit succeeds, stop work and send this prompt to the user:

```text
Phase 4 is complete for /Users/anegron/Desktop/In_Progress/OSN/opensec-lab-v1 on branch feat/product-direction-workshops.

Please start a fresh session for any publish, review, PR, or follow-up scope.

Fresh-session starting context:
- Read docs/superpowers/plans/2026-05-25-workshop-product-direction.md.
- Confirm all Phase Status Ledger rows are Done.
- Review git status before staging anything.
- Preserve unrelated dirty worktree changes.
- Do not stage docs/superpowers/.DS_Store.
- Do not push or open a PR unless explicitly asked.

Expected completed commits:
- test: align static portal expectations with current Spanish copy
- docs: add api breach workshop guides
- feat: expose free exploration and guided workshops in portal
- test: add api breach readiness helper
- docs: finalize workshop direction implementation status
```

## Deferred Work

Do not include these in this MVP unless a later session explicitly expands scope:

- `./opensec-lab.sh workshop api-breach`
- `./opensec-lab.sh doctor api-breach`
- Final portal visual redesign
- Wazuh UI automation as a hard gate
- Points, badges, leaderboards, scoring, or competitive mechanics
- Additional workshops beyond `api-breach`

## Self-Review Checklist

- [ ] Every approved MVP surface has a task: MkDocs content, portal structure, readiness helper, static validation.
- [ ] Free exploration remains visible and direct service cards remain prominent.
- [ ] All shipped learner/instructor/helper copy is Spanish.
- [ ] No scoring or competitive wording is introduced.
- [ ] Each phase has one atomic commit and a plan-ledger update.
- [ ] Runtime readiness is documented as conditional on services being available.
