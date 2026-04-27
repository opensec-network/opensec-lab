#!/bin/sh
# services/gitea/configure_gitea.sh
# Sidecar idempotente: configura Gitea con repos vulnerables para ejercicios de code review.

. /lib/common.sh

GITEA_URL="http://opsn-gitea:3000"
ADMIN_USER="${OPSN_GITEA_ADMIN_USER:-admin}"
ADMIN_PASS="${OPSN_GITEA_PASSWORD:-Password}"
ADMIN_EMAIL="admin@${OPSN_DOMAIN:-opensec.lab}"
AUTH_HEADER="Authorization: Basic $(printf '%s:%s' "$ADMIN_USER" "$ADMIN_PASS" | base64 | tr -d '\n')"

# ─────────────────────────────────────────────────────
# 1. Esperar que Gitea este disponible
# ─────────────────────────────────────────────────────
wait_for_api "$GITEA_URL" 120 || exit 1

# ─────────────────────────────────────────────────────
# 2. Verificar que el admin existe (creado por gitea-entrypoint.sh)
# ─────────────────────────────────────────────────────

# Esperar a que el admin este disponible via API
log_step "Verificando acceso de admin..."
MAX=20; I=0
until curl -sf -H "$AUTH_HEADER" "$GITEA_URL/api/v1/user" > /dev/null 2>&1; do
    I=$((I+1))
    [ $I -ge $MAX ] && log_error "Admin no disponible via API." && exit 1
    sleep 5
done
log_info "Admin autenticado correctamente."

# ─────────────────────────────────────────────────────
# Funcion: crear repositorio
# ─────────────────────────────────────────────────────
create_repo() {
    local name="$1"
    local description="$2"

    EXISTING=$(curl -sf -H "$AUTH_HEADER" "$GITEA_URL/api/v1/repos/$ADMIN_USER/$name" | \
        sed -n 's/.*"name":"\([^"]*\)".*/\1/p' | head -1)

    if [ -n "$EXISTING" ]; then
        log_info "Repo ya existe: $name"
        return 0
    fi

    api_post "$GITEA_URL/api/v1/user/repos" \
        "{\"name\":\"$name\",\"description\":\"$description\",\"private\":false,\"auto_init\":false,\"default_branch\":\"main\"}" \
        "$AUTH_HEADER" > /dev/null

    log_info "Repo creado: $name"
    sleep 2  # Esperar inicializacion
}

# ─────────────────────────────────────────────────────
# Funcion: crear/actualizar archivo en repo via API
# ─────────────────────────────────────────────────────
create_file() {
    local repo="$1"
    local filepath="$2"
    local message="$3"
    local content_b64="$4"

    # Verificar si el archivo ya existe (necesitamos el SHA para actualizar)
    FILE_INFO=$(curl -sf -H "$AUTH_HEADER" \
        "$GITEA_URL/api/v1/repos/$ADMIN_USER/$repo/contents/$filepath" 2>/dev/null)
    EXISTING_SHA=$(printf '%s' "$FILE_INFO" | sed -n 's/.*"sha":"\([^"]*\)".*/\1/p' | head -1)

    if [ -n "$EXISTING_SHA" ]; then
        # Verificar si el contenido actual ya es el nuestro (comparar longitud del base64)
        EXISTING_SIZE=$(printf '%s' "$FILE_INFO" | sed -n 's/.*"size":\([0-9]*\).*/\1/p' | head -1)
        NEW_SIZE=$(printf '%s' "$content_b64" | base64 -d 2>/dev/null | wc -c | tr -d ' ')
        if [ "$EXISTING_SIZE" = "$NEW_SIZE" ]; then
            log_info "Archivo sin cambios: $repo/$filepath"
            return 0
        fi
        # Actualizar (PUT) con el SHA existente
        curl -s -X PUT -H "$AUTH_HEADER" \
            -H "Content-Type: application/json" \
            -d "{\"message\":\"$message (update)\",\"content\":\"$content_b64\",\"sha\":\"$EXISTING_SHA\"}" \
            "$GITEA_URL/api/v1/repos/$ADMIN_USER/$repo/contents/$filepath" > /dev/null
        log_info "Archivo actualizado: $repo/$filepath"
        return 0
    fi

    api_post "$GITEA_URL/api/v1/repos/$ADMIN_USER/$repo/contents/$filepath" \
        "{\"message\":\"$message\",\"content\":\"$content_b64\"}" \
        "$AUTH_HEADER" > /dev/null

    log_info "Archivo creado: $repo/$filepath"
}

# ─────────────────────────────────────────────────────
# 3. Crear repos con codigo vulnerable
# ─────────────────────────────────────────────────────
log_step "Creando repositorios con codigo vulnerable..."

