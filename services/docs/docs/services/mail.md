# Servidor de Correo — Postfix + Roundcube

**Webmail:** http://localhost:8888
**SMTP:** 172.18.0.7:25 (interno), 587 (submission)
**IMAP:** 172.18.0.7:143

---

## Cuentas disponibles

| Usuario | Password | Proposito |
|---------|----------|-----------|
| admin@opensec.lab | Password | Cuenta principal |
| user@opensec.lab | Password | Victima de phishing |

## Acceder via Roundcube

1. Abre http://localhost:8888
2. Inicia sesion con `admin@opensec.lab` / `Password`
3. Los correos de phishing de GoPhish llegan aqui

## Verificar el servidor SMTP

```bash
docker exec opsn-desktop nc -zv 172.18.0.7 25
```

## Proposito en los escenarios

El servidor de correo es la infraestructura que recibe los correos de GoPhish. Sin el servidor de correo activo, GoPhish no puede entregar emails.

El Desktop incluye Thunderbird pre-configurado con la cuenta `admin@opensec.lab` para simular el rol de victima recibiendo phishing.