# OpenSec Lab — Referencia de Arquitectura

Complemento de `architecture.svg` / `architecture.png`.

---

## Contenedores por Tier

### TIER 0 — Core Lab (6 servicios)
| Contenedor | Imagen | Puerto(s) Host | Notas |
|---|---|---|---|
| `opsn-dns` | technitium/dns-server | 5380 (UI), 53 UDP/TCP | Resuelve `*.opensec.lab` en toda la red |
| `opsn-mail` | build local | 25, 143, 587, 8888→80 | Postfix + Dovecot + Roundcube |
| `opsn-gophish` | opensecnetwork/gophish:multi-arch | 3333 (admin), 80 (phishing) | `gophish-volume-init` + `gophish-init` como sidecars |
| `opsn-desktop` | linuxserver/webtop:ubuntu-xfce | 3100 (HTTP), 3101 (HTTPS) | Thunderbird preconfigurado. Monta `docker.sock` |
| `opsn-dvwa` | ghcr.io/digininja/dvwa | 8080 | App vulnerable clásica |
| `opsn-juice-shop` | bkimminich/juice-shop | 3000 | OWASP Juice Shop |

### TIER 1 — Vulnerable Targets (9 contenedores)
| Contenedor | Imagen | Puerto(s) Host | Notas |
|---|---|---|---|
| `opsn-webgoat` | webgoat/webgoat | 8081 | Aprendizaje guiado OWASP |
| `opsn-crapi` | crapi/crapi-web | 8025 | Frontend React + nginx proxy — punto de entrada al cluster crAPI |
| `opsn-crapi-identity` | crapi/crapi-identity | — (interno) | Depende de mongo + postgres + mailhog |
| `opsn-crapi-community` | crapi/crapi-community | — (interno) | Depende de mongo + identity |
| `opsn-crapi-workshop` | crapi/crapi-workshop | — (interno) | Depende de postgres + identity |
| `opsn-crapi-mongo` | mongo:4.4 | — (interno) | Vol: `opsn_crapi_data` |
| `opsn-crapi-postgres` | postgres:14-alpine | — (interno) | Vol: `opsn_crapi_postgres` |
| `opsn-crapi-mailhog` | crapi/mailhog | — (interno) | SMTP interno para crAPI |
| `opsn-portainer` | portainer/portainer-ce | 9443 HTTPS | Monta `docker.sock` (read-only) |

### TIER 2 — Aprendizaje (9 contenedores)
| Contenedor | Imagen | Puerto(s) Host | Notas |
|---|---|---|---|
| `opsn-wiki` | linuxserver/bookstack | 6875 | Depende de wiki-db (healthcheck) |
| `opsn-wiki-db` | mariadb:10.11 | — (interno) | Vol: `opsn_wiki_db` |
| `opsn-wiki-init` | alpine/curl | — (efímero) | Seed de guías via API BookStack |
| `opsn-gitea` | gitea/gitea | 3002 (HTTP), 2222 (SSH) | SQLite, auto-inicializado |
| `opsn-gitea-init` | alpine/curl | — (efímero) | Seed de repos vulnerables via API |
| `opsn-portal` | nginx:alpine | 8443 | Dashboard de accesos del lab |
| `opsn-portal-init` | alpine | — (efímero) | Genera HTML con `envsubst` |

### TIER 3 — Blue Team (6 contenedores, 12+ GB RAM)
| Contenedor | Imagen | Puerto(s) Host | Notas |
|---|---|---|---|
| `opsn-wazuh-certs` | wazuh/wazuh-certs-generator:0.0.2 | — (efímero) | Genera certs SSL para todo el stack. Vol: `opsn_wazuh_certs` |
| `opsn-wazuh-indexer` | wazuh/wazuh-indexer:4.9.0 | 9200 (interno) | OpenSearch. RAM: ~1.5 GB |
| `opsn-wazuh-manager` | wazuh/wazuh-manager:4.9.0 | 1514, 1515, 55000 | Monta `docker.sock` + `suricata_logs` vol |
| `opsn-wazuh-dashboard` | wazuh/wazuh-dashboard:4.9.0 | 5601 | Kibana-like UI |
| `opsn-wazuh-init` | alpine/curl | — (efímero) | Valida la API tras el arranque |
| `opsn-suricata` | jasonish/suricata | — (`network_mode: host`) | IDS. Escribe `eve.json` al vol compartido |

---

## Red Docker

| Parámetro | Valor |
|---|---|
| Nombre | `openseclab` |
| Driver | bridge (externa, creada manualmente) |
| Subnet | `172.18.0.0/16` |
| DNS interno | Todos los contenedores se resuelven por hostname |

---

## DNS Records (`*.opensec.lab`)

| Registro | Tipo | Destino |
|---|---|---|
| `dns.opensec.lab` | A | `opsn-dns` |
| `mail.opensec.lab` | A | `opsn-mail` |
| `webmail.opensec.lab` | A | `opsn-mail` |
| `opensec.lab` | MX | `mail.opensec.lab` (priority 10) |
| `gophish.opensec.lab` | A | `opsn-gophish` |
| `webgoat.opensec.lab` | A | `opsn-webgoat` |
| `crapi.opensec.lab` | A | `opsn-crapi` |
| `portainer.opensec.lab` | A | `opsn-portainer` |
| `wiki.opensec.lab` | A | `opsn-wiki` |
| `git.opensec.lab` | A | `opsn-gitea` |
| `lab.opensec.lab` | A | `opsn-portal` |
| `wazuh.opensec.lab` | A | `opsn-wazuh-dashboard` |

---

## Volúmenes Compartidos Clave

| Volumen | Productor | Consumidor | Propósito |
|---|---|---|---|
| `opsn_wazuh_certs` | wazuh-certs (write) | indexer, manager, dashboard (read) | Certificados SSL del stack Wazuh |
| `opsn_suricata_logs` | Suricata (write `eve.json`) | Wazuh Manager (read via localfile) | Alertas IDS → SIEM |
| `opsn_portal_html` | portal-init (write) | portal/nginx (read-only) | HTML generado del dashboard |
| `opsn_gophish_data` | gophish-volume-init → gophish | gophish-init (read) | Datos y DB de GoPhish |

---

## Accesos que Montan `docker.sock`

| Contenedor | Modo | Propósito |
|---|---|---|
| `opsn-desktop` | `:ro` | Thunderbird/KDE puede inspeccionar contenedores |
| `opsn-portainer` | `:ro` | UI de gestión Docker |
| `opsn-wazuh-manager` | `:rw` | `wodle docker-listener` — monitoreo de eventos Docker |

---

## Profiles Docker Compose

| Profile | Contenedores incluidos |
|---|---|
| `dns` | opsn-dns |
| `mail` | opsn-mail |
| `gophish` | opsn-gophish + gophish-volume-init + gophish-init |
| `desktop` | opsn-desktop |
| `dvwa` | opsn-dvwa |
| `juice-shop` | opsn-juice-shop |
| `webgoat` | opsn-webgoat |
| `crapi` | opsn-crapi + 6 sub-contenedores |
| `portainer` | opsn-portainer |
| `wiki` | opsn-wiki + wiki-db + wiki-init |
| `gitea` | opsn-gitea + gitea-init |
| `portal` | opsn-portal + portal-init |
| `wazuh` | 5 contenedores Wazuh |
| `suricata` | opsn-suricata |
| `blue-team` | wazuh + suricata (meta-profile) |
| `all` | Todos los anteriores |
