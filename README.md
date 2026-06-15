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
| DVWA | `admin` | `admin` | http://localhost:8080 |
| Juice Shop | — | (es un reto) | http://localhost:3000 |
| API — alice | `alice` | `alice123` | http://localhost:8025 |
| API — admin | `admin` | `admin_secret` | http://localhost:8025 |
| GoPhish | `admin` | *(auto-generada — ver logs)* | https://localhost:3333 |
| Desktop | `abc` | `abc` | http://localhost:3100 |
| DNS | `admin` | `Password` | http://localhost:5380 |
| Mail / Roundcube | `admin` | `Password` | http://localhost:8888 |
| Wazuh | `admin` | `admin` | https://localhost:5601 |
| Docs | — | — | http://localhost:4000 |

Para ver la contraseña de GoPhish después de instalar:
```bash
docker logs opsn-gophish 2>&1 | grep "Please login"
```

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

```
openseclab (172.18.0.0/16)
├── 172.18.0.2  opsn-dns          Technitium DNS (resuelve *.opensec.lab)
├── 172.18.0.3  opsn-dvwa         DVWA :8080
├── 172.18.0.4  opsn-juice-shop   Juice Shop :3000
├── 172.18.0.5  opsn-gophish      GoPhish :3333/:80
├── 172.18.0.6  opsn-desktop      XFCE con Thunderbird :3100
├── 172.18.0.7  opsn-mail         Postfix + Roundcube :8888
├── 172.18.0.8  opsn-api          API vulnerable (Flask) :8025
├── 172.18.0.9  opsn-wazuh        Wazuh SIEM :5601
├── 172.18.0.10 opsn-suricata     Suricata IDS (pasivo)
└── (dinámica)  opsn-docs         MkDocs :4000
```

> **Nota sobre las IPs:** son ilustrativas. El `docker-compose.yml` actual **no asigna IPs
> estáticas** — Docker las asigna dinámicamente dentro de la subred `172.18.0.0/16`. Los
> servicios se localizan entre sí por nombre DNS (`*.opensec.lab`), no por IP fija. El diagrama
> tampoco incluye WebGoat (8081) ni Gitea (3002), que también forman parte del catálogo.

Zona DNS `opensec.lab` configurada automáticamente:

| Registro | Nombre | Valor |
|----------|--------|-------|
| A | `mail.opensec.lab` | 172.18.0.7 |
| A | `webmail.opensec.lab` | 172.18.0.7 |
| A | `gophish.opensec.lab` | 172.18.0.5 |
| A | `api.opensec.lab` | 172.18.0.8 |
| A | `docs.opensec.lab` | (resuelta dinámicamente por Docker) |
| MX | `opensec.lab` | `mail.opensec.lab` |

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
