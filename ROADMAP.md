# OpenSec Lab — Roadmap de Expansion v2

> Documento vivo. Actualizar el estado de cada item al completarlo.
> Ultima actualizacion: 2026-03-31 (Cabos sueltos Fases 1-3 cerrados: sidecar Wazuh, reto #8 CTFd, guia BookStack, widget leaderboard, meta-profiles, release.yml alineado)
>
> **Como usar este documento:**
> Al iniciar una sesion de desarrollo, leer este archivo para saber donde quedamos.
> Al completar un item, cambiar `[ ]` por `[x]` y anotar la fecha.

---

## Vision

Transformar OpenSec Lab de un simulador de phishing + apps vulnerables en una
plataforma completa de entrenamiento en ciberseguridad con:

- Ejercicios pre-creados y conectados entre servicios (flags plantados)
- Gamificacion con scoring y leaderboard (CTFd)
- Deteccion y analisis (Wazuh SIEM + Suricata IDS)
- Respuesta a incidentes (TheHive)
- Aprendizaje guiado (BookStack + Gitea)
- Portal central que unifica todo

**Audiencia:** Aprendices y profesionales por igual. Instalacion modular — el usuario elige que instalar.

---

## Recursos del Sistema por Escenario

| Escenario | RAM Minima | Contenedores | Notas |
|-----------|-----------|--------------|-------|
| Tier 0 solamente (actual) | 6 GB | 6 | Estado actual del lab |
| Tier 0 + Tier 1 completo | 6 GB | ~13 | Sin Blue Team |
| + Wazuh + Suricata | 12 GB | ~16 | Con deteccion |
| Full lab (todo) | 16 GB | 19+ | Incluyendo TheHive |

---

## Dependencias entre servicios

El script resuelve dependencias automaticamente. Reglas:

```
WebGoat      → independiente
crAPI        → independiente
Portainer    → independiente
DVWA         → independiente
Juice Shop   → independiente
CTFd         → requiere DNS
BookStack    → requiere DNS
Gitea        → requiere DNS
Wazuh        → requiere DNS
Suricata     → requiere DNS
TheHive      → requiere DNS + Wazuh
GoPhish      → requiere DNS + Mail
Desktop      → requiere DNS
Mail         → requiere DNS
Portal       → requiere DNS
```

---

## Fase 1 — Quick Wins: Targets vulnerables adicionales

> Solo imagenes Docker, sin init scripts. Prioridad maxima.

| # | Servicio | Container | Imagen | Puerto Host | RAM | Dependencias | Estado |
|---|----------|-----------|--------|-------------|-----|--------------|--------|
| 1.1 | WebGoat | opsn-webgoat | webgoat/webgoat:latest | 8081 | ~300 MB | ninguna | [x] Completado 2026-03-28 |
| 1.2 | crAPI | opsn-crapi | crapi/crapi-all:latest | 8025 | ~500 MB | ninguna | [x] Completado 2026-03-28 |
| 1.3 | Portainer | opsn-portainer | portainer/portainer-ce:latest | 9443 | ~150 MB | ninguna | [x] Completado 2026-03-28 |

> **Nota crAPI ARM64:** Verificar soporte ARM64 de la imagen all-in-one. Si no existe, usar imagen multi-container.
> **Nota Portainer:** Monta `/var/run/docker.sock` — es herramienta admin, NO un target de ataque. Documentar en guia de usuario.

### Tareas transversales Fase 1

- [x] Agregar los 3 servicios a `docker-compose.yml` (con profiles: ["nombre", "all"]) — 2026-03-28
- [x] Actualizar `SERVICES_CATALOG` en `opensec-lab.sh` — 2026-03-28
- [x] Agregar variables a `config/defaults.env` y `.env.example` — 2026-03-28
  - `OPSN_WEBGOAT_PORT=8081`
  - `OPSN_CRAPI_PORT=8025`
  - `OPSN_PORTAINER_PORT=9443`
- [x] Actualizar `services/dns/configure_dns.sh` con nuevos A records (webgoat, crapi, portainer) — 2026-03-28
- [x] Actualizar `mostrar_credenciales()` en `opensec-lab.sh` — 2026-03-28
- [x] Actualizar `Makefile` si aplica (SERVICES no necesita tarballs para estos — sin cambios) — 2026-03-28
- [x] Tests estáticos: 124/124 pasando (`make test-static`) — 2026-03-28
- [x] Smoke tests creados (`tests/smoke.sh`) — 2026-03-28
- [x] Smoke tests ejecutados con lab corriendo: 53/53 pasando — 2026-03-29
- [ ] Test en AMD64
- [ ] Test en ARM64 (especialmente crAPI)

---

## Fase 2 — Gamificacion y Aprendizaje (con init scripts)

> Prioridad alta. Requiere scripts de configuracion automatica via API.

| # | Servicio | Container | Imagen | Puerto Host | RAM | Init Script | Estado |
|---|----------|-----------|--------|-------------|-----|-------------|--------|
| 2.1 | CTFd | opsn-ctfd | ctfd/ctfd:latest | 8000 | ~200 MB | configure_ctfd.sh | [x] Completado 2026-03-28 |
| 2.1b | CTFd DB | opsn-ctfd-db | mariadb:10.11 | (interno) | ~150 MB | (con 2.1) | [x] Completado 2026-03-28 |
| 2.2 | BookStack | opsn-wiki | lscr.io/linuxserver/bookstack:latest | 6875 | ~200 MB | configure_wiki.sh | [x] Completado 2026-03-28 |
| 2.2b | BookStack DB | opsn-wiki-db | mariadb:10.11 | (interno) | ~150 MB | (con 2.2) | [x] Completado 2026-03-28 |
| 2.3 | Gitea | opsn-gitea | gitea/gitea:latest | 3002 / 2222 | ~200 MB | configure_gitea.sh | [x] Completado 2026-03-28 |
| 2.4 | Portal Central | opsn-portal | nginx:alpine | 8443 | ~30 MB | portal-init | [x] Completado 2026-03-28 |

### Contenido pre-cargado (init sidecars)

**CTFd — Retos pre-creados con flags:**

| Reto | Categoria | Fuente del Flag | Puntos |
|------|-----------|-----------------|--------|
| Analisis de campana de phishing | Social Engineering | Flag en source HTML del landing page GoPhish | 100 |
| SQL Injection en DVWA | Web | Flag plantado en BD de DVWA via init | 150 |
| Score Board de Juice Shop | Web | Reto nativo de Juice Shop | 200 |
| Lecciones de WebGoat | Learning | Completar leccion especifica | 50 c/u |
| BOLA en crAPI | API Security | Flag en objeto de usuario crAPI | 200 |
| Analisis de headers de email | Forensics | Flag en headers del mail de GoPhish | 100 |
| Zone Transfer DNS | Recon | Flag como TXT record en Technitium | 75 |
| Triage de alertas Suricata | Blue Team | Identificar patron de alerta especifico | 150 |

**CTFd — Achievement badges por categoria (se desbloquean al completar todos los retos de una categoria):**
- [ ] Badge "Phisher" — completar Social Engineering (requiere CTFd plugins, dejar para Fase 5)
- [ ] Badge "Web Hacker" — completar Web
- [ ] Badge "API Ninja" — completar API Security
- [ ] Badge "Detective" — completar Forensics
- [ ] Badge "Blue Teamer" — completar Blue Team

**BookStack — Contenido pre-cargado:**
- [x] Guia: Bienvenido a OpenSec Lab (intro con tabla de servicios y credenciales) — 2026-03-28
- [x] Guia: SQL Injection paso a paso en DVWA — 2026-03-28
- [x] Guia: Como lanzar campana de phishing con GoPhish — 2026-03-28
- [x] Cheat Sheet: nmap (escaneo de redes) — 2026-03-28
- [x] Cheat Sheet: Burp Suite (proxy web) — 2026-03-28
- [x] Cheat Sheet: sqlmap (inyeccion SQL automatizada) — 2026-03-28
- [x] Guia: Como explorar Juice Shop — 2026-03-28
- [x] Guia: Pruebas de seguridad en APIs con crAPI (BOLA) — 2026-03-28
- [x] Guia: Analisis de logs en Wazuh — 2026-03-31
- [x] Cheat Sheet: hydra (fuerza bruta) — 2026-03-28
- [x] Cheat Sheet: curl (API testing) — 2026-03-28

**Gitea — Repos seed con codigo vulnerable:**
- [x] Repo `vulnerable-flask-app` — Flask con SQLi, Command Injection, XSS, Path Traversal, Hardcoded Creds — 2026-03-28
- [x] Repo `insecure-api` — Node.js con BOLA, Excessive Data Exposure, no-auth admin endpoint — 2026-03-28

**Portal — Dashboard central:**
- [x] Cards con link a cada servicio (organizadas por seccion) — 2026-03-28
- [x] Tabla de credenciales por defecto — 2026-03-28
- [x] Widget de leaderboard CTFd (iframe o API fetch) — 2026-03-31
- [x] Estado de salud (verde/rojo) via JavaScript fetch en el browser — 2026-03-28

### Nuevo archivo compartido

- [x] Crear `services/lib/common.sh` — Funciones compartidas para todos los init scripts — 2026-03-28

### Flags plantados en otros servicios

- [x] Flag en landing page GoPhish: `OPSN{ph1sh1ng_aw4r3n3ss_ch4ll3ng3}` en comentario HTML — 2026-03-28
- [x] Flag en DNS: TXT record `flag.opensec.lab` = `OPSN{dns_r3c0n_m4st3r}` — 2026-03-28

### Tareas transversales Fase 2

- [x] Crear `services/ctfd/configure_ctfd.sh` (7 retos pre-cargados via API) — 2026-03-28
- [x] Crear `services/wiki/bookstack-init.sh` (artisan tinker, token API, credenciales) — 2026-03-28
- [x] Crear `services/wiki/configure_wiki.sh` (2 libros, 5+ paginas via API) — 2026-03-28
- [x] Crear `services/gitea/configure_gitea.sh` (setup + 2 repos + archivos via API) — 2026-03-28
- [x] Crear `services/portal/generate_portal.sh` (genera HTML desde env vars) — 2026-03-28
- [x] Crear `services/portal/nginx.conf` — 2026-03-28
- [x] Agregar todos los servicios Fase 2 a `docker-compose.yml` — 2026-03-28
- [x] Agregar variables a `config/defaults.env` y `.env.example` — 2026-03-28
- [x] Actualizar `SERVICES_CATALOG` en `opensec-lab.sh` — 2026-03-28
- [x] Actualizar `mostrar_credenciales()` en `opensec-lab.sh` — 2026-03-28
- [x] Actualizar `configure_dns.sh` con A records (ctf, wiki, git, portal, lab) y TXT flag — 2026-03-28
- [x] Actualizar `Makefile` SERVICES para incluir tarballs de Fase 2 — 2026-03-28
- [x] Validar con `docker compose config --quiet` — OK 2026-03-28
- [x] Actualizar `release.yml` para empaquetar nuevos tarballs — 2026-03-28 (portainer/wazuh/suricata agregados 2026-03-31)
- [ ] Test en AMD64 y ARM64

---

## Fase 3 — Blue Team: SIEM + IDS

> Requiere 12+ GB RAM. El script debe advertir al usuario antes de instalar.

| # | Servicio | Container | Imagen | Puerto Host | RAM | Init Script | Estado |
|---|----------|-----------|--------|-------------|-----|-------------|--------|
| 3.1 | Wazuh Manager | opsn-wazuh-manager | wazuh/wazuh-manager:4.9.0 | 55000 | ~700 MB | configure_wazuh.sh | [x] Implementado 2026-03-29 |
| 3.2 | Wazuh Indexer | opsn-wazuh-indexer | wazuh/wazuh-indexer:4.9.0 | (interno) | ~1,500 MB | (certs via opsn-wazuh-certs) | [x] Implementado 2026-03-29 |
| 3.3 | Wazuh Dashboard | opsn-wazuh-dashboard | wazuh/wazuh-dashboard:4.9.0 | 5601 | ~500 MB | (con 3.1) | [x] Implementado 2026-03-29 |
| 3.4 | Suricata | opsn-suricata | jasonish/suricata:latest | (sin puertos) | ~500 MB | (config via volume) | [x] Implementado 2026-03-29 |

### Integraciones Blue Team

- [x] Wazuh Manager monta `/var/run/docker.sock` (docker-listener module) — 2026-03-29
- [x] Suricata escribe `eve.json` en volumen compartido (`opsn_suricata_logs`) — Wazuh lee via localfile — 2026-03-29
- [x] Reglas custom en Wazuh: DVWA (SQLi, CMDi, XSS, FI), Juice Shop, GoPhish, WebGoat, crAPI, Suricata alerts — 2026-03-29
- [x] Reglas custom en Suricata: SQLi, CMDi, XSS, BOLA crAPI, port scan, brute force HTTP, DNS flag CTF — 2026-03-29
- [ ] Dashboards pre-construidos en Wazuh (pendiente — Wazuh tiene dashboards por defecto)
- [ ] Reto de Blue Team en CTFd: "Identifica el ataque" (pendiente Fase 5)

### Tareas transversales Fase 3

- [x] Crear `services/wazuh/config/certs.yml` — configuracion del generador de certificados SSL — 2026-03-29
- [x] Crear `services/wazuh/config/ossec.conf` — config del manager con docker-listener y localfile eve.json — 2026-03-29
- [x] Crear `services/wazuh/config/wazuh_indexer.yml` — config OpenSearch single-node — 2026-03-29
- [x] Crear `services/wazuh/config/opensearch_dashboards.yml` — config Dashboard — 2026-03-29
- [x] Crear `services/wazuh/config/wazuh.yml` — conexion Dashboard → Manager API — 2026-03-29
- [x] Crear `services/wazuh/rules/openseclab.xml` — reglas custom para el lab — 2026-03-29
- [x] Crear `services/wazuh/configure_wazuh.sh` — sidecar de inicializacion post-arranque — 2026-03-31 (logica extraida de opensec-lab.sh; sidecar opsn-wazuh-init agregado al compose)
- [x] Crear `services/suricata/suricata.yaml` — config con interface "any" (captura todo el trafico) — 2026-03-29
- [x] Crear `services/suricata/rules/openseclab.rules` — reglas custom para trafico del lab — 2026-03-29
- [x] Implementar `estimar_ram()` en `opensec-lab.sh` — avisa si RAM estimada > 80% disponible — 2026-03-29
- [x] Implementar meta-profiles en `opensec-lab.sh` (B=Blue Team, V=Vuln Targets, C=CTF Ready, F=Full Lab) — 2026-03-29
- [x] Verificar `vm.max_map_count` en el host antes de instalar Wazuh — 2026-03-29
- [x] Agregar variables a `config/defaults.env` (OPSN_WAZUH_PASSWORD, OPSN_WAZUH_API_PASSWORD, OPSN_WAZUH_DASH_PORT, OPSN_WAZUH_API_PORT, OPSN_SURICATA_INTERFACE) — 2026-03-29
- [x] Actualizar `configure_dns.sh` con registro A para wazuh.opensec.lab — 2026-03-29
- [x] Actualizar `Makefile` SERVICES para incluir wazuh + suricata — 2026-03-29
- [x] Test en sistema de 16 GB Docker Desktop — 64/65 smoke tests (crAPI no levantado en esa sesion) — 2026-03-29

---

## Fase 4 — Incident Response avanzado

> Requiere 16+ GB RAM. Profile dedicado `incident-response`. NO incluir en profile `all`.

| # | Servicio | Container | Imagen | Puerto Host | RAM | Init Script | Estado |
|---|----------|-----------|--------|-------------|-----|-------------|--------|
| 4.1 | TheHive | opsn-thehive | strangebee/thehive:5.3 | 9000 | ~500 MB | thehive-init | [ ] Pendiente |
| 4.2 | Elasticsearch | opsn-thehive-es | elasticsearch:7.17.28 | (interno) | ~1,500 MB | (con 4.1) | [ ] Pendiente |
| 4.3 | Cortex | opsn-cortex | thehiveproject/cortex:3.1.8 | 9001 | ~500 MB | (con 4.1) | [ ] Pendiente |
| 4.4 | Servicio vulnerable custom | opsn-vuln-custom | build local | 8082 | ~100 MB | (propio) | [ ] Pendiente |

> **Nota TheHive:** ARM64 puede requerir imagen custom o build propio. Verificar.
> **Nota Cortex:** Historial de issues en ARM64. Evaluar alternativas.
> **Nota servicio custom:** Tecnologia por definir (Flask/Node/Go). Debe tener flags para CTFd.

### Integraciones Fase 4

- [ ] Wazuh -> TheHive alert forwarding (via Wazuh integration module)
- [ ] Casos de IR pre-armados en TheHive (escenarios reales con alertas del lab)
- [ ] Servicio vulnerable custom con flags para nuevos retos en CTFd
- [ ] Dashboards avanzados en Wazuh para correlacion de eventos

---

## Fase 5 — Polish y documentacion

- [ ] Comprimir `services/desktop/opsn-background.jpg` a menos de 1 MB (actualmente ~15 MB)
- [ ] Publicar `opensecnetwork/mail:multi-arch` y cambiar `build:` por `image:` en compose
- [ ] Contenido completo en BookStack (todas las guias de ejercicios)
- [ ] Repos completos en Gitea (codigo vulnerable bien documentado)
- [ ] Actualizar `USER_GUIDE.md` con todos los servicios nuevos
- [ ] Actualizar `README.md` con tabla expandida de servicios
- [ ] Agregar `make validate` al CI (lint en cada PR)
- [ ] Registrar dominio `opensec.network` y apuntar `lab.opensec.network/install`
- [ ] **Modo taller:** Opcion en el script para que un instructor pre-configure servicios + retos CTFd y genere un comando de instalacion personalizado para sus estudiantes
- [ ] Bookmarks de cheat sheets pre-instalados en el navegador del Desktop (`custom-init.sh`)

---

## Mapa de Puertos Completo

| Puerto | Servicio | Protocolo | Fase |
|--------|----------|-----------|------|
| 25 | Mail (SMTP) | TCP | 0 |
| 53 | DNS | UDP/TCP | 0 |
| 80 | GoPhish (phish listener) | TCP | 0 |
| 143 | Mail (IMAP) | TCP | 0 |
| 587 | Mail (submission) | TCP | 0 |
| 2222 | Gitea (SSH) | TCP | 2 |
| 3000 | Juice Shop | TCP | 0 |
| 3002 | Gitea (HTTP) | TCP | 2 |
| 3100 | Desktop (HTTP) | TCP | 0 |
| 3101 | Desktop (HTTPS) | TCP | 0 |
| 3333 | GoPhish (admin) | TCP | 0 |
| 5380 | DNS (admin console) | TCP | 0 |
| 5601 | Wazuh Dashboard | TCP | 3 |
| 6875 | BookStack | TCP | 2 |
| 8000 | CTFd | TCP | 2 |
| 8025 | crAPI | TCP | 1 |
| 8080 | DVWA | TCP | 0 |
| 8081 | WebGoat | TCP | 1 |
| 8082 | VulnCustom | TCP | 4 |
| 8443 | Portal (HTTP) | TCP | 2 |
| 8888 | Mail (Roundcube webmail) | TCP | 0 |
| 9000 | TheHive | TCP | 4 |
| 9001 | Cortex | TCP | 4 |
| 9443 | Portainer | TCP | 1 |
| 55000 | Wazuh API | TCP | 3 |

---

## Meta-Profiles

Se implementan en `opensec-lab.sh` como expansion de profiles antes de llamar a Docker Compose:

| Meta-Profile | Se expande a | RAM minima |
|-------------|-------------|-----------|
| `vuln-targets` | dvwa + juice-shop + webgoat + crapi | 6 GB |
| `ctf-ready` | vuln-targets + ctfd + dns + portal | 6 GB |
| `blue-team` | wazuh + suricata + dns | 12 GB |
| `incident-response` | blue-team + thehive | 16 GB |
| `full-lab` | Todo excepto thehive | 12 GB |

---

## Notas de Arquitectura

- **Patron de cada servicio:** `profiles + sidecar init + DNS dinamico + .env`
- **Sidecars son idempotentes:** siempre verifican si el recurso existe antes de crearlo (igual que `configure_gophish.sh`)
- **`services/lib/common.sh`:** biblioteca compartida de funciones para todos los init scripts (wait_for_api, check_exists, log_info/error)
- **BD internas:** MariaDB y Elasticsearch no exponen puertos al host
- **Wazuh:** Requiere `/var/run/docker.sock` en el manager (documentar implicaciones de seguridad)
- **Suricata:** Requiere `NET_ADMIN` + `NET_RAW` capabilities para monitorear el bridge Docker
- **TheHive:** Requiere `vm.max_map_count=262144` en el host (el script debe verificar y advertir)
- **Versionado:** v2.0 = Fase 1+2 completas, v2.1 = Fase 3, v2.2 = Fase 4, v2.3 = Fase 5

---

## Plan 3 — Portal + Reglas + Contenido (completado 2026-04-27)

- [x] Portal rediseñado con secciones ATAQUE / DEFENSA / INFRAESTRUCTURA / APRENDIZAJE
- [x] CTAs en el portal: "Sigue un escenario" (→ Docs) y "Explora libremente" (→ scroll)
- [x] Reglas Wazuh educativas para la API (100060-100065) con descripciones en español
- [x] Reglas Suricata para endpoints de la API (SIDs 9000060-9000063)
- [x] MkDocs: 3 escenarios guiados (Phishing, API Security, Web Hacking)
- [x] MkDocs: 6 páginas de servicio (DVWA, Juice Shop, API, Wazuh, GoPhish, Mail)
- [x] MkDocs: 4 cheat sheets (curl, nmap, Burp Suite, Wazuh)
- [x] README actualizado con todos los servicios actuales (API, Wazuh, Suricata, Docs)
