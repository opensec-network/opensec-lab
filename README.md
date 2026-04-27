# OpenSec Lab

Laboratorio de ciberseguridad basado en Docker para simulaciones de phishing y entrenamiento en seguridad web.

Instala solo los servicios que necesitas. Un script hace todo.

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
| 2 | **Juice Shop** | OWASP Juice Shop | 3000 |
| 3 | **GoPhish** | Framework de phishing con campaña pre-configurada | 3333, 80 |
| 4 | **Desktop** | Escritorio KDE con Thunderbird pre-configurado | 3100 |
| 5 | **DNS** | Servidor DNS Technitium para la zona `opensec.lab` | 5380 |
| 6 | **Mail** | Servidor de correo + Roundcube webmail | 8888 |

> GoPhish requiere DNS y Mail. Desktop y Mail requieren DNS. Se instalan automáticamente.

---

## Credenciales por defecto

| Servicio | Usuario | Contraseña | URL |
|----------|---------|------------|-----|
| DVWA | `admin` | `admin` | http://localhost:8080 |
| Juice Shop | — | (es un reto) | http://localhost:3000 |
| GoPhish | `admin` | *(auto-generada — ver logs)* | https://localhost:3333 |
| Desktop | `abc` | `abc` | http://localhost:3100 |
| DNS | `admin` | `Password` | http://localhost:5380 |
| Mail / Roundcube | `admin` | `Password` | http://localhost:8888 |

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
├── 172.18.0.2  opsn-dns       — Technitium DNS (resuelve *.opensec.lab)
├── 172.18.0.3  opsn-dvwa      — DVWA
├── 172.18.0.4  opsn-juice-shop — Juice Shop
├── 172.18.0.5  opsn-gophish   — GoPhish (phishing framework)
├── 172.18.0.6  opsn-desktop   — KDE Webtop con Thunderbird
└── 172.18.0.7  opsn-mail      — Postfix + Dovecot + Roundcube
```

Zona DNS `opensec.lab` configurada automáticamente:

| Registro | Nombre | Valor |
|----------|--------|-------|
| A | `mail.opensec.lab` | 172.18.0.7 |
| A | `webmail.opensec.lab` | 172.18.0.7 |
| A | `gophish.opensec.lab` | 172.18.0.5 |
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
