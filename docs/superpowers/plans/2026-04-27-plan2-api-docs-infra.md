# Plan 2 — API vulnerable + MkDocs Material (infraestructura)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Agregar dos nuevos servicios al lab — `opsn-api` (Flask con vulnerabilidades OWASP API Top 10) y `opsn-docs` (MkDocs Material servido por nginx) — con sus wires completos: compose, env vars, DNS, opensec-lab.sh, ossec.conf, Makefile, release.yml y tests estáticos.

**Architecture:** El branch de trabajo es `feature/plan2-api-docs-infra`, creado desde `feature/plan1-limpieza`. `opsn-api` es un build local (`./services/api/`) que escribe logs JSON estructurados en el volumen `opsn_api_logs`, compartido con `opsn-wazuh-manager` para ingesta via Wazuh localfile. `opsn-docs` usa un sidecar `opsn-docs-build` (squidfunk/mkdocs-material) que genera HTML estático desde `./services/docs/` al volumen `opsn_docs_html`; nginx lo sirve en el puerto 4000.

**Tech Stack:** Flask 3.1 + Python 3.12-slim; squidfunk/mkdocs-material; nginx:alpine; docker compose profiles.

---

## Mapa de archivos

**Crear:**
- `services/api/Dockerfile`
- `services/api/requirements.txt`
- `services/api/app.py`
- `services/docs/mkdocs.yml`
- `services/docs/nginx.conf`
- `services/docs/docs/index.md`

**Modificar:**
- `docker-compose.yml` — añadir opsn-api, opsn-docs-build, opsn-docs; dos volúmenes nuevos; opsn-api-logs en wazuh-manager; OPSN_API_PORT + OPSN_DOCS_PORT en portal-init
- `services/wazuh/config/ossec.conf` — añadir bloque localfile para api.log
- `config/defaults.env` — OPSN_API_PORT=8025, OPSN_DOCS_PORT=4000
- `.env.example` — mismas variables
- `services/dns/configure_dns.sh` — api.opensec.lab, docs.opensec.lab
- `opensec-lab.sh` — SERVICES_CATALOG, SERVICE_RAM_MB, META_PROFILES, mostrar_credenciales
- `Makefile` — añadir `api docs` a SERVICES
- `.github/workflows/release.yml` — añadir `api docs` al loop y a la tabla de assets
- `tests/static.sh` — assertions para archivos, contenedores, volúmenes, env vars nuevos

---

## Task 1: Flask API vulnerable — archivos del servicio + tests estáticos

**Files:**
- Create: `services/api/Dockerfile`
- Create: `services/api/requirements.txt`
- Create: `services/api/app.py`
- Modify: `tests/static.sh`

- [ ] **Step 1: Añadir assertions en tests/static.sh antes de crear los archivos (TDD)**

Localiza la sección `── Estructura de archivos ──` en `tests/static.sh`. Añade estos archivos a la lista de existencia justo después de `services/portal/nginx.conf`:

```bash
    "services/api/Dockerfile" \
    "services/api/app.py" \
    "services/api/requirements.txt" \
    "services/docs/mkdocs.yml" \
    "services/docs/nginx.conf" \
    "services/docs/docs/index.md"
```

La lista actual termina con un par de líneas que verifica archivos existentes. Busca la línea que cierra el bucle `for f in ... do` (el `done` después de las assertions de archivos) y añade antes del `done`:

```bash
    "services/api/Dockerfile" \
    "services/api/app.py" \
    "services/api/requirements.txt" \
    "services/docs/mkdocs.yml" \
    "services/docs/nginx.conf" \
    "services/docs/docs/index.md" \
```

- [ ] **Step 2: Verificar que los tests fallan (estado previo correcto)**

```bash
bash tests/static.sh 2>&1 | grep -E "✗|Resultado"
```

Esperado: al menos 6 fallos para los archivos que no existen aún.

- [ ] **Step 3: Crear `services/api/requirements.txt`**

