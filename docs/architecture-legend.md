# OpenSec Lab — Referencia de Arquitectura

Complemento de `architecture.svg` / `architecture.png`.

---

## Contenedores por Tier

### TIER 0 — Core Lab (4 servicios)
| Contenedor | Imagen | Puerto(s) Host | Notas |
|---|---|---|---|
| `opsn-dns` | technitium/dns-server:latest | 5380 (UI), 53 UDP/TCP | Resuelve `*.opensec.lab` en toda la red |
| `opsn-mail` | build local | 25, 143, 587, 8888→80 | Postfix + Dovecot + Roundcube |
| `opsn-gophish` | opensecnetwork/gophish:multi-arch | 3333 (admin), 80 (phishing) | `gophish-volume-init` + `gophish-init` como sidecars |
| `opsn-desktop` | lscr.io/linuxserver/webtop:ubuntu-xfce | 3100 (HTTP), 3101 (HTTPS) | Thunderbird preconfigurado. Monta `docker.sock:ro` |

### TIER 1 — Vulnerable Targets (5 contenedores)
| Contenedor | Imagen | Puerto(s) Host | Notas |
|---|---|---|---|
| `opsn-dvwa` | ghcr.io/digininja/dvwa:latest | 8080 | App vulnerable clásica. Depende de `opsn-dvwa-db` |
| `opsn-dvwa-db` | mariadb:10.11 | — (interno) | Base de datos de DVWA |
| `opsn-juice-shop` | bkimminich/juice-shop:latest | 3000 | OWASP Juice Shop |
| `opsn-webgoat` | webgoat/webgoat:latest | 8081 | Aprendizaje guiado OWASP |
| `opsn-api` | build local (Flask) | 8025 | API vulnerable OWASP API Top 10. Escribe logs a `opsn_api_logs` |

### TIER 2 — Aprendizaje (5 contenedores)
| Contenedor | Imagen | Puerto(s) Host | Notas |
|---|---|---|---|
| `opsn-gitea` | gitea/gitea:latest | 3002 (HTTP), 2222 (SSH) | SQLite, auto-inicializado |
| `opsn-gitea-init` | alpine/curl:latest | — (efímero) | Seed de repos vulnerables vía API |
| `opsn-portal-init` | alpine:latest | — (efímero) | Genera HTML con `envsubst` |
| `opsn-portal` | nginx:alpine | 8443 | Dashboard de accesos del lab |
| `opsn-docs-build` | squidfunk/mkdocs-material:9.5 | — (efímero) | Compila la documentación MkDocs al volumen `opsn_docs_html` |
| `opsn-docs` | nginx:alpine | 4000 | Sirve la documentación compilada |

### TIER 3 — Blue Team (6 contenedores, 12+ GB RAM)
| Contenedor | Imagen | Puerto(s) Host | Notas |
|---|---|---|---|
| `opsn-wazuh-certs` | wazuh/wazuh-certs-generator:0.0.2 | — (efímero) | Genera certs SSL para todo el stack. Vol: `opsn_wazuh_certs` |
| `opsn-wazuh-indexer` | wazuh/wazuh-indexer:4.9.0 | 9200 (interno) | OpenSearch. RAM: ~1 GB (configurable) |
| `opsn-wazuh-manager` | wazuh/wazuh-manager:4.9.0 | 1514, 1515, 55000 | Monta `docker.sock:ro` + consume `opsn_suricata_logs` + `opsn_api_logs` |
| `opsn-wazuh-dashboard` | wazuh/wazuh-dashboard:4.9.0 | 5601 | Kibana-like UI |
| `opsn-wazuh-init` | docker:cli | — (efímero) | Valida la API y configura el stack tras el arranque. Monta `docker.sock:ro` |
| `opsn-suricata` | jasonish/suricata:latest | — (`network_mode: host`) | IDS. Escribe `eve.json` al vol compartido `opsn_suricata_logs` |

---

## Red Docker

| Parámetro | Valor |
|---|---|
| Nombre | `openseclab` |
| Driver | bridge (externa, creada por el instalador antes del `docker compose up`) |
| Subnet | Asignada dinámicamente por Docker (no hay IPs estáticas fijas en el compose) |
| DNS interno | Todos los contenedores se resuelven por hostname/container_name |

