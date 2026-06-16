# Próxima sesión — Estado y cómo continuar

Última actualización: 2026-06-15

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
| 3 | Phishing | GoPhish | Comportamiento + correlación email→web | ⏳ **Pendiente — el siguiente** |
| 4 | Kill Chain | Red/multi-señal | Correlación tipo analista SOC | ⏳ Pendiente (avanzado) |

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

## Próximo: Taller 3 — Phishing → Detección

- **Servicios:** `gophish` (requiere `dns` + `mail`), `desktop` (víctima con Thunderbird), `wazuh`.
- **Ataque:** lanzar la campaña GoPhish ya pre-configurada → la víctima (Desktop) abre el correo,
  hace click en la landing, envía credenciales.
- **Spike a verificar PRIMERO:** la regla Wazuh "Click en landing page registrado" existe
  (`services/wazuh/rules/openseclab.xml`, grupo `openseclab_gophish,phishing`), pero NO está
  verificado de dónde lee (logs de GoPhish vs Suricata viendo el GET a la landing). Levantar
  gophish+mail+dns+desktop, disparar la campaña, y confirmar qué evento/alerta se genera y si
  llega a Wazuh. La habilidad azul es correlación email→web (mismo usuario recibió, abrió, picó).
- **Posible trabajo de motor:** si el click no genera alerta en Wazuh, conectar la fuente
  (logs de GoPhish → Wazuh, o regla nueva). Verificar antes de escribir la guía.

## Después: Taller 4 — Kill Chain → Correlación (avanzado)

- **Ataque (cadena):** recon (port scan → Suricata "Escaneo de puertos SYN detectado") →
  explotación del servicio hallado (web o API) → observar la cadena.
- **Decisión abierta:** el Desktop no trae `nmap`/`sqlmap` (solo `curl`). Para el scan: `nc -z`
  en bucle (cero dependencias) como camino por defecto, o añadir `nmap` al `custom-init.sh`.
- **Habilidad azul:** correlacionar en Wazuh "scan + ataque al servicio escaneado".

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
