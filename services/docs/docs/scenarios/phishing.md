# Escenario: Phishing con GoPhish

**Duracion estimada:** 30 minutos
**Servicios necesarios:** GoPhish, Mail, Desktop (opcional)
**Lo que aprenderas:** Como funciona un ataque de phishing y que registros genera.

---

## Objetivo

Lanzar una campana de phishing contra usuarios del lab, ver como llegan los correos, y analizar las alertas que genera Wazuh.

---

## Paso 1 — Acceder a GoPhish

Abre https://localhost:3333 en tu navegador.

> GoPhish usa un certificado autofirmado. Acepta la excepcion de seguridad del navegador.

Las credenciales se generan al instalar el servicio. Para verlas:

```bash
docker logs opsn-gophish 2>&1 | grep "Please login"
```

---

## Paso 2 — Revisar la configuracion pre-existente

El sidecar `opsn-gophish-init` ya configuro:

- **Sending Profile** — SMTP apuntando a `opsn-mail:25` (nombre interno; la IP es dinámica)
- **Email Template** — "Tu contrasena ha expirado"
- **Landing Page** — Portal corporativo falso con captura de credenciales
- **Users & Groups** — `admin@opensec.lab`, `user@opensec.lab`
- **Campaign** — Pre-armada, lista para lanzar

Navega a **Campaigns** para verla.

---

## Paso 3 — Lanzar la campana

En la campana pre-configurada, haz clic en **Launch Campaign**.

GoPhish enviara correos a los usuarios del grupo via el servidor SMTP interno.

---

## Paso 4 — Ver el correo en Roundcube

Abre http://localhost:8888 e inicia sesion como `admin@opensec.lab` / `Password`.

Deberias ver el correo de phishing en la bandeja de entrada.

**Punto de decision:** El correo parece legitimo? Que senales delatan que es falso?

---

## Paso 5 — Hacer clic en el enlace (simular victima)

En el correo de phishing, haz clic en el enlace. Seras redirigido a la landing page de GoPhish en http://localhost:80.

Introduce credenciales ficticias en el formulario y envia.

GoPhish captura las credenciales. En el dashboard aparecera el evento como "Submitted Data".

---

## Paso 6 — Ver las alertas en Wazuh

Abre https://localhost:5601 (Wazuh Dashboards). Credenciales: `admin` / `admin`.

Ve a **Security Events** y busca:

```
group: openseclab_gophish
```

Deberias ver la regla **100020** que se dispara cuando alguien hace clic en la landing page.

---

## Para reflexionar

- Como se diferencia este correo de uno legitimo?
- Que controles hubieran bloqueado este ataque? (SPF, DKIM, MFA, entrenamiento de usuarios)
- Wazuh detecto el clic pero no el envio de credenciales. Por que? Como podrias mejorar la deteccion?
