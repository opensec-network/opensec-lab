# OpenSec Lab

Laboratorio de ciberseguridad basado en Docker. Cada accion ofensiva que ejecutes deja una traza defensiva que puedes analizar en Wazuh.

---

## Empezar aqui

Elige un camino:

| Camino | Para quien | Primer paso |
|--------|-----------|-------------|
| [Escenario: Phishing](scenarios/phishing.md) | Quieres ver el ciclo completo de un ataque de phishing | Lanzar campana en GoPhish |
| [Escenario: API Security](scenarios/api.md) | Quieres practicar OWASP API Top 10 | Explorar la API vulnerable en :8025 |
| [Escenario: Web Hacking](scenarios/web.md) | Quieres practicar SQL injection, XSS, etc. | Abrir DVWA en :8080 |

---

## Servicios del lab

| Servicio | Puerto | Rol |
|----------|--------|-----|
| [DVWA](services/dvwa.md) | 8080 | Target vulnerable — OWASP Web Top 10 |
| [Juice Shop](services/juiceshop.md) | 3000 | Target vulnerable — 100+ retos |
| [API Vulnerable](services/api.md) | 8025 | Target vulnerable — OWASP API Top 10 |
| [GoPhish](services/gophish.md) | 3333 | Herramienta ofensiva — phishing |
| [Wazuh SIEM](services/wazuh.md) | 5601 | Herramienta defensiva — SIEM |
| [Mail / Roundcube](services/mail.md) | 8888 | Infraestructura — servidor de correo |

---

## Arquitectura

```
openseclab (172.18.0.0/16)
├── 172.18.0.2  opsn-dns          Technitium DNS
├── 172.18.0.3  opsn-dvwa         DVWA :8080
├── 172.18.0.4  opsn-juice-shop   Juice Shop :3000
├── 172.18.0.5  opsn-gophish      GoPhish :3333/:80
├── 172.18.0.6  opsn-desktop      XFCE Desktop :3100
├── 172.18.0.7  opsn-mail         Postfix+Roundcube :8888
├── 172.18.0.8  opsn-api          API Vulnerable :8025
├── 172.18.0.9  opsn-wazuh        Wazuh SIEM :5601
└── 172.18.0.10 opsn-docs         MkDocs :4000
```

Pipeline de deteccion: Flask escribe JSON a `/logs/api.log` — volumen Docker — Wazuh indexa — alerta visible en Dashboards.
