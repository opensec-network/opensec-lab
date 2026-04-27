# opsn-gophish — GoPhish con campaña Acme Corp preconfigurada

Usa la imagen publicada `opensecnetwork/gophish:multi-arch`. Al instalar este servicio,
el contenedor `opsn-gophish-init` configura automáticamente todo via la API REST de GoPhish
con branding de la empresa ficticia **Acme Corp**.

## Qué se configura automáticamente

| Recurso | Nombre (default) | Detalle |
|---------|------------------|---------|
| Sending Profile | Acme Corp Mail Server | SMTP → opsn-mail:25 |
| Email Template | Acme Corp Password Reset | Email de contraseña expirada, logo Acme Corp |
| Landing Page | Acme Corp Login Page | Captura usuario + contraseña, logo Acme Corp |
| User Group | Acme Corp Lab Users | admin@opensec.lab, user@opensec.lab |
| Campaign | Acme Corp - Campaña Demo | Pre-armada, **no lanzada** |

## Uso

1. Acceder a `https://localhost:3333`
2. Login con `admin` y la contraseña que el instalador mostró al finalizar
3. Ir a **Campaigns** → la campaña ya está lista con todos los activos
4. Hacer clic en **Launch Campaign** para iniciarla
5. El correo llegará a los destinatarios configurados (visibles en **Users & Groups**)
6. Verificar recepción en Roundcube: `http://localhost:8888`

## Variables de entorno configurables

Todas se definen en `.env` (o `config/defaults.env`):

| Variable | Default | Descripción |
|----------|---------|-------------|
| `OPSN_GOPHISH_COMPANY_NAME` | `Acme Corp` | Nombre de la empresa ficticia |
| `OPSN_GOPHISH_FROM_NAME` | `Soporte IT` | Nombre visible del remitente |
| `OPSN_GOPHISH_EMAIL_SUBJECT` | `Accion requerida: ...` | Asunto del correo |
| `OPSN_GOPHISH_SUPPORT_TEAM` | `Equipo de Seguridad IT` | Firma en el cuerpo del email |
| `OPSN_GOPHISH_CAMPAIGN_NAME` | `Acme Corp - Campaña Demo` | Nombre en el panel GoPhish |
| `OPSN_GOPHISH_SMTP_PORT` | `25` | Puerto SMTP del servidor de correo |

## Estructura de archivos

```
services/gophish/
├── configure_gophish.sh        # Script de bootstrap via API REST (sidecar)
├── assets/
│   └── logo.svg                # Logo corporativo de Acme Corp (editable)
├── templates/
│   ├── email_template.html     # Plantilla del correo de phishing
│   └── landing_page.html       # Página de captura de credenciales
└── README.md
```

## Personalizar el branding

| Elemento | Archivo a editar |
|----------|-----------------|
| Logo | `assets/logo.svg` |
| Cuerpo del email | `templates/email_template.html` |
| Landing page | `templates/landing_page.html` |
| Empresa / asunto / firma | `.env` o `config/defaults.env` |

Los placeholders disponibles en los templates HTML son:

| Placeholder | Reemplazado por |
|-------------|-----------------|
| `%%COMPANY_NAME%%` | `OPSN_GOPHISH_COMPANY_NAME` |
| `%%FROM_NAME%%` | `OPSN_GOPHISH_FROM_NAME` |
| `%%SUPPORT_TEAM%%` | `OPSN_GOPHISH_SUPPORT_TEAM` |
| `%%DOMAIN%%` | `OPSN_DOMAIN` |
| `%%LOGO_IMG%%` | Data URI base64 del logo SVG |

Los merge tags de GoPhish (`{{.URL}}`, `{{.Tracker}}`) se mantienen sin cambios.

## Reinicializar la campaña

Si modificas templates o variables y necesitas re-aplicar desde cero:

```bash
# Eliminar el volumen de datos de GoPhish (esto borra la DB y la contraseña generada)
docker volume rm opsn_gophish_data

# Reiniciar los servicios
docker compose --profile gophish up -d

# Ver progreso del sidecar de configuración
docker logs opsn-gophish-init -f
```

> **Nota:** Al reiniciar, GoPhish genera una nueva contraseña. El instalador la muestra
> en pantalla; también puede leerse con `docker logs opsn-gophish | grep password`.

## Nota sobre seguridad

Esta configuración es exclusivamente para laboratorio de concienciación en seguridad.
Los templates incluyen un disclaimer visible indicando que es un ejercicio controlado.
No está diseñada para uso fuera del entorno `opensec.lab`.
