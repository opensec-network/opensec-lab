# Cheat Sheet — Burp Suite

Guia de referencia rapida para interceptar y modificar trafico HTTP.

---

## Configuracion inicial

1. Abre Burp Suite — **Proxy** — **Options**
2. El proxy escucha en `127.0.0.1:8080` por defecto
3. Configura tu navegador para usar ese proxy
4. Instala el certificado: navega a `http://burpsuite` con el proxy activo

## Interceptar una peticion

1. **Proxy** — **Intercept** — boton **Intercept is on**
2. Navega a la aplicacion en el navegador
3. La peticion aparece en Burp — modifica lo que necesites
4. Haz clic en **Forward** para enviarla

## Repetir peticiones con Repeater

1. Click derecho en peticion — **Send to Repeater**
2. En **Repeater**, modifica headers/body y haz clic en **Send**
3. Ideal para explorar APIs y probar payloads

## Fuerza bruta con Intruder

1. Click derecho en peticion — **Send to Intruder**
2. Marca el campo a variar con `§valor§`
3. En **Payloads**, carga un wordlist
4. Haz clic en **Start Attack**

## Explorar la API del lab con Burp

```bash
curl --proxy http://127.0.0.1:8080 http://localhost:8025/api/health
```

Burp captura la peticion en HTTP History. Click derecho — **Send to Repeater** para explorar libremente.

## Tips para APIs

- Usa **Content-Type: application/json** en peticiones modificadas
- El **Target** — **Site Map** agrupa los endpoints descubiertos automaticamente
- Activa **Logger** para ver todo el trafico incluso sin interceptar
