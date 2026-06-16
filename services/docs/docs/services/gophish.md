# GoPhish

**URL:** https://localhost:3333
**Credenciales:** `admin` / `Password`
**Proposito:** Framework de simulacion de phishing. Campana pre-configurada.

---

## Configuracion pre-existente

| Elemento | Detalle |
|----------|---------|
| Sending Profile | SMTP a opsn-mail:25 (hostname de red interna) |
| Email Template | "Tu contrasena ha expirado" |
| Landing Page | Portal corporativo falso |
| Users & Groups | admin@opensec.lab y user@opensec.lab (victimas simuladas) |
| Campaign | Pre-armada, lista para lanzar |

## Credenciales de admin

**Usuario:** `admin`  
**Password:** la definida en `OPSN_GOPHISH_PASSWORD` (valor por defecto: `Password`)

Si cambiaste la variable en `.env`, usa ese valor. Para confirmar la password configurada:

```bash
docker exec opsn-gophish-init env | grep OPSN_GOPHISH_PASSWORD
```

## Lanzar la campana

1. Abre https://localhost:3333 (acepta el cert autofirmado)
2. Inicia sesion con `admin` / `Password`
3. Ve a **Campaigns**
4. Haz clic en **Launch Campaign**

## Interpretar resultados

| Estado | Significado |
|--------|------------|
| Email Sent | Correo entregado al servidor de mail |
| Email Opened | Pixel de tracking cargado |
| Clicked Link | Victima hizo clic en el enlace |
| Submitted Data | Victima introdujo credenciales |

## Deteccion en Wazuh

La regla **100020** se activa cuando alguien visita la URL de tracking de GoPhish.