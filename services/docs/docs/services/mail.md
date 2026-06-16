# Servidor de Correo — Postfix + Roundcube

**Webmail:** http://localhost:8888
**SMTP:** opsn-mail:25 (red interna), puerto 587 para submission
**IMAP:** opsn-mail:143 (red interna)

---

## Cuentas disponibles

| Usuario | Password | Proposito |
|---------|----------|-----------|
| user@opensec.lab | Password | Victima de phishing (cuenta pre-configurada en Thunderbird) |
| admin@opensec.lab | Password | Cuenta de administracion |

## Acceder via Roundcube

1. Abre http://localhost:8888
2. Inicia sesion con `user@opensec.lab` / `Password` (victima) o `admin@opensec.lab` / `Password`
3. Los correos de phishing de GoPhish llegan aqui

## Verificar el servidor SMTP

```bash
docker exec opsn-desktop nc -zv opsn-mail 25
```

## Proposito en los escenarios

El servidor de correo es la infraestructura que recibe los correos de GoPhish. Sin el servidor de correo activo, GoPhish no puede entregar emails.

El Desktop incluye Thunderbird pre-configurado con la cuenta `user@opensec.lab` para simular el rol de victima recibiendo phishing.