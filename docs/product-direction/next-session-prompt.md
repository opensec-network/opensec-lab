# Próxima sesión — Estado y cómo continuar

Última actualización: 2026-06-16

## Dónde estamos

Trabajamos en `/Users/anegron/Desktop/In_Progress/OSN/opensec-lab-v1`.
Rama de trabajo y canónica: **`main`** (= `feat/product-direction-workshops`, apuntan al mismo
commit). Ver [project_repo_topology] en memoria: `main` es el monorepo real; `dev` y los tags
`legacy/*` son el repo viejo. Todo está pusheado (`git ls-remote origin main`).

## Objetivo vigente: la RUTA de talleres (de 1 a 4)

El lab tenía 1 solo taller (15 min → "no aporta valor"). Lo estamos convirtiendo en una **ruta de
4 talleres ataque→detección**, dominios diversos con dificultad creciente, cada uno con una
**habilidad de detección distinta** (la directriz del usuario: nada de la misma prueba reskineada).

Diseño aprobado y completo en:
`docs/superpowers/specs/2026-06-15-ruta-talleres-deteccion-design.md`

| # | Taller | Dominio | Habilidad de detección | Estado |
|---|--------|---------|------------------------|--------|
| 1 | Web Hacking | DVWA | Firma/IDS de red (Suricata) | ✅ **Completo** (2026-06-15) |
| 2 | API Security | API | Eventos estructurados de app | ✅ Existía (flagship) |
| 3 | Phishing | GoPhish | Comportamiento (credential harvesting) | ✅ **Completo** (2026-06-16) |
| 4 | Kill Chain | Red/multi-señal | Correlación tipo analista SOC | ✅ **Completo** (2026-06-16) |

**La ruta de 4 talleres está COMPLETA.** Ver [project_taller3_phishing_spike] en memoria
para los detalles de la sesión 2026-06-16 (hallazgos, fixes y gotchas).

## El patrón PROBADO de implementación (seguir igual para Phishing y Kill Chain)

La lección clave de esta sesión: **el motor de detección suele estar roto; verificar end-to-end
ANTES de escribir contenido.** El Taller 1 reveló que las reglas Suricata web nunca detectaron nada.

Orden por taller:
1. **Spike de factibilidad PRIMERO:** levantar los servicios, ejecutar el ataque real, y confirmar
   en vivo QUÉ alerta se genera y por qué camino (Suricata `eve.json`, logs de app, o eventos del
   servicio) y que llega a Wazuh. NO asumir que las reglas disparan.
2. **Arreglar el motor** si está roto (reglas, decoders, config) y verificar la detección en vivo.
3. **Escribir las guías** (estudiante + instructor) sobre lo que REALMENTE dispara, usando el
   esqueleto de `services/docs/docs/workshops/api-breach.md`.
4. **Readiness** modelado en `tests/api-breach-readiness.sh` o `tests/web-hacking-readiness.sh`
   (degradar a `warn` sin Wazuh/IDS; verificar la indexación real).
5. **Plumbing:** nav en `services/docs/mkdocs.yml`, CTA en `services/portal/generate_portal.sh`,
   aserciones en `tests/static.sh`.
6. **Verificación final:** `make validate && make test-static && bash tests/<taller>-readiness.sh`.

Ejecutamos con subagentes (subagent-driven-development): un subagente por tarea + review.
El plan del Taller 1 es la plantilla exacta: `docs/superpowers/plans/2026-06-15-taller-1-web-hacking-deteccion.md`.

## Cómo se cerraron los Talleres 3 y 4 (2026-06-16)

- **Taller 3 — Phishing:** el motor estaba doblemente roto. (1) `configure_gophish.sh` creaba
  la campaña por `id` en vez de `name` → nunca se creaba (fix `d3e853a`). (2) La regla Wazuh
  `100020` (`/track`) nunca disparaba: no hay fuente de logs de GoPhish (el docker-listener está
  muerto). Decisión del usuario: **solo Suricata por comportamiento**, sin threat-intel ni logs de
  GoPhish. Nueva regla Suricata `9000070` (credential harvesting: POST con password en claro),
  verificada en vivo.
