# Guia de instructor: Ataque y deteccion en APIs

Esta guia ayuda a facilitar el taller **Ataque y deteccion en APIs** para una clase, meetup, equipo interno o practica individual supervisada.

## Resumen

- Duracion estimada: 45 a 75 minutos.
- Nivel: principiante-intermedio.
- Modo: practica guiada con comandos `curl`.
- Resultado: el estudiante explota tres fallas y relaciona los eventos con reglas de Wazuh.

## Servicios requeridos

Minimo:

- `opsn-api`
- `opsn-docs`

Recomendado para la parte defensiva:

- `opsn-wazuh`
- `opsn-suricata`
- `opsn-portal`

## Preparacion

1. Inicia los servicios requeridos.
2. Espera a que `opsn-api` responda en `http://localhost:8025/api/health`.
3. Si usaras Wazuh, espera a que el dashboard responda en `https://localhost:5601`.
4. Ejecuta el readiness helper cuando exista:

```bash
bash tests/api-breach-readiness.sh
```

## Credenciales y tokens

| Usuario | Password | Token esperado |
| --- | --- | --- |
| `alice` | `alice123` | `token_alice` |
| `bob` | `bob456` | `token_bob` |
| `admin` | `admin_secret` | `token_admin` |

## Evidencia esperada

| Paso | Request | Evento esperado | Regla Wazuh |
| --- | --- | --- | --- |
| BOLA | `GET /api/users/2/profile` con token de Alice | `bola_attempt` | `100061` |
| Broken function auth | `GET /api/admin/users` con token de Alice | `broken_function_auth` | `100064` |
| Mass assignment | `PUT /api/users/1/profile` con campo `role` | `mass_assignment_attempt` | `100063` |

## Temas de explicacion

- BOLA ocurre cuando el servidor confia en el identificador del objeto solicitado sin validar propiedad o permiso.
- Excessive data exposure aparece cuando la API devuelve mas datos de los necesarios.
- Mass assignment ocurre cuando el servidor aplica campos enviados por el cliente sin una lista permitida.
- Broken function authorization ocurre cuando el servidor autentica al usuario pero no valida si puede ejecutar esa funcion.
- La deteccion depende de eventos con nombres estables, contexto de usuario, endpoint y metodo HTTP.

## Troubleshooting

### La API no responde

Verifica que el contenedor exista:

```bash
docker ps --format '{{.Names}}' | grep -x opsn-api
```

Si no aparece, inicia el perfil de API.

### El token no es `token_alice`

Verifica el usuario y password:

```bash
curl -s -X POST http://localhost:8025/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"alice","password":"alice123"}'
```

### No aparecen eventos en Wazuh

Primero confirma que el log de API tiene eventos:

```bash
docker exec opsn-api sh -lc 'tail -n 20 /logs/api.log'
```

Luego confirma que Wazuh manager esta corriendo:

```bash
docker ps --format '{{.Names}}' | grep -x opsn-wazuh-manager
```

Wazuh puede tardar varios minutos en indexar eventos despues del arranque.

## Reset antes de repetir

```bash
docker restart opsn-api
docker exec opsn-api sh -lc ': > /logs/api.log'
```
