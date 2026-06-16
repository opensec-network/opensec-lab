# OpenSec Lab — Roadmap

> Última actualización: 2026-06-15

---

## Producto actual

**OpenSec Lab** es un laboratorio de ciberseguridad basado en Docker centrado en el loop
ataque→detección. La experiencia insignia es el taller *API Breach to Detection*: explotar
fallas de API (BOLA, mass assignment, broken function auth) y detectar la evidencia en Wazuh
SIEM en tiempo real.

### Servicios instalables hoy (12 + Suricata)

| Servicio | Clave | Puerto(s) host | Notas |
|----------|-------|----------------|-------|
| DNS (Technitium) | `dns` | 5380, 53 | Prerequisito de mail, gophish, desktop, wazuh |
| Mail + Roundcube | `mail` | 25, 143, 587, 8888 | Prerequisito de gophish |
| GoPhish | `gophish` | 3333, 80 | Campaña Acme Corp pre-configurada |
| Desktop XFCE | `desktop` | 3100, 3101 | Thunderbird pre-configurado |
| DVWA | `dvwa` | 8080 | Independiente |
| Juice Shop | `juice-shop` | 3000 | Independiente |
| WebGoat | `webgoat` | 8081 | Independiente |
| API vulnerable (Flask) | `api` | 8025 | OWASP API Top 10 — taller API Breach |
| Gitea | `gitea` | 3002, 2222 | Repos con código vulnerable |
| Docs (MkDocs) | `docs` | 4000 | Escenarios y talleres guiados |
| Portal central | `portal` | 8443 | Dashboard con acceso a todos los servicios |
| Wazuh SIEM + Suricata IDS | `wazuh` | 5601, 55000 | Blue Team — 8+ GB RAM requeridos |

> Suricata se despliega junto con Wazuh. No es un servicio seleccionable de forma independiente.

### Talleres disponibles

| Taller | Estado | Descripción |
|--------|--------|-------------|
| API Breach to Detection | Listo | Explotar BOLA / mass assignment / broken auth en la API → detectar en Wazuh |
| Web Hacking | Listo | SQLi / XSS / command injection en DVWA y Juice Shop |
| Phishing End-to-End | En diseño | GoPhish → víctima en Desktop → alerta en Wazuh |
| Kill Chain Completo | En diseño | Reconocimiento → explotación → persistencia → detección |

### Credenciales por defecto

| Servicio | Usuario | Contraseña |
|----------|---------|------------|
| DVWA | `admin` | `password` |
| DNS / Mail | `admin` | `Password` |
| Desktop | `abc` | `abc` |
| Gitea | `admin` | `Password` |
| API (alice) | `alice` | `alice123` |
| API (admin) | `admin` | `admin_secret` |
| Wazuh | `admin` | `admin` |
| GoPhish | `admin` | *(auto-generada — ver logs)* |

---

## Pendiente

### Infraestructura y distribución

- [ ] Publicar release v3.0 en GitHub con todos los tarballs y `docker-compose.yml`
- [ ] Publicar `opensecnetwork/mail:multi-arch` → cambiar `build:` por `image:` en compose
- [ ] Publicar `opensecnetwork/api:multi-arch` → cambiar `build:` por `image:` en compose
- [ ] Registrar dominio `opensec.network` y apuntar `lab.opensec.network/install` al release
- [ ] Validar todos los servicios en AMD64 (plataforma primaria)
- [ ] Validar en ARM64 con advertencias donde corresponda

### Talleres

- [ ] Taller: Phishing End-to-End (GoPhish → Desktop → Wazuh)
- [ ] Taller: Kill Chain Completo
- [ ] Guía de instructor para Web Hacking (equivalente a la de API Breach)

### Calidad y UX

- [ ] Smoke tests en AMD64 con todos los servicios activos
- [ ] Bookmarks de cheat sheets pre-instalados en el navegador del Desktop

---

## Historial

- **v3.0 (en preparación):** 12 servicios instalables, ruta de talleres ataque→detección,
  dashboards Wazuh auto-importados, portal rediseñado (tema claro, estilo Wazuh), taller
  Web Hacking completo, CI con `make validate` en cada PR.
- **Hubo una visión llamada "Expansión v2"** (registrada en commits anteriores) que contemplaba
  CTFd, BookStack, crAPI y Portainer. Esa dirección fue descartada a favor de profundidad sobre
  el motor existente: mejor loop ataque→detección, más talleres, Wazuh integrado.
  Ninguno de esos servicios existe en el código actual.