```
flask==3.1.0
```

- [ ] **Step 4: Crear `services/api/Dockerfile`**

```dockerfile
FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

RUN mkdir -p /logs

EXPOSE 5000

CMD ["python", "app.py"]
```

- [ ] **Step 5: Crear `services/api/app.py`**

```python
#!/usr/bin/env python3
"""
OPSN API — API vulnerable para practica de OWASP API Security Top 10.

Vulnerabilidades implementadas:
  API1:2023 — Broken Object Level Authorization (BOLA)
  API2:2023 — Broken Authentication (tokens que nunca expiran)
  API3:2023 — Broken Object Property Level Authorization
               (mass assignment + excessive data exposure)
  API5:2023 — Broken Function Level Authorization

Cada explotacion genera un evento JSON en LOG_FILE (/logs/api.log por defecto),
leido por Wazuh via localfile.
"""

import json
import os
from datetime import datetime
from functools import wraps

from flask import Flask, request, jsonify, g

app = Flask(__name__)

LOG_FILE = os.environ.get("LOG_FILE", "/logs/api.log")

# ─── Usuarios en memoria ──────────────────────────────────────────────────────
USERS = {
    1: {
        "id": 1, "username": "alice", "email": "alice@opensec.lab",
        "role": "user", "password": "alice123",
        "credit_card": "4111-1111-1111-1111", "ssn": "123-45-6789",
        "address": "123 Main St", "salary": 75000,
    },
    2: {
        "id": 2, "username": "bob", "email": "bob@opensec.lab",
        "role": "user", "password": "bob456",
        "credit_card": "4222-2222-2222-2222", "ssn": "987-65-4321",
        "address": "456 Oak Ave", "salary": 80000,
    },
    3: {
        "id": 3, "username": "admin", "email": "admin@opensec.lab",
        "role": "admin", "password": "admin_secret",
        "credit_card": "4333-3333-3333-3333", "ssn": "555-55-5555",
        "address": "789 Admin Rd", "salary": 120000,
    },
}

# Tokens estaticos que nunca expiran — API2:2023 Broken Authentication
TOKENS = {
    "token_alice": 1,
    "token_bob": 2,
    "token_admin": 3,
}


def _write_log(event_data: dict) -> None:
    record = {
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "source": "opsn-api",
        "remote_ip": request.remote_addr,
        "method": request.method,
        "path": request.path,
        **event_data,
    }
    try:
        os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)
        with open(LOG_FILE, "a") as fh:
            fh.write(json.dumps(record) + "\n")
    except OSError:
        pass


def _current_user():
    token = request.headers.get("Authorization", "").replace("Bearer ", "")
    user_id = TOKENS.get(token)
    return USERS.get(user_id) if user_id else None


def require_auth(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        user = _current_user()
        if not user:
            _write_log({"event": "auth_failed", "reason": "invalid_or_missing_token"})
            return jsonify({"error": "Unauthorized"}), 401
        g.current_user = user
        return f(*args, **kwargs)
    return decorated


# ─── Health ───────────────────────────────────────────────────────────────────

@app.route("/api/health")
def health():
    return jsonify({"status": "ok", "service": "opsn-api"})


# ─── Autenticacion — API2: token estatico, sin expiracion ────────────────────

@app.route("/api/auth/login", methods=["POST"])
def login():
    data = request.get_json(silent=True) or {}
    username = data.get("username", "")
    password = data.get("password", "")

    for user in USERS.values():
        if user["username"] == username and user["password"] == password:
            token = f"token_{username}"
            _write_log({"event": "login_success", "user_id": user["id"],
                        "username": username})
            return jsonify({
                "token": token,
                "note": "Este token nunca expira — API2:2023 Broken Authentication",
            })

    _write_log({"event": "login_failed", "username": username})
    return jsonify({"error": "Invalid credentials"}), 401


# ─── Perfil de usuario — API1: BOLA + API3: Excessive Data Exposure ──────────

@app.route("/api/users/<int:user_id>/profile", methods=["GET"])
@require_auth
def get_user_profile(user_id):
    target = USERS.get(user_id)
    if not target:
        return jsonify({"error": "User not found"}), 404

    if g.current_user["id"] != user_id:
        _write_log({
            "event": "bola_attempt",
            "user_id": g.current_user["id"],
            "target_id": user_id,
        })

    # API3: devuelve todos los campos incluyendo credit_card, ssn, salary
    return jsonify(target)


# ─── Actualizar perfil — API1: BOLA + API3: Mass Assignment ──────────────────

@app.route("/api/users/<int:user_id>/profile", methods=["PUT"])
@require_auth
def update_user_profile(user_id):
    target = USERS.get(user_id)
    if not target:
        return jsonify({"error": "User not found"}), 404

    data = request.get_json(silent=True) or {}
    updated_fields = list(data.keys())

    if g.current_user["id"] != user_id:
        _write_log({
            "event": "bola_write_attempt",
            "user_id": g.current_user["id"],
            "target_id": user_id,
            "fields": updated_fields,
        })

    if "role" in data or "id" in data:
        _write_log({
            "event": "mass_assignment_attempt",
            "user_id": g.current_user["id"],
            "attempted_fields": updated_fields,
        })

    # Mass assignment: aplica todos los campos sin filtrar
    target.update(data)
    return jsonify({"message": "Updated", "user": target})


# ─── Ordenes — API1: BOLA adicional ──────────────────────────────────────────

@app.route("/api/users/<int:user_id>/orders", methods=["GET"])
@require_auth
def get_user_orders(user_id):
    target = USERS.get(user_id)
    if not target:
        return jsonify({"error": "User not found"}), 404

    if g.current_user["id"] != user_id:
        _write_log({
            "event": "bola_attempt",
            "user_id": g.current_user["id"],
            "target_id": user_id,
            "endpoint": f"/api/users/{user_id}/orders",
        })

    orders = [
        {"id": user_id * 100 + 1, "item": "Laptop", "amount": 1200.00,
         "status": "shipped"},
        {"id": user_id * 100 + 2, "item": "Mouse", "amount": 25.00,
         "status": "delivered"},
    ]
    return jsonify({"user_id": user_id, "orders": orders})


# ─── Admin — API5: Broken Function Level Authorization ───────────────────────

@app.route("/api/admin/users", methods=["GET"])
@require_auth
def list_all_users():
    if g.current_user.get("role") != "admin":
        _write_log({
            "event": "broken_function_auth",
            "user_id": g.current_user["id"],
            "endpoint": "/api/admin/users",
        })

    # Sin verificacion de rol: cualquier usuario autenticado accede
    return jsonify(list(USERS.values()))


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=False)
```