# ── Repo 1: vulnerable-flask-app ──────────────────────
create_repo "vulnerable-flask-app" \
    "[LABORATORIO] App Flask con vulnerabilidades intencionadas para ejercicios de code review"

# README.md
README_FLASK=$(printf '%s' \
'# vulnerable-flask-app

> **ADVERTENCIA:** Esta aplicacion contiene vulnerabilidades **intencionadas** con fines educativos.
> NO desplegar en produccion.

## Ejercicio de Code Review

Tu tarea es identificar las vulnerabilidades de seguridad en este codigo.

### Vulnerabilidades incluidas (no mirar hasta intentarlo)
<details>
<summary>Spoilers (expandir solo despues de revisar el codigo)</summary>

1. **SQL Injection** en `/user` — concatenacion directa de input en query
2. **Command Injection** en `/ping` — uso de `os.system()` con input del usuario
3. **XSS Reflejado** en `/search` — output de input sin sanitizar en HTML
4. **Path Traversal** en `/files` — no se valida el parametro `filename`
5. **Hardcoded Credentials** — contrasena de DB en el codigo fuente

</details>

## Como usar

```bash
pip install flask
python app.py
```

Luego abre http://localhost:5000 y revisa cada endpoint buscando vulnerabilidades.

## Flag del ejercicio

Despues de identificar las vulnerabilidades, el flag esta en: `OPSN{c0d3_r3v13w_vuln_f0und}`' | base64 | tr -d '\n')

create_file "vulnerable-flask-app" "README.md" "Initial commit: README" "$README_FLASK"

# app.py con vulnerabilidades
APP_PY=$(printf '%s' \
'#!/usr/bin/env python3
"""
vulnerable-flask-app — Aplicacion con vulnerabilidades intencionadas.
USO EXCLUSIVO PARA LABORATORIO EDUCATIVO.
"""
import os
import sqlite3
from flask import Flask, request, render_template_string

app = Flask(__name__)

# VULNERABILIDAD: Credenciales hardcodeadas
DB_PASSWORD = "supersecret123"
DB_PATH = "/tmp/lab.db"

def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.execute("""CREATE TABLE IF NOT EXISTS users
                    (id INTEGER PRIMARY KEY, username TEXT, password TEXT, role TEXT)""")
    conn.execute("INSERT OR IGNORE INTO users VALUES (1, '"'"'admin'"'"', '"'"'admin123'"'"', '"'"'admin'"'"')")
    conn.execute("INSERT OR IGNORE INTO users VALUES (2, '"'"'alice'"'"', '"'"'alice456'"'"', '"'"'user'"'"')")
    conn.commit()
    return conn

@app.route("/")
def index():
    return """
    <h1>vulnerable-flask-app</h1>
    <ul>
      <li><a href="/user?id=1">User lookup (SQLi)</a></li>
      <li><a href="/search?q=test">Search (XSS)</a></li>
      <li><a href="/ping?host=127.0.0.1">Ping (Command Injection)</a></li>
      <li><a href="/files?filename=readme.txt">Files (Path Traversal)</a></li>
    </ul>
    """

@app.route("/user")
def get_user():
    user_id = request.args.get("id", "")
    conn = get_db()
    # VULNERABILIDAD: SQL Injection — concatenacion directa
    query = "SELECT * FROM users WHERE id = " + user_id
    try:
        result = conn.execute(query).fetchall()
        return str(result)
    except Exception as e:
        return "Error: " + str(e)

@app.route("/search")
def search():
    query = request.args.get("q", "")
    # VULNERABILIDAD: XSS Reflejado — sin sanitizar
    template = "<h1>Resultados para: " + query + "</h1>"
    return render_template_string(template)

@app.route("/ping")
def ping():
    host = request.args.get("host", "127.0.0.1")
    # VULNERABILIDAD: Command Injection — os.system con input del usuario
    result = os.popen("ping -c 1 " + host).read()
    return "<pre>" + result + "</pre>"

@app.route("/files")
def read_file():
    filename = request.args.get("filename", "")
    # VULNERABILIDAD: Path Traversal — sin validar la ruta
    base_path = "/tmp/files/"
    try:
        with open(base_path + filename, "r") as f:
            return "<pre>" + f.read() + "</pre>"
    except Exception as e:
        return "Error: " + str(e)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
' | base64 | tr -d '\n')

create_file "vulnerable-flask-app" "app.py" "Add vulnerable Flask app" "$APP_PY"

# requirements.txt
REQS=$(printf 'flask==2.3.3\n' | base64 | tr -d '\n')
create_file "vulnerable-flask-app" "requirements.txt" "Add requirements" "$REQS"

# ── Repo 2: insecure-api ──────────────────────────────
create_repo "insecure-api" \
    "[LABORATORIO] API REST Node.js con vulnerabilidades de seguridad para code review"

README_API=$(printf '%s' \
'# insecure-api

> **ADVERTENCIA:** API con vulnerabilidades **intencionadas** para fines educativos.

## Ejercicio de Code Review

Revisa el codigo de esta API REST y encuentra todas las vulnerabilidades de seguridad.

### Categorias de vulnerabilidades presentes
- Broken Object Level Authorization (BOLA/IDOR)
- Broken Authentication
- Excessive Data Exposure
- Falta de rate limiting
- Credenciales hardcodeadas

### Referencia
OWASP API Security Top 10: https://owasp.org/www-project-api-security/

## Ejecutar

```bash
npm install
node api.js
```

API disponible en http://localhost:3000

## Endpoints

| Metodo | Ruta | Descripcion |
|--------|------|-------------|
| POST | /login | Autenticacion |
| GET | /users/:id | Perfil de usuario |
| GET | /orders/:id | Pedido (vulnerable a BOLA) |
| GET | /admin/users | Lista de usuarios (sin auth) |

## Flag del ejercicio

`OPSN{4p1_s3cur1ty_r3v13w}`' | base64 | tr -d '\n')

create_file "insecure-api" "README.md" "Initial commit: README" "$README_API"

API_JS=$(printf '%s' \
'// insecure-api — API REST con vulnerabilidades intencionadas
// USO EXCLUSIVO PARA LABORATORIO EDUCATIVO

const express = require("express");
const app = express();
app.use(express.json());

// VULNERABILIDAD: Credenciales hardcodeadas en el codigo
const SECRET_KEY = "jwt-secret-hardcoded-12345";
const ADMIN_PASSWORD = "admin123";

// Base de datos simulada en memoria
const users = [
  { id: 1, username: "admin", password: ADMIN_PASSWORD, role: "admin", email: "admin@empresa.com", salary: 150000 },
  { id: 2, username: "alice", password: "alice456", role: "user", email: "alice@empresa.com", salary: 85000 },
  { id: 3, username: "bob",   password: "bob789",   role: "user", email: "bob@empresa.com",   salary: 72000 },
];

const orders = [
  { id: 1, userId: 1, product: "Laptop", amount: 1500, status: "delivered" },
  { id: 2, userId: 2, product: "Mouse",  amount: 30,   status: "pending"   },
  { id: 3, userId: 3, product: "Teclado",amount: 80,   status: "shipped"   },
];

// VULNERABILIDAD: No hay rate limiting en login
app.post("/login", (req, res) => {
  const { username, password } = req.body;
  const user = users.find(u => u.username === username && u.password === password);
  if (!user) return res.status(401).json({ error: "Credenciales incorrectas" });

  // VULNERABILIDAD: Token predecible (no JWT real, solo base64)
  const token = Buffer.from(JSON.stringify({ id: user.id, role: user.role })).toString("base64");
  return res.json({ token, userId: user.id });
});

// VULNERABILIDAD: Excessive Data Exposure — devuelve salary, password hash y datos sensibles
app.get("/users/:id", (req, res) => {
  const user = users.find(u => u.id === parseInt(req.params.id));
  if (!user) return res.status(404).json({ error: "Usuario no encontrado" });
  // Devuelve TODOS los campos incluyendo password y salary
  return res.json(user);
});

// VULNERABILIDAD: BOLA — cualquier usuario puede ver pedidos de otros usuarios
app.get("/orders/:id", (req, res) => {
  // No verifica que el pedido pertenezca al usuario autenticado
  const order = orders.find(o => o.id === parseInt(req.params.id));
  if (!order) return res.status(404).json({ error: "Pedido no encontrado" });
  return res.json(order);
});

// VULNERABILIDAD: Endpoint admin sin autenticacion
app.get("/admin/users", (req, res) => {
  // No verifica si el usuario es admin
  return res.json(users);
});

app.listen(3000, () => console.log("insecure-api corriendo en :3000"));
' | base64 | tr -d '\n')

create_file "insecure-api" "api.js" "Add insecure API" "$API_JS"

PKG_JSON=$(printf '%s' \
'{
  "name": "insecure-api",
  "version": "1.0.0",
  "description": "API vulnerable para laboratorio educativo",
  "main": "api.js",
  "scripts": { "start": "node api.js" },
  "dependencies": { "express": "^4.18.2" }
}' | base64 | tr -d '\n')

create_file "insecure-api" "package.json" "Add package.json" "$PKG_JSON"

log_info "Repositorios de Gitea configurados."
log_info "Gitea disponible en: http://localhost:${OPSN_GITEA_PORT:-3002}"
exit 0
