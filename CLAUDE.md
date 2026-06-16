# CLAUDE.md — opensec-lab-v1

Contexto y convenciones para trabajar en este repositorio.

---

## Qué es este proyecto

**OpenSec Lab v1** es la versión consolidada del laboratorio de ciberseguridad OSN.
Reemplaza la cadena de repos independientes (`opensec-lab`, `opsn-mail`, `opsn-dns`, etc.)
con un monorepo con un instalador tipo una línea.

- **Identidad del producto:** lab de ciberseguridad centrado en el loop ataque→detección. La experiencia insignia es el taller "API Breach to Detection" (explotar fallas de API y detectarlas en Wazuh). No es solo un lab de phishing.
- **Dirección del producto:** ver `docs/product-direction/` para decisiones y visión aprobadas.
- **Audiencia:** Kali Linux (ARM64 / AMD64), mínimo 6 GB RAM, 20 GB disco
- **Instalación:** `/bin/bash -c "$(curl -fsSL https://lab.opensec.network/install)"`
- **GitHub:** `https://github.com/opensec-network/opensec-lab`

---

## Estructura

```
opensec-lab-v1/
├── opensec-lab.sh          # Script único: instala y gestiona el lab
├── docker-compose.yml      # Estático — contiene TODOS los servicios con profiles
├── .env.example            # Template de configuración
├── config/
│   └── defaults.env        # Valores por defecto (IPs, passwords, puertos, dominio)
├── services/
│   ├── lib/common.sh       # Helpers compartidos entre init scripts
│   ├── dns/configure_dns.sh
│   ├── mail/               # Dockerfile + entrypoint + configs parametrizadas
│   ├── desktop/            # init.sh + custom-init.sh + wallpaper
│   ├── gophish/            # configure_gophish.sh + templates HTML
│   ├── gitea/              # configure_gitea.sh (repos con código vulnerable)
│   ├── api/                # Dockerfile + app.py (API REST vulnerable, Flask)
│   ├── wazuh/              # rules/openseclab.xml (reglas SIEM para el lab)
│   ├── suricata/           # rules/openseclab.rules (reglas IDS para el lab)
│   ├── portal/             # generate_portal.sh + nginx.conf
│   └── docs/               # mkdocs.yml + docs/ (escenarios, talleres, cheatsheets)
├── docs/
│   └── product-direction/  # Visión del producto y decisiones de dirección
├── .github/workflows/
│   ├── build-mail.yml      # Push de opensecnetwork/mail:multi-arch al tocar services/mail/
│   └── release.yml         # Empaqueta tarballs + crea GitHub Release en git tag v*
└── Makefile                # make release / make validate / make test-static
```

---

## Arquitectura de red

Las IPs son ilustrativas — el compose actual asigna IPs dinámicamente dentro de `172.18.0.0/16`. Los servicios se localizan por nombre DNS (`*.opensec.lab`), no por IP fija.

| Contenedor       | Puerto(s) host              | Propósito                              |
|------------------|-----------------------------|----------------------------------------|
| opsn-dns         | 5380, 53/udp, 53/tcp        | DNS (Technitium) — zona opensec.lab    |
| opsn-dvwa        | 8080                        | DVWA (app vulnerable)                  |
| opsn-juice-shop  | 3000                        | OWASP Juice Shop                       |
| opsn-webgoat     | 8081                        | WebGoat (aprendizaje guiado OWASP)     |
| opsn-api         | 8025                        | API REST vulnerable (Flask)            |
| opsn-gophish     | 3333, 80                    | GoPhish                                |
| opsn-desktop     | 3100, 3101                  | Escritorio XFCE (Webtop)              |
| opsn-mail        | 25, 143, 587, 8888→80       | Mail + Roundcube webmail               |
| opsn-gitea       | 3002, 2222                  | Repos con código vulnerable            |
| opsn-wazuh       | 5601                        | Wazuh SIEM (Blue Team)                 |
| opsn-suricata    | —                           | Suricata IDS (pasivo, junto a Wazuh)   |
| opsn-portal      | 8443                        | Panel de inicio con acceso a servicios |
| opsn-docs        | 4000                        | MkDocs con escenarios y talleres       |

---

## Cómo funciona el script