- [ ] **Step 6: Crear `services/docs/mkdocs.yml`**

```yaml
site_name: OpenSec Lab — Documentacion
docs_dir: docs
site_dir: /site

theme:
  name: material
  palette:
    scheme: slate
    primary: red
    accent: orange
  features:
    - navigation.sections
    - navigation.top
    - search.highlight

nav:
  - Inicio: index.md
```

- [ ] **Step 7: Crear `services/docs/docs/index.md`**

```markdown
# OpenSec Lab

Bienvenido al laboratorio de ciberseguridad OpenSec.

> Esta documentacion esta en construccion. Los escenarios guiados estaran disponibles proximamente.

## Servicios disponibles

| Servicio | URL | Descripcion |
|----------|-----|-------------|
| DVWA | http://localhost:8080 | Aplicacion web vulnerable |
| Juice Shop | http://localhost:3000 | OWASP Top 10 |
| WebGoat | http://localhost:8081/WebGoat | Aprendizaje guiado |
| API Vulnerable | http://localhost:8025 | OWASP API Top 10 |
| GoPhish | https://localhost:3333 | Framework de phishing |
| Wazuh | https://localhost:5601 | SIEM - Blue Team |
| Gitea | http://localhost:3002 | Repos de codigo vulnerable |
```

- [ ] **Step 8: Crear `services/docs/nginx.conf`**

