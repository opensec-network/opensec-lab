# CLAUDE.md — opensec-lab-v1

Contexto y convenciones para trabajar en este repositorio.

---

## Qué es este proyecto

**OpenSec Lab v1** es la versión consolidada del laboratorio de ciberseguridad OSN.
Reemplaza la cadena de repos independientes (`opensec-lab`, `opsn-mail`, `opsn-dns`, etc.)
con un monorepo con un instalador tipo una línea.

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
│   ├── dns/configure_dns.sh
│   ├── mail/               # Dockerfile + entrypoint + configs parametrizadas
│   ├── desktop/            # init.sh + custom-init.sh + wallpaper
│   └── gophish/            # configure_gophish.sh + templates HTML
├── .github/workflows/
│   ├── build-mail.yml      # Push de opensecnetwork/mail:multi-arch al tocar services/mail/
│   └── release.yml         # Empaqueta tarballs + crea GitHub Release en git tag v*
└── Makefile                # make release / make validate
```

---

## Arquitectura de red

| IP           | Contenedor       | Puerto(s) host              | Propósito                   |
|--------------|------------------|-----------------------------|-----------------------------|
| 172.18.0.2   | opsn-dns         | 5380, 53/udp, 53/tcp        | DNS (Technitium)            |
| 172.18.0.3   | opsn-dvwa        | 8080                        | DVWA (app vulnerable)       |
| 172.18.0.4   | opsn-juice-shop  | 3000                        | OWASP Juice Shop            |
| 172.18.0.5   | opsn-gophish     | 3333, 80                    | GoPhish                     |
| 172.18.0.6   | opsn-desktop     | 3100, 3101                  | Escritorio XFCE (Webtop)    |
| 172.18.0.7   | opsn-mail        | 25, 143, 587, 8888→80       | Mail + Roundcube webmail    |

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
- `dvwa` / `juice-shop` → independientes

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
docker exec opsn-desktop nslookup gophish.opensec.lab 172.18.0.2

# Probar SMTP interno
docker exec opsn-desktop nc -zv 172.18.0.7 25
```

---

## Pendiente

- Publicar `opensecnetwork/mail:multi-arch` → cambiar `build:` por `image:` en compose
- Registrar dominio `opensec.network` y apuntar `lab.opensec.network/install` → `opensec-lab.sh` del último release
- Comprimir `services/desktop/opsn-background.jpg` a < 1 MB (actualmente ~15 MB) o usar Git LFS
- Agregar `make validate` al CI (lint en cada PR)
