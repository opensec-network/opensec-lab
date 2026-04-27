# DVWA — Damn Vulnerable Web Application

**URL:** http://localhost:8080
**Credenciales:** `admin` / `admin`
**Proposito:** Practicar OWASP Web Top 10 en un entorno controlado.

---

## Vulnerabilidades disponibles

| Modulo | Tipo | Nivel recomendado |
|--------|------|-------------------|
| SQL Injection | Inyeccion | Low |
| SQL Injection (Blind) | Inyeccion ciega | Low |
| Command Injection | Ejecucion remota | Low |
| XSS (Reflected) | Cross-site scripting | Low |
| XSS (Stored) | Persistente | Low |
| CSRF | Falsificacion de peticion | Medium |
| File Upload | Subida arbitraria | Low |
| File Inclusion | LFI/RFI | Low |
| Brute Force | Fuerza bruta | Low |

## Configurar el nivel de seguridad

1. Inicia sesion en http://localhost:8080
2. Ve a **DVWA Security**
3. Selecciona **Low** para empezar (sin proteccion)
4. Progresa a **Medium** y **High** para ver las mitigaciones

## Deteccion en Wazuh

| Regla | Modulo | Endpoint |
|-------|--------|----------|
| 100001 | SQL Injection | `/vulnerabilities/sqli` |
| 100002 | Command Injection | `/vulnerabilities/exec` |
| 100003 | XSS | `/vulnerabilities/xss` |
| 100004 | File Inclusion | `/vulnerabilities/fi` |

Busca en Wazuh con el filtro `group: openseclab_dvwa`.
