# GoPhish

**URL:** https://localhost:3333
**Proposito:** Framework de simulacion de phishing. Campana pre-configurada.

---

## Configuracion pre-existente

| Elemento | Detalle |
|----------|---------|
| Sending Profile | SMTP a opsn-mail (172.18.0.7:25) |
| Email Template | "Tu contrasena ha expirado" |
| Landing Page | Portal corporativo falso |
| Users & Groups | admin@opensec.lab, user@opensec.lab |
| Campaign | Pre-armada, lista para lanzar |

## Obtener la contrasena de admin

```bash
docker logs opsn-gophish 2>&1 | grep "Please login"
```

## Lanzar la campana

1. Abre https://localhost:3333 (acepta el cert autofirmado)
2. Inicia sesion con la password obtenida
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