- **Taller 4 — Kill Chain:** la regla de port scan `9000050` usaba `$EXTERNAL_NET` → no detectaba
  scans internos (el atacante del lab está en HOME_NET). Fix a `any any ->` (también cubre lateral
  movement). Cadena recon→explotación verificada y correlacionada en Wazuh por `src_ip`.

## Próximos pasos (la ruta ya está completa)

- **Verificar en AMD64 (Kali):** todo se probó en macOS/ARM. La elevación de nivel de las reglas
  Wazuh custom (`100020`, `100050-59`) no encadena en este ARM por listas rotas del ruleset base;
  la detección sí funciona (alertas indexadas y buscables). Confirmar la elevación en AMD64.
- **Bug latente (fuera de alcance hasta ahora):** las firmas Suricata de la API (`9000060-63`)
  usan `$EXTERNAL_NET` → no disparan para ataques internos. El flagship no las necesita (detecta
  por `api.log`). Mismo fix de una línea que `9000050` si se quiere detección Suricata interna.
- **Índice de ruta + portal:** opcionalmente, una página índice de la ruta (`workshops/index.md`)
  que presente los 4 talleres con su habilidad y orden sugerido. El portal ya enlaza los 4.
- **Release v3.0 + AMD64 + dominio:** ver pendientes mayores abajo.

### Gotcha de entorno crítico (no re-descubrir)

El disco de la VM Docker Desktop se llena (llegó a 100% esta sesión → Suricata no escribe
`eve.json`, Wazuh pasa a read-only y no indexa). Disfraza reglas y pipeline como "rotos" sin
estarlo. **Antes de debuggear una regla que "no dispara", revisar disco** (`docker run --rm
alpine df -h /`); liberar con `docker builder prune -af`.

## Gotchas verificados esta sesión (no re-descubrir)

- **Reglas Suricata web (DVWA):** arregladas (commits c0891c5/d742fd7). Ver [project_wazuh_macos_fixes]
  en memoria: el `;` literal rompe PCRE (usar `\x3b`); ataques GET deben mirar `http.uri` no
  `http.request_body`; `HOME_NET` ahora cubre todo el rango privado (no hardcodear subred).
- **Filtro Wazuh que SÍ funciona** para alertas de Suricata: `rule.groups: suricata` (no
  `data.alert.signature` con match_phrase). Las alertas Suricata entran como `rule.id 86601`.
- **Credencial DVWA:** `admin`/`password` (NO admin/admin; corregido en docs).
- **Red Docker es dinámica:** la subred NO es fija (cayó en 172.21 esta vez, no 172.18). Cualquier
  config que dependa de la subred debe cubrir el rango privado o resolverla en runtime.
- **Wazuh y disco:** si el disco supera ~95%, los índices pasan a read-only y deja de indexar.
  `configure_wazuh.sh` libera el block al iniciar; `reset_taller` (menú opción 15) también.
- **Wazuh indexa con 1-3 min de retraso.** Los readiness reintentan ~2 min.

## Cómo levantar el entorno para trabajar

```bash
cd ~/Desktop/In_Progress/OSN/opensec-lab-v1
cp config/defaults.env /tmp/lab.env
# Para Suricata, fijar la interfaz al bridge real (la subred es dinámica):
netid=$(docker network inspect openseclab -f '{{.Id}}' | cut -c1-12)
echo "OPSN_SURICATA_INTERFACE=br-${netid}" >> /tmp/lab.env
# Levantar lo que cada taller necesite, p.ej. para Phishing:
docker compose -f docker-compose.yml --env-file /tmp/lab.env \
  --profile dns --profile mail --profile gophish --profile desktop --profile wazuh up -d
```
Verificación general del lab: opción 14 (Lab Doctor) del menú, o `bash tests/<taller>-readiness.sh`.

## Pendientes mayores fuera de la ruta (cuando se decida)

- Publicar release `v3.0` (listo: `git tag v3.0 && git push origin v3.0` → release.yml).
- Imágenes Docker `api`/`mail` multi-arch (necesita secrets Docker Hub) → cambiar `build:`→`image:`.
- Registrar dominio `lab.opensec.network`.
- Verificar en AMD64 (plataforma primaria; todo se probó en ARM/macOS).
