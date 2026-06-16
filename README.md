# OpenSec Lab

Laboratorio de ciberseguridad basado en Docker: practica ataques reales (web, API, phishing) y aprende a **detectarlos** en un SIEM real. Instala solo lo que necesitas, con un comando.

**Experiencia insignia:** el taller *API Breach to Detection* — explotas fallas de API (BOLA, mass assignment, broken function auth) y luego investigas la evidencia en Wazuh. Atacar y defender en un mismo loop.

---

## Instalación

```bash
/bin/bash -c "$(curl -fsSL https://lab.opensec.network/install)"
```

**Requisitos:** Docker, 6 GB RAM, 20 GB disco libre. Compatible con AMD64 y ARM64 (Kali Linux, Ubuntu).

El script detecta si ya tienes una instalación y muestra el menú de gestión en lugar del de instalación.

---

## Servicios disponibles

| # | Servicio | Descripción | Puerto(s) |
|---|----------|-------------|-----------|
| 1 | **DVWA** | Damn Vulnerable Web Application | 8080 |
| 2 | **Juice Shop** | OWASP Juice Shop — 100+ retos | 3000 |
| 3 | **WebGoat** | Plataforma de aprendizaje guiado OWASP | 8081 |
| 4 | **API Vulnerable** | API REST con OWASP API Security Top 10 (Flask) | 8025 |
| 5 | **GoPhish** | Framework de phishing con campaña pre-configurada | 3333, 80 |
| 6 | **Desktop** | Escritorio XFCE con Thunderbird pre-configurado | 3100 |
| 7 | **DNS** | Servidor DNS Technitium para la zona `opensec.lab` | 5380 |
| 8 | **Mail** | Servidor de correo + Roundcube webmail | 8888 |
| 9 | **Gitea** | Repos con código vulnerable para análisis estático | 3002, 2222 |
| 10 | **Wazuh + Suricata** | SIEM + IDS (Blue Team) — detecta los ataques del lab en tiempo real. Suricata (IDS pasivo) se instala junto con Wazuh. | 5601 |
| 11 | **Portal** | Panel de inicio con acceso a todos los servicios | 8443 |
| 12 | **Docs** | Documentación y escenarios guiados (MkDocs) | 4000 |

> GoPhish requiere DNS y Mail. Wazuh requiere DNS. Desktop y Mail requieren DNS. Gitea, DVWA, Juice Shop y WebGoat son independientes.

---

## Credenciales por defecto

| Servicio | Usuario | Contraseña | URL |
|----------|---------|------------|-----|
| DVWA | `admin` | `password` | http://localhost:8080 |
| Juice Shop | — | (es un reto) | http://localhost:3000 |
| API — alice | `alice` | `alice123` | http://localhost:8025 |
| API — admin | `admin` | `admin_secret` | http://localhost:8025 |
| GoPhish | `admin` | `Password` | https://localhost:3333 |
| Desktop | `abc` | `abc` | http://localhost:3100 |
| DNS | `admin` | `Password` | http://localhost:5380 |
| Mail / Roundcube | `admin` | `Password` | http://localhost:8888 |
| Wazuh | `admin` | `admin` | https://localhost:5601 |
| Docs | — | — | http://localhost:4000 |

La contraseña de GoPhish la fija el sidecar `configure_gophish.sh` a partir de
`OPSN_GOPHISH_PASSWORD` (por defecto `Password`). Cámbiala en `.env` antes de instalar si lo deseas.

---

## GoPhish — campaña pre-configurada

Al instalar GoPhish, el script `configure_gophish.sh` configura automáticamente:

- **Sending Profile** → SMTP apuntando a `opsn-mail` (integración interna)
- **Email Template** → Email de phishing "contraseña expirada"
- **Landing Page** → Portal corporativo falso con captura de credenciales
- **User Group** → `admin@opensec.lab`, `user@opensec.lab`
- **Campaign** → Pre-armada, lista para lanzar desde la interfaz

Accede a `https://localhost:3333`, ve a **Campaigns** y haz clic en **Launch Campaign**.

---

## Gestión del lab

Después de la instalación, el mismo script sirve para gestionar el lab:

```bash
~/OpenSec_Lab/opensec-lab.sh
```

Opciones disponibles:
- Instalar más servicios
- Eliminar servicios
- Reinstalar servicios (sin borrar datos)
- Borrar todo el lab
- Actualizar definiciones (descarga compose y .env más recientes)

---

## Arquitectura

Red Docker: `openseclab` — subred `172.18.0.0/16`. Las IPs son dinámicas (Docker las asigna
automáticamente); los servicios se localizan entre sí por nombre DNS (`*.opensec.lab`), no por IP fija.

| Contenedor | Puerto(s) host | Propósito |
|---|---|---|
| `opsn-dns` | 5380, 53/udp, 53/tcp | Technitium DNS — zona `opensec.lab` |
| `opsn-dvwa` | 8080 | DVWA |
| `opsn-juice-shop` | 3000 | Juice Shop |
| `opsn-webgoat` | 8081 | WebGoat |
| `opsn-api` | 8025 | API vulnerable (Flask) |
| `opsn-gophish` | 3333, 80 | GoPhish |
| `opsn-desktop` | 3100, 3101 | Escritorio XFCE con Thunderbird |
| `opsn-mail` | 25, 143, 587, 8888→80 | Postfix + Roundcube webmail |
| `opsn-gitea` | 3002, 2222 | Gitea — repos con código vulnerable |
| `opsn-wazuh` | 5601, 55000 | Wazuh SIEM |
| `opsn-suricata` | — | Suricata IDS (pasivo, junto a Wazuh) |
| `opsn-portal` | 8443 | Portal central |
| `opsn-docs` | 4000 | MkDocs — escenarios y talleres |

Zona DNS `opensec.lab` configurada automáticamente:

| Registro | Nombre | Valor |
|----------|--------|-------|
| A | `mail.opensec.lab` | IP dinámica de `opsn-mail` |
| A | `webmail.opensec.lab` | IP dinámica de `opsn-mail` |
| A | `gophish.opensec.lab` | IP dinámica de `opsn-gophish` |
| A | `api.opensec.lab` | IP dinámica de `opsn-api` |
| A | `docs.opensec.lab` | IP dinámica de `opsn-docs` |
| MX | `opensec.lab` | `mail.opensec.lab` |

> `configure_dns.sh` resuelve la IP de cada contenedor en tiempo de ejecución via la API de Technitium.

---

## Personalización

Copia `.env.example` como `.env` en el directorio del lab y ajusta los valores:

```bash
cp .env.example ~/OpenSec_Lab/.env
```

Variables disponibles: dominio, IPs, contraseñas, puertos, y parámetros de campaña de GoPhish.

---

## Licencia

[MIT](LICENSE)