### Primera instalación
```
opensec-lab.sh
  → Verifica Docker + puerto 53
  → Descarga docker-compose.yml + defaults.env desde GitHub Release
  → Menú: seleccionar servicios
  → Para servicios con archivos: descarga opsn-<nombre>.tar.gz
  → Guarda selección en ~/OpenSec_Lab/.active_profiles
  → docker compose --profile <seleccionados> up -d
  → Muestra credenciales
```

### Ejecuciones posteriores
```
opensec-lab.sh
  → Lee ~/OpenSec_Lab/.active_profiles
  → Menú de gestión: agregar / eliminar / reinstalar / borrar todo
```

### .active_profiles
Archivo plano con un profile por línea. Los profiles coinciden con los nombres de servicios:
```
dns
gophish
mail
```

### Dependencias automáticas
- `gophish` → agrega `dns` + `mail`
- `desktop` → agrega `dns`
- `mail` → agrega `dns`
- `wazuh` → agrega `dns`
- `dvwa` / `juice-shop` / `webgoat` / `api` / `gitea` / `portal` / `docs` → independientes

---

## Assets en GitHub Releases

Cada release (`v*`) publica:
```
opensec-lab.sh
docker-compose.yml
defaults.env
opsn-dns.tar.gz
opsn-mail.tar.gz
opsn-desktop.tar.gz
opsn-gophish.tar.gz
opsn-gitea.tar.gz
opsn-portal.tar.gz
opsn-api.tar.gz
opsn-docs.tar.gz
checksums.sha256
```

El script siempre descarga de un release tagueado (`RELEASE_TAG` en `opensec-lab.sh`),
nunca de `refs/heads/main` (evita dependencia de HEAD).

---

## Convenciones

### Shell
- Scripts con `#!/usr/bin/env bash` (excepto `configure_gophish.sh` que usa `#!/bin/sh` por la imagen Alpine)
- Variables de entorno: `OPSN_*` (prefijo consistente)
- Fallbacks con `${VAR:-default}` en todos los scripts de servicio
- Sin `set -e` en el script principal (manejo explícito de errores); sí en scripts de servicio

### docker-compose.yml
- Archivo **estático** — nunca se modifica en tiempo de ejecución
- Todo servicio tiene `profiles: ["<nombre>", "all"]`
- Todas las variables referencian `.env` (cargado automáticamente por docker compose)
- `opsn-mail` usa `build: ./services/mail` hasta publicar la imagen; luego cambiar a `image:`

### config/defaults.env
- Fuente de verdad para IPs, passwords, puertos
- Se copia como `.env` al directorio del lab (`~/OpenSec_Lab/.env`)
- Los scripts de servicio también leen estas variables vía `env_file` en el compose

---

## Comandos útiles

```bash
# Validar compose y sintaxis del script
make validate

# Generar tarballs de release localmente
make release

# Ver logs del sidecar de GoPhish
docker logs opsn-gophish-init

# Probar DNS desde el desktop
docker exec opsn-desktop nslookup gophish.opensec.lab

# Probar SMTP interno
docker exec opsn-desktop nc -zv mail.opensec.lab 25
```

---

## Pendiente

- Publicar `opensecnetwork/mail:multi-arch` → cambiar `build:` por `image:` en compose
- Publicar `opensecnetwork/api:multi-arch` para eliminar el `build:` local de `opsn-api`
- Registrar dominio `opensec.network` y apuntar `lab.opensec.network/install` → `opensec-lab.sh` del último release
- Publicar release v3.0 en GitHub con todos los tarballs y el `docker-compose.yml`
- Verificar la ruta en AMD64/Kali (todo se probó en macOS/ARM); confirmar la elevación de las reglas Wazuh custom

## Ruta de talleres (completa)

Ruta de 4 talleres ataque→detección, cada uno con una habilidad de detección distinta:

1. **Web Hacking** (`workshops/web-hacking.md`) — firma de payload (Suricata)
2. **API Breach** (`workshops/api-breach.md`) — eventos estructurados de app (flagship)
3. **Phishing** (`workshops/phishing.md`) — comportamiento (credential harvesting, regla Suricata `9000070`)
4. **Kill Chain** (`workshops/kill-chain.md`) — correlación multi-señal (regla `9000050`)

Cada taller tiene guía de estudiante + instructor + `tests/<taller>-readiness.sh`.
