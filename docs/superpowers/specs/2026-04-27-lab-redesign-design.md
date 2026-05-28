# OpenSec Lab — Diseño de Rediseño v2
**Fecha:** 2026-04-27
**Estado:** Aprobado por el usuario — pendiente de implementación

---

## Contexto

OpenSec Lab es un laboratorio de ciberseguridad basado en Docker dirigido a estudiantes y entusiastas con nivel mixto (principiante e intermedio). El objetivo de este rediseño es darle una identidad central coherente y eliminar servicios que no aportan valor educativo claro.

---

## Identidad central

**"Cada acción ofensiva deja una huella defensiva visible."**

El usuario ejecuta un ataque — phishing, explotación web, ataque a API — y luego abre Wazuh para ver exactamente qué evidencia dejó ese ataque: qué alertas se dispararon, qué patrones quedaron en los logs, qué detectó Suricata.

No son dos roles separados. Es la misma persona aprendiendo las dos caras del mismo evento. Esto es lo que forma a un profesional de seguridad completo.

Los servicios también se pueden usar de forma independiente para práctica libre — la narrativa guiada es opcional, no obligatoria.

---

## Audiencia

- **Principiante:** primer contacto con ciberseguridad, sigue los escenarios guiados en MkDocs
- **Intermedio:** conoce Kali Linux y CTFs, usa los servicios directamente sin guía
- **Ambos:** el Portal tiene dos puntos de entrada diferenciados

---

## Catálogo de servicios

### Servicios que SALEN

| Servicio | Razón |
|----------|-------|
| CTFd + su BD (MariaDB `opsn-ctfd-db`) | Eliminado de esta visión. Ambos contenedores salen. |
| Portainer | Herramienta admin sin propósito pedagógico. Monta docker.sock innecesariamente |
| crAPI (7 contenedores, ~1.5 GB) | Reemplazado por servicio custom más ligero y mejor integrado |
| TheHive + Cortex + Elasticsearch | Fuera del roadmap — demasiado pesado y avanzado para la audiencia |
| BookStack | Reemplazado por MkDocs Material (más moderno, más liviano, sin BD) |

### Servicios que SE MANTIENEN

| Servicio | Rol |
|----------|-----|
| DNS (Technitium) | Infraestructura — resuelve `*.opensec.lab` |
| Mail (Postfix + Roundcube) | Infraestructura del escenario de phishing |
| GoPhish | Ataque: campaña de phishing |
| Desktop (Webtop XFCE) | Víctima simulada — recibe el correo de phishing |
| DVWA | Ataque: vulnerabilidades web (SQLi, XSS, CMDi) |
| Juice Shop | Ataque: OWASP Top 10 con mayor profundidad |
| WebGoat | Aprendizaje guiado estructurado |
| Wazuh + Suricata | Defensa: evidencia de los ataques |
| Gitea | Código vulnerable para análisis estático |
| Portal | Hub central de entrada |
| MkDocs Material (nuevo) | Documentación conectando ataque↔evidencia |

### Servicio que SE AGREGA

| Servicio | Descripción |
|----------|-------------|
| API vulnerable custom (`opsn-api`) | Flask, 1 contenedor, ~150 MB. OWASP API Top 10. Logs estructurados en JSON para Wazuh. Build local desde `services/api/` |

---

## Arquitectura técnica

### Cambios en SERVICES_CATALOG (opensec-lab.sh)

**Salen:** `opsn-ctfd`, `opsn-portainer`, `opsn-crapi`
**Entra:** `opsn-api`
**Cambia:** `opsn-wiki` → `opsn-docs`

### Dependencias actualizadas

```
opsn-api       → independiente
opsn-docs      → requiere opsn-gitea
opsn-gophish   → requiere opsn-dns + opsn-mail
opsn-desktop   → requiere opsn-dns
opsn-wazuh     → requiere opsn-dns
```

### MkDocs Material — implementación

Patrón sidecar ya conocido en el lab:

```
opsn-docs-build (sidecar efímero)
  imagen: squidfunk/mkdocs-material
  acción: clona opensec-lab-docs desde Gitea → mkdocs build → escribe en volumen opsn_docs_html
  restart: "no"

opsn-docs (nginx:alpine)
  sirve: volumen opsn_docs_html
  puerto: 4000 → host
  restart: unless-stopped
```

El repo `opensec-lab-docs` en Gitea se configura read-only para el usuario por defecto. El HTML generado es estático — el usuario no puede editar nada desde el browser.

### API vulnerable custom — diseño

- **Stack:** Flask (Python)
- **Puerto host:** 8025 (liberado al eliminar crAPI)
- **Build:** local desde `build: ./services/api`
- **Vulnerabilidades:** BOLA, autenticación rota, mass assignment, exposición excesiva de datos
- **Logs:** JSON estructurado con campo `event` diferenciado por tipo de ataque

```python
# Ejemplo de log al explotar BOLA
{"event": "bola_attempt", "user_id": 1, "target_id": 2, "endpoint": "/api/users/2/profile", "method": "GET"}
```

- **Integración Wazuh:** logs montados en volumen leído por Wazuh localfile

