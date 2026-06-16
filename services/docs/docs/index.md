# OpenSec Lab

Laboratorio de ciberseguridad basado en Docker. Cada accion ofensiva que ejecutes deja una traza defensiva que puedes analizar en Wazuh.

---

## Empezar aqui

Elige un camino:

| Camino | Para quien | Primer paso |
|--------|-----------|-------------|
| [Taller: Ataque y deteccion en APIs](workshops/api-breach.md) | Practica guiada completa — API Top 10 + Wazuh | Confirmar que la API responde en :8025 |
| [Taller: Hacking Web y Deteccion](workshops/web-hacking.md) | Practica guiada completa — SQLi, XSS, CMDi + Suricata | Preparar DVWA en :8080 |
| [Escenario: Phishing](scenarios/phishing.md) | Ciclo completo de un ataque de phishing | Lanzar campana en GoPhish :3333 |

---

## Servicios del lab

| Servicio | Puerto host | Rol |
|----------|-------------|-----|
| [DVWA](services/dvwa.md) | 8080 | Target vulnerable — OWASP Web Top 10 |
| [Juice Shop](services/juiceshop.md) | 3000 | Target vulnerable — 100+ retos OWASP |
| [WebGoat](services/dvwa.md) | 8081 | Target vulnerable — plataforma de aprendizaje OWASP |
| [API Vulnerable](services/api.md) | 8025 | Target vulnerable — OWASP API Top 10 |
| [Gitea](services/dvwa.md) | 3002 | Repos con codigo vulnerable para analisis estatico |
| [GoPhish](services/gophish.md) | 3333 / 80 | Herramienta ofensiva — phishing |
| [Wazuh SIEM](services/wazuh.md) | 5601 | Herramienta defensiva — SIEM + Suricata IDS |
| [Mail / Roundcube](services/mail.md) | 8888 | Infraestructura — servidor de correo interno |
| [Desktop XFCE](services/mail.md) | 3100 | Escritorio con Thunderbird pre-configurado |
| [DNS (Technitium)](services/mail.md) | 5380 | DNS interno del lab |
| [Portal](services/dvwa.md) | 8443 | Dashboard central con enlaces a todos los servicios |
| [Documentacion](services/dvwa.md) | 4000 | Esta guia (MkDocs) |

---

## Arquitectura

```
Red Docker: openseclab (subred dinamica, no usar IPs fijas)

opsn-dns          → DNS interno Technitium (:5380 consola)
opsn-dvwa         → DVWA (:8080)
opsn-juice-shop   → Juice Shop (:3000)
opsn-webgoat      → WebGoat (:8081)
opsn-gophish      → GoPhish (:3333 admin / :80 landing)
opsn-desktop      → XFCE + Thunderbird (:3100)
opsn-mail         → Postfix + Roundcube (:8888 webmail)
opsn-api          → API Flask vulnerable (:8025)
opsn-gitea        → Gitea (:3002 web / :2222 SSH)
opsn-portal       → Portal central (:8443)
opsn-docs         → MkDocs (:4000)
opsn-wazuh        → Wazuh SIEM + Dashboard (:5601)
opsn-suricata     → Suricata IDS (monitorea trafico de red)
```

Pipeline de deteccion: las acciones ofensivas generan trafico o logs — Suricata y el agente Wazuh los inspeccionan — alertas visibles en el Dashboard (:5601).