```nginx
server {
    listen 80;
    server_name _;

    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

- [ ] **Step 9: Verificar que los tests de existencia de archivos pasan**

```bash
bash tests/static.sh 2>&1 | grep -E "api|docs|Resultado"
```

Esperado: los 6 archivos ahora muestran `✓`. Los tests de compose/env vars aún fallarán — eso es correcto en este paso.

- [ ] **Step 10: Commit**

```bash
git add services/api/ services/docs/ tests/static.sh
git commit -m "feat: add Flask API and MkDocs docs service files"
```

---

## Task 2: Integrar opsn-api en el ecosistema

**Files:**
- Modify: `docker-compose.yml`
- Modify: `services/wazuh/config/ossec.conf`
- Modify: `config/defaults.env`
- Modify: `.env.example`
- Modify: `services/dns/configure_dns.sh`
- Modify: `opensec-lab.sh`

### docker-compose.yml — añadir opsn-api y conectar Wazuh

- [ ] **Step 1: Añadir el servicio opsn-api después del bloque de WebGoat**

El bloque de WebGoat termina con `restart: unless-stopped` y la siguiente línea está en blanco seguida del comentario `# GoPhish Volume Init`. Insertar el bloque nuevo entre WebGoat y GoPhish:

```yaml
  # ─────────────────────────────────────────────────────────────────
  # API Vulnerable — OWASP API Security Top 10 (Flask custom)
  # Profiles: api, all
  # Puerto host: 8025 (liberado al eliminar crAPI)
  # Logs JSON → volumen opsn_api_logs (leidos por Wazuh via localfile)
  # ─────────────────────────────────────────────────────────────────
  opsn-api:
    build: ./services/api
    container_name: opsn-api
    profiles: ["api", "all"]
    environment:
      - LOG_FILE=/logs/api.log
    volumes:
      - opsn_api_logs:/logs
    ports:
      - "${OPSN_API_PORT:-8025}:5000"
    networks:
      - openseclab
    healthcheck:
      test: ["CMD-SHELL", "wget -qO- http://localhost:5000/api/health > /dev/null 2>&1"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 15s
    restart: unless-stopped

```

- [ ] **Step 2: Añadir opsn_api_logs al volumen del Wazuh Manager**

El bloque `opsn-wazuh-manager` tiene una sección `volumes:`. Localizar la línea:

```yaml
      - opsn_suricata_logs:/var/ossec/logs/suricata:ro
```

Añadir inmediatamente después:

```yaml
      - opsn_api_logs:/var/ossec/logs/api:ro
```

- [ ] **Step 3: Añadir OPSN_API_PORT y OPSN_DOCS_PORT al environment de opsn-portal-init**

Localizar la línea `- OPSN_GITEA_PORT=${OPSN_GITEA_PORT:-3002}` en el bloque `opsn-portal-init`. Añadir después:

```yaml
      - OPSN_API_PORT=${OPSN_API_PORT:-8025}
      - OPSN_DOCS_PORT=${OPSN_DOCS_PORT:-4000}
```

- [ ] **Step 4: Añadir opsn_api_logs en la sección volumes al final del compose**

La sección `volumes:` al final del archivo tiene entradas vacías como `opsn_dns_data:`. Añadir:

```yaml
  opsn_api_logs:
```

### ossec.conf — localfile para API logs

- [ ] **Step 5: Añadir bloque localfile en `services/wazuh/config/ossec.conf`**

Localizar el bloque Suricata existente:

```xml
  <!-- ── Suricata eve.json: alertas del IDS ───────────────────── -->
  <!-- eve.json escrito por opsn-suricata en el volumen compartido -->
  <localfile>
    <log_format>json</log_format>
    <location>/var/ossec/logs/suricata/eve.json</location>
    <label key="event_type">suricata</label>
  </localfile>
```