### Puertos actualizados

| Puerto | Servicio |
|--------|----------|
| 4000 | MkDocs Material (nuevo) |
| 8025 | opsn-api (reutilizado de crAPI) |
| ~~8000~~ | Libre (era CTFd) |
| ~~6875~~ | Libre (era BookStack) |
| ~~9443~~ | Libre (era Portainer) |

---

## Portal — diseño

### Dos puntos de entrada

1. **"Explora el lab libremente"** — lista de todos los servicios instalados con acceso directo. Sin guía.
2. **"Sigue un escenario guiado"** — abre MkDocs en el Escenario 1.

### Cards organizadas por rol

```
[ ATAQUE ]          [ DEFENSA ]       [ INFRAESTRUCTURA ]
GoPhish             Wazuh             DNS
DVWA                                  Mail / Roundcube
Juice Shop                            Desktop
WebGoat
API Vulnerable

[ APRENDIZAJE ]
Documentación (MkDocs)
Repositorios (Gitea)
```

### Widget de alertas en tiempo real

Fetch a la API de Wazuh cada 30 segundos. Muestra las últimas 5 alertas como preview. El usuario puede seguir accediendo directamente a `https://localhost:5601` para ver el dashboard completo — el widget es un punto de entrada, no un reemplazo.

**No hay botón "Iniciar ataque".** El usuario ejecuta cada paso manualmente desde los servicios. La automatización existente (sidecar que pre-configura GoPhish al instalar) se mantiene porque ahorra configuración técnica irrelevante, pero el acto de lanzar el ataque es siempre del usuario.

---

## MkDocs — estructura de contenido

Repo `opensec-lab-docs` en Gitea:

```
docs/
├── index.md                   # Bienvenida + tabla de servicios + cómo usar el lab
├── escenarios/
│   ├── 01-phishing.md         # GoPhish → Desktop → Wazuh
│   ├── 02-web.md              # DVWA / Juice Shop → Wazuh
│   └── 03-api.md              # API vulnerable → Wazuh
├── servicios/
│   ├── gophish.md
│   ├── dvwa.md
│   ├── juice-shop.md
│   ├── webgoat.md
│   ├── wazuh.md               # Cómo leer las alertas
│   └── api.md
└── cheatsheets/
    ├── nmap.md
    ├── burpsuite.md
    ├── curl-api.md
    └── sqlmap.md
```

### Estructura de cada escenario

Cada archivo de escenario tiene dos bloques claramente diferenciados:

```markdown
## Ejecuta el ataque
[pasos concretos, comandos, qué hacer en la UI]

## Qué dejó en los logs
[qué buscar en Wazuh, qué alerta se disparó, qué significa]
```

---

## Integración Wazuh/Suricata

### Flujo técnico por escenario

**Escenario 1 — Phishing:**
```
GoPhish → log HTTP → Suricata (openseclab.rules) → eve.json → opsn_suricata_logs → Wazuh localfile → alerta
```

**Escenario 2 — Web:**
```
DVWA/Juice Shop → logs de contenedor → Wazuh docker-listener → reglas openseclab.xml → alerta
```

**Escenario 3 — API:**
```
opsn-api Flask → JSON logs → volumen montado → Wazuh localfile → reglas custom → alerta
```

### Reglas con contexto educativo

Las descripciones de reglas Wazuh y Suricata se reescriben en español con contexto que conecta la alerta con la acción del estudiante:

```xml
<!-- Wazuh -->
<description>SQL Injection detectado en DVWA — payload en parámetro de query.
Técnica: error-based o union-based. El atacante intenta extraer datos sin credenciales.</description>

<!-- Suricata -->
alert http any any -> any any (msg:"[DVWA] Posible SQL Injection — payload en query string"; ...)
```

---

## Orden de implementación

| Prioridad | Tarea | Impacto |
|-----------|-------|---------|
| 1 | Limpieza del catálogo (eliminar CTFd, Portainer, crAPI, BookStack) | Bajo riesgo, alto impacto |
| 2 | Agregar MkDocs Material (opsn-docs-build + opsn-docs) | Reemplaza BookStack |
| 3 | Crear API vulnerable custom (services/api/) | Reemplaza crAPI |
| 4 | Mejorar reglas Wazuh/Suricata con descripciones educativas | Narrativa ataque↔evidencia |
| 5 | Rediseñar Portal (roles, dos entradas, widget alertas) | UX central |
| 6 | Crear contenido MkDocs (3 escenarios + servicios + cheatsheets) — trabajo de redacción, no de código | Contenido educativo |
| 7 | Polish (comprimir wallpaper, actualizar README/USER_GUIDE, actualizar ROADMAP.md) | Pendientes históricos |

---

## Lo que NO cambia

- Arquitectura de red Docker (`openseclab`, `172.18.0.0/16`)
- Patrón sidecar init para configuración automática
- Sistema de profiles y meta-profiles
- Estimación de RAM y advertencias en el instalador
- `services/lib/common.sh` como biblioteca compartida
- No se publican imágenes Docker en ningún repositorio (decisión pendiente para el futuro)
