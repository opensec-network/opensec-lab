# API Vulnerable — OWASP API Top 10

**URL:** http://localhost:8025
**Health check:** `curl http://localhost:8025/api/health`
**Proposito:** Practicar las 4 vulnerabilidades de API mas comunes.

---

## Endpoints disponibles

| Metodo | Endpoint | Vulnerabilidad |
|--------|----------|----------------|
| POST | `/api/auth/login` | API2: token estatico |
| GET | `/api/users/{id}/profile` | API1: BOLA + API3: datos excesivos |
| PUT | `/api/users/{id}/profile` | API1: BOLA + API3: mass assignment |
| GET | `/api/users/{id}/orders` | API1: BOLA |
| GET | `/api/admin/users` | API5: broken function auth |

## Usuarios de prueba

| Usuario | Password | Token | Rol |
|---------|----------|-------|-----|
| alice | alice123 | token_alice | user |
| bob | bob456 | token_bob | user |
| admin | admin_secret | token_admin | admin |

## Ejemplo rapido — Login

```bash
curl -s -X POST http://localhost:8025/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"alice","password":"alice123"}'
```

## Ejemplo rapido — BOLA

```bash
# alice accede al perfil de bob (deberia ser denegado)
curl -s http://localhost:8025/api/users/2/profile \
  -H "Authorization: Bearer token_alice"
```

## Deteccion en Wazuh

| Regla | Vulnerabilidad | Evento |
|-------|---------------|--------|
| 100061 | API1 BOLA lectura | bola_attempt |
| 100062 | API1 BOLA escritura | bola_write_attempt |
| 100063 | API3 Mass Assignment | mass_assignment_attempt |
| 100064 | API5 Broken Function Auth | broken_function_auth |
| 100065 | API2 Login fallido | login_failed |

Busca con el filtro `group: openseclab_api`.