Añadir inmediatamente después:

```xml

  <!-- ── API Vulnerable: JSON logs ────────────────────────────── -->
  <!-- api.log escrito por opsn-api en el volumen opsn_api_logs    -->
  <localfile>
    <log_format>json</log_format>
    <location>/var/ossec/logs/api/api.log</location>
    <label key="source">opsn-api</label>
  </localfile>
```

### config/defaults.env y .env.example

- [ ] **Step 6: Añadir OPSN_API_PORT en `config/defaults.env`**

Localizar la línea:

```
OPSN_WEBGOAT_PORT=8081
```

Añadir después:

```
OPSN_API_PORT=8025
```

- [ ] **Step 7: Añadir OPSN_API_PORT en `.env.example`**

Localizar la sección `# Tier 1: Targets vulnerables adicionales`. Después de `OPSN_WEBGOAT_PORT=8081` añadir:

```
# Puerto de la API vulnerable custom (OWASP API Security Top 10)
OPSN_API_PORT=8025
```

### configure_dns.sh

- [ ] **Step 8: Añadir resolución de API en `services/dns/configure_dns.sh`**

Al final del bloque de resoluciones de IPs (después de `WAZUH_IP=$(resolve_host "opsn-wazuh-dashboard")`), añadir:

```bash
API_IP=$(resolve_host "opsn-api")
```

Al final del archivo, después del bloque de Wazuh y antes del `echo "Configuración DNS completada."`, añadir:

```bash
if [ -n "$API_IP" ]; then
    add_dns_record "A"  "api"       "$API_IP"        ""            "$TTL"
else
    echo "  (api omitido — opsn-api no esta corriendo)" >> /proc/1/fd/1
fi
```

### opensec-lab.sh

- [ ] **Step 9: Añadir opsn-api al SERVICES_CATALOG**

Localizar la línea:

```bash
    "opsn-webgoat|WebGoat — plataforma de aprendizaje guiado OWASP|no|"
```

Añadir después:

```bash
    "opsn-api|API vulnerable — OWASP API Security Top 10 (Flask)|no|"
```

- [ ] **Step 10: Añadir opsn-api al SERVICE_RAM_MB**

Localizar `["opsn-webgoat"]=400` y añadir después:

```bash
    ["opsn-api"]=150
```

- [ ] **Step 11: Actualizar META_PROFILES para incluir opsn-api**

Localizar:

```bash
declare -A META_PROFILES=(
    ["B"]="opsn-wazuh opsn-suricata"
    ["V"]="opsn-dvwa opsn-juice-shop opsn-webgoat"
    ["C"]="opsn-dvwa opsn-juice-shop opsn-webgoat opsn-portal"
    ["F"]="opsn-dns opsn-mail opsn-gophish opsn-desktop opsn-dvwa opsn-juice-shop opsn-webgoat opsn-gitea opsn-portal opsn-wazuh opsn-suricata"
)
```

Reemplazar con:

```bash
declare -A META_PROFILES=(
    ["B"]="opsn-wazuh opsn-suricata"
    ["V"]="opsn-dvwa opsn-juice-shop opsn-webgoat opsn-api"
    ["C"]="opsn-dvwa opsn-juice-shop opsn-webgoat opsn-api opsn-portal opsn-docs"
    ["F"]="opsn-dns opsn-mail opsn-gophish opsn-desktop opsn-dvwa opsn-juice-shop opsn-webgoat opsn-api opsn-gitea opsn-portal opsn-docs opsn-wazuh opsn-suricata"
)
```

- [ ] **Step 12: Añadir opsn-api en mostrar_credenciales()**

Localizar el bloque:

```bash
    service_installed "opsn-webgoat" && \
        printf "  %-18s %-22s %-14s %s\n" "OPSN WebGoat" "guest" "(sin auth)" "http://localhost:$(_port OPSN_WEBGOAT_PORT 8081)/WebGoat"
```

Añadir después:

```bash
    service_installed "opsn-api" && \
        printf "  %-18s %-22s %-14s %s\n" "OPSN API" "(ver /api/health)" "(abierta)" "http://localhost:$(_port OPSN_API_PORT 8025)"
```

- [ ] **Step 13: Verificar tests estáticos**

```bash
bash tests/static.sh 2>&1 | grep -E "opsn-api|OPSN_API|Resultado"
```

Los assertions de container, env var ya pasan porque acabamos de modificar los archivos. Los de volumen y release/Makefile aún fallan — se corrigen en Tasks 3 y 4.

- [ ] **Step 14: Commit**

```bash
git add docker-compose.yml services/wazuh/config/ossec.conf \
        config/defaults.env .env.example \
        services/dns/configure_dns.sh opensec-lab.sh
git commit -m "feat: integrate opsn-api into compose, wazuh, dns and catalog"
```

---

## Task 3: Integrar opsn-docs en el ecosistema

**Files:**
- Modify: `docker-compose.yml`
- Modify: `config/defaults.env`
- Modify: `.env.example`
- Modify: `services/dns/configure_dns.sh`
- Modify: `opensec-lab.sh`

### docker-compose.yml — añadir opsn-docs-build y opsn-docs

- [ ] **Step 1: Añadir opsn-docs-build y opsn-docs después del bloque de Portal**

El bloque `opsn-portal` termina con `restart: unless-stopped`. El siguiente comentario es el bloque de Wazuh (Tier 3). Insertar antes del Tier 3:

```yaml
  # ─────────────────────────────────────────────────────────────────
  # Docs Build — genera HTML con MkDocs Material (sidecar efimero)
  # Profiles: docs, all
  # ─────────────────────────────────────────────────────────────────
  opsn-docs-build:
    image: squidfunk/mkdocs-material
    container_name: opsn-docs-build
    profiles: ["docs", "all"]
    volumes:
      - ./services/docs:/docs
      - opsn_docs_html:/site
    entrypoint: ["mkdocs", "build", "--config-file", "/docs/mkdocs.yml",
                 "--site-dir", "/site"]
    networks:
      - openseclab
    restart: "no"

  # ─────────────────────────────────────────────────────────────────
  # Docs — nginx sirve la documentacion MkDocs Material
  # Profiles: docs, all
  # Puerto: 4000
  # ─────────────────────────────────────────────────────────────────
  opsn-docs:
    image: nginx:alpine
    container_name: opsn-docs
    profiles: ["docs", "all"]
    depends_on:
      opsn-docs-build:
        condition: service_completed_successfully
    volumes:
      - opsn_docs_html:/usr/share/nginx/html:ro
      - ./services/docs/nginx.conf:/etc/nginx/conf.d/default.conf:ro
    ports:
      - "${OPSN_DOCS_PORT:-4000}:80"
    networks:
      - openseclab
    restart: unless-stopped

```

- [ ] **Step 2: Añadir opsn_docs_html en la sección volumes**

En la sección `volumes:` final del compose, añadir junto a `opsn_api_logs:`:

```yaml
  opsn_docs_html:
```

### config/defaults.env y .env.example

- [ ] **Step 3: Añadir OPSN_DOCS_PORT en `config/defaults.env`**

Localizar:

```
OPSN_API_PORT=8025
```

Añadir después:

```
OPSN_DOCS_PORT=4000
```

- [ ] **Step 4: Añadir OPSN_DOCS_PORT en `.env.example`**

Localizar la nueva línea `OPSN_API_PORT=8025` y añadir después:

```
# Puerto de la documentacion MkDocs Material
OPSN_DOCS_PORT=4000
```

### configure_dns.sh

- [ ] **Step 5: Añadir resolución de Docs en `services/dns/configure_dns.sh`**

Después de `API_IP=$(resolve_host "opsn-api")`, añadir:

```bash
DOCS_IP=$(resolve_host "opsn-docs")
```

Después del bloque condicional de `api`, añadir:

```bash
if [ -n "$DOCS_IP" ]; then
    add_dns_record "A"  "docs"      "$DOCS_IP"       ""            "$TTL"
else
    echo "  (docs omitido — opsn-docs no esta corriendo)" >> /proc/1/fd/1
fi
```

### opensec-lab.sh

- [ ] **Step 6: Añadir opsn-docs al SERVICES_CATALOG**

Localizar:

```bash
    "opsn-gitea|Gitea — repos con código vulnerable para análisis estático|yes|"
```

Añadir después:

```bash
    "opsn-docs|Documentacion guiada MkDocs Material|no|"
```

- [ ] **Step 7: Añadir opsn-docs al SERVICE_RAM_MB**

Localizar `["opsn-api"]=150` y añadir después:

```bash
    ["opsn-docs"]=50
```

- [ ] **Step 8: Añadir opsn-docs en mostrar_credenciales()**

Localizar:

```bash
    service_installed "opsn-gitea" && \
        printf "  %-18s %-22s %-14s %s\n" "OPSN Gitea" ...
```

Añadir antes del bloque de `opsn-portal`:

```bash
    service_installed "opsn-docs" && \
        printf "  %-18s %-22s %-14s %s\n" "OPSN Docs" "(documentacion)" "(abierta)" "http://localhost:$(_port OPSN_DOCS_PORT 4000)"
```

- [ ] **Step 9: Verificar compose es válido**

```bash
cp config/defaults.env .env && docker compose config --quiet && rm -f .env
```

Esperado: exit 0, sin errores.

- [ ] **Step 10: Commit**

```bash
git add docker-compose.yml config/defaults.env .env.example \
        services/dns/configure_dns.sh opensec-lab.sh
git commit -m "feat: integrate opsn-docs into compose, dns and catalog"
```

---

## Task 4: Makefile, release.yml y tests estáticos — validación final

**Files:**
- Modify: `Makefile`
- Modify: `.github/workflows/release.yml`
- Modify: `tests/static.sh`

### Makefile

- [ ] **Step 1: Añadir `api docs` a la variable SERVICES**

Localizar:

```makefile
SERVICES  := dns mail desktop gophish gitea portal wazuh suricata
```

Reemplazar con:

```makefile
SERVICES  := dns mail desktop gophish gitea portal wazuh suricata api docs
```

### release.yml

- [ ] **Step 2: Añadir `api docs` al loop de empaquetado**

Localizar:

```yaml
          for svc in dns mail desktop gophish gitea portal wazuh suricata; do
```

Reemplazar con:

```yaml
          for svc in dns mail desktop gophish gitea portal wazuh suricata api docs; do
```

- [ ] **Step 3: Añadir las dos entradas en la tabla de assets del body**

Localizar en el `body:` del paso `Create GitHub Release`:

```yaml
            | `opsn-suricata.tar.gz` | Config y reglas custom de Suricata |
```

Añadir después:

```yaml
            | `opsn-api.tar.gz` | API Flask vulnerable (OWASP API Top 10) |
            | `opsn-docs.tar.gz` | Configuracion MkDocs Material + placeholder |
```

### tests/static.sh — assertions de contenedores, volúmenes, env vars y release

- [ ] **Step 4: Añadir assertions de containers en la sección Docker Compose**

En la lista de containers dentro del bucle `for service in opsn-dns ... do`, añadir `opsn-api opsn-docs-build opsn-docs`:

```bash
for service in opsn-dns opsn-dvwa opsn-juice-shop opsn-webgoat opsn-api \
               opsn-gophish opsn-desktop opsn-mail \
               opsn-gitea opsn-gitea-init \
               opsn-docs-build opsn-docs \
               opsn-portal opsn-portal-init; do
    assert_file_contains "compose tiene $service" "$COMPOSE" "container_name: $service"
done
```

