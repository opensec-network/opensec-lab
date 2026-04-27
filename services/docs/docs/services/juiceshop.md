# OWASP Juice Shop

**URL:** http://localhost:3000
**Credenciales:** ninguna (los retos son descubrirlas)
**Proposito:** 100+ retos que cubren todo el OWASP Top 10.

---

## Como empezar

1. Abre http://localhost:3000
2. El reto inicial es encontrar el **Score Board** (esta oculto en la interfaz)
3. Pista: inspecciona el codigo fuente o los archivos JavaScript del frontend

## Categorias de retos

| Categoria | Dificultad | Ejemplos |
|-----------|-----------|---------|
| Injection | 1-4 estrellas | SQLi en login, NoSQLi |
| Broken Authentication | 2-4 estrellas | Reset de password, JWT |
| XSS | 1-4 estrellas | Reflected, DOM-based |
| Broken Access Control | 2-5 estrellas | IDOR, endpoints ocultos |
| Security Misconfiguration | 1-3 estrellas | Headers, error disclosure |

## Primer reto recomendado

Intenta iniciar sesion como administrador usando SQL injection en el campo email:

```
' OR 1=1--
```

## Deteccion en Wazuh

| Regla | Descripcion |
|-------|-------------|
| 100010 | Acceso al Score Board |
| 100011 | SQLi en endpoint de login |
| 100012 | Actividad en API de feedbacks |

Busca con el filtro `group: openseclab_juiceshop`.