> Los servicios se comunican entre sí por nombre de contenedor (p. ej. `opsn-mail`, `opsn-wazuh-dashboard`).
> Las IPs reales son asignadas por Docker en cada arranque; `configure_dns.sh` las resuelve dinámicamente
> con `getent hosts` antes de registrarlas en Technitium.

---

## DNS Records (`*.opensec.lab`)

Los registros se crean dinámicamente por `services/dns/configure_dns.sh` al arrancar `opsn-dns`.
Las IPs se resuelven en tiempo de ejecución — no son valores fijos.

| Registro | Tipo | Destino (nombre de contenedor) |
|---|---|---|
| `dns.opensec.lab` | A | `opsn-dns` |
| `mail.opensec.lab` | A | `opsn-mail` (solo si el perfil `mail` está activo) |
| `webmail.opensec.lab` | A | `opsn-mail` (solo si el perfil `mail` está activo) |
| `opensec.lab` | MX | `mail.opensec.lab` (priority 10) |
| `gophish.opensec.lab` | A | `opsn-gophish` (solo si el perfil `gophish` está activo) |
| `webgoat.opensec.lab` | A | `opsn-webgoat` (solo si el perfil `webgoat` está activo) |
| `git.opensec.lab` | A | `opsn-gitea` (solo si el perfil `gitea` está activo) |
| `lab.opensec.lab` | A | `opsn-portal` (solo si el perfil `portal` está activo) |
| `wazuh.opensec.lab` | A | `opsn-wazuh-dashboard` (solo si el perfil `wazuh` está activo) |
| `api.opensec.lab` | A | `opsn-api` (solo si el perfil `api` está activo) |
| `docs.opensec.lab` | A | `opsn-docs` (solo si el perfil `docs` está activo) |

---

## Volúmenes Compartidos Clave

| Volumen | Productor | Consumidor | Propósito |
|---|---|---|---|
| `opsn_wazuh_certs` | wazuh-certs (write) | indexer, manager, dashboard (read) | Certificados SSL del stack Wazuh |
| `opsn_suricata_logs` | Suricata (write `eve.json`) | Wazuh Manager (read vía localfile) | Alertas IDS → SIEM |
| `opsn_api_logs` | opsn-api (write `api.log`) | Wazuh Manager (read vía localfile) | Logs de API → SIEM |
| `opsn_portal_html` | portal-init (write) | portal/nginx (read-only) | HTML generado del dashboard |
| `opsn_docs_html` | docs-build (write) | docs/nginx (read-only) | Documentación MkDocs compilada |
| `opsn_gophish_data` | gophish-volume-init → gophish | gophish-init (read) | Datos y DB de GoPhish |

---

## Accesos que Montan `docker.sock`

| Contenedor | Modo | Propósito |
|---|---|---|
| `opsn-desktop` | `:ro` | Permite al escritorio inspeccionar contenedores del lab |
| `opsn-wazuh-manager` | `:ro` | `wodle docker-listener` — monitoreo de eventos Docker |
| `opsn-wazuh-init` | `:ro` | Ejecuta comandos de configuración en indexer y manager |

---

## Profiles Docker Compose

| Profile | Contenedores incluidos |
|---|---|
| `dns` | opsn-dns |
| `mail` | opsn-mail |
| `gophish` | opsn-gophish + gophish-volume-init + gophish-init |
| `desktop` | opsn-desktop |
| `dvwa` | opsn-dvwa + opsn-dvwa-db |
| `juice-shop` | opsn-juice-shop |
| `webgoat` | opsn-webgoat |
| `api` | opsn-api |
| `gitea` | opsn-gitea + gitea-init |
| `docs` | opsn-docs-build + opsn-docs |
| `portal` | opsn-portal + portal-init |
| `wazuh` | opsn-wazuh-certs + indexer + manager + dashboard + init |
| `suricata` | opsn-suricata |
| `blue-team` | wazuh + suricata (meta-profile) |
| `all` | Todos los anteriores |