- [ ] **Step 5: Añadir assertions de volúmenes**

Localizar el bucle de volumes:

```bash
for vol in opsn_dns_data opsn_dvwa_data opsn_gophish_data opsn_mail_data \
           opsn_gitea_data opsn_portal_html; do
```

Reemplazar con:

```bash
for vol in opsn_dns_data opsn_dvwa_data opsn_gophish_data opsn_mail_data \
           opsn_gitea_data opsn_portal_html \
           opsn_api_logs opsn_docs_html; do
```

- [ ] **Step 6: Añadir assertions de env vars**

En la sección de env vars, localizar el bucle Tier 1:

```bash
# Tier 1
for var in OPSN_WEBGOAT_PORT; do
    assert_env_var "defaults.env (Tier 1)" "$DEFAULTS" "$var"
done
```

Añadir después:

```bash
# API y Docs
for var in OPSN_API_PORT OPSN_DOCS_PORT; do
    assert_env_var "defaults.env (API/Docs)" "$DEFAULTS" "$var"
done
```

- [ ] **Step 7: Añadir assertions de release.yml y Makefile**

Localizar el bucle de release.yml:

```bash
for svc in dns mail desktop gophish gitea portal; do
    assert_file_contains "release.yml incluye $svc" "$RELEASE" "$svc"
done
```

Reemplazar con:

```bash
for svc in dns mail desktop gophish gitea portal api docs; do
    assert_file_contains "release.yml incluye $svc" "$RELEASE" "$svc"
done
```

Localizar los assertions de Makefile:

```bash
assert_file_contains "Makefile SERVICES incluye gitea" "Makefile" "gitea"
assert_file_contains "Makefile SERVICES incluye portal" "Makefile" "portal"
```

Añadir después:

```bash
assert_file_contains "Makefile SERVICES incluye api" "Makefile" "api"
assert_file_contains "Makefile SERVICES incluye docs" "Makefile" "docs"
```

- [ ] **Step 8: Ejecutar todos los tests estáticos**

```bash
bash tests/static.sh 2>&1
```

Esperado: todos los tests pasan. La línea de resultado debe mostrar `X/X tests pasaron` sin fallos.

- [ ] **Step 9: Verificar compose es válido**

```bash
cp config/defaults.env .env && docker compose config --quiet && rm -f .env
```

Esperado: exit 0.

- [ ] **Step 10: Verificar sintaxis de scripts**

```bash
bash -n opensec-lab.sh && echo "opensec-lab.sh: OK"
bash -n services/dns/configure_dns.sh && echo "configure_dns.sh: OK"
bash -n services/api/app.py 2>&1 || python3 -c "import ast; ast.parse(open('services/api/app.py').read()); print('app.py: OK')"
```

Esperado: OK en los tres. (El último usa python3 para validar sintaxis Python.)

- [ ] **Step 11: Commit final**

```bash
git add Makefile .github/workflows/release.yml tests/static.sh
git commit -m "chore: update makefile, release workflow and static tests for api and docs"
```

---

## Resumen de verificaciones finales

Antes de dar el plan por completado, ejecutar:

```bash
# 1. Tests estáticos — debe mostrar N/N tests pasaron, 0 fallos
bash tests/static.sh

# 2. Validación del compose
cp config/defaults.env .env && docker compose config --quiet && rm -f .env

# 3. Verificar que los directorios de servicios existen
ls services/api/
ls services/docs/docs/

# 4. Verificar que no quedan referencias a servicios eliminados
grep -rn "opsn-crapi\|opsn-portainer\|opsn-wiki\|CTFD" \
    docker-compose.yml opensec-lab.sh config/defaults.env .env.example \
    services/dns/configure_dns.sh tests/static.sh
```

Resultado esperado del último comando: sin salida (grep vacío).
