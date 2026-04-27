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
| 2 | **Juice Shop** | OWASP Juice Shop — 100+ retos | 3000 |
| 3 | **API Vulnerable** | API REST con OWASP API Top 10 | 8025 |
| 4 | **GoPhish** | Framework de phishing con campaña pre-configurada | 3333, 80 |
| 5 | **Desktop** | Escritorio XFCE con Thunderbird pre-configurado | 3100 |
| 6 | **DNS** | Servidor DNS Technitium para la zona `opensec.lab` | 5380 |
| 7 | **Mail** | Servidor de correo + Roundcube webmail | 8888 |
| 8 | **Wazuh** | SIEM — detecta todos los ataques del lab en tiempo real | 5601 |
| 9 | **Suricata** | IDS — monitorea el tráfico de red del lab | — |
| 10 | **Portal** | Panel de inicio con acceso a todos los servicios | 4080 |
| 11 | **Docs** | Documentación y escenarios guiados | 4000 |

> GoPhish requiere DNS y Mail. Wazuh requiere DNS. Desktop y Mail requieren DNS.

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
| Wazuh | `admin` | `SecretPassword` | https://localhost:5601 |
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
└── 172.18.0.10 opsn-suricata     Suricata IDS (pasivo)
```

Zona DNS `opensec.lab` configurada automáticamente:

| Registro | Nombre | Valor |
|----------|--------|-------|
| A | `mail.opensec.lab` | 172.18.0.7 |
| A | `webmail.opensec.lab` | 172.18.0.7 |
| A | `gophish.opensec.lab` | 172.18.0.5 |
| A | `api.opensec.lab` | 172.18.0.8 |
| A | `docs.opensec.lab` | 172.18.0.10 |
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
