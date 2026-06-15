# Ruta OpenSec — de la explotación a la detección (Design)

Date: 2026-06-15
Status: Diseño aprobado, implementación no iniciada

## Problema

Hoy el lab tiene **un** taller guiado completo (API Breach to Detection). Un usuario lo
completa en ~15 min y "ya no hay más que hacer" — el ratio esfuerzo de instalación (~12 GB)
vs valor entregado no se justifica. El motor (reglas de detección Wazuh/Suricata) ya cubre
~13 detecciones en 5 servicios, pero solo 1 está "activado" con contenido guiado.

## Objetivo

Convertir el lab de **1 taller** a una **ruta de 4 talleres** ataque→detección sobre el motor
existente, de forma que pasar de "15 min de contenido" a "varias horas de progresión real"
justifique instalar el lab y entregue valor a la comunidad.

**Restricción central (directriz del usuario):** ningún taller puede sentirse como otro
reskineado. Cada uno cubre un **dominio distinto** y enseña una **habilidad de detección
distinta**, con **dificultad creciente**.

**Fuera de alcance:** NO se añaden servicios nuevos (el motor está completo). NO gamificación
(puntos/badges/leaderboards). NO se rediseña el formato del taller (se reusa el del flagship).

## Estructura del currículo

**Orden sugerido por dificultad, talleres autocontenidos.** Encaja con el modelo del producto
(exploración libre primaria + guiado opcional): hay un orden recomendado, pero cada taller se
puede hacer solo y aporta valor por sí mismo. No se fuerza linealidad ni prerrequisitos rígidos.

| # | Taller | Dominio | Dificultad | Ataque (herramienta) | Habilidad de detección |
|---|--------|---------|------------|----------------------|------------------------|
| 1 | Web Hacking → Detección | Web app (DVWA) | Principiante | SQLi + Command Injection (`curl`) | Detección por **firma/patrón** (IDS de red + logs web) |
| 2 | API Security → Detección *(existe)* | API | Intermedio | BOLA, mass assignment, broken func (`curl`) | **Eventos estructurados** de app + lógica de authz |
| 3 | Phishing → Detección | Humano/social (GoPhish) | Intermedio | Campaña → click → captura | **Comportamiento** + correlación email→web |
| 4 | Kill Chain → Correlación | Red + multi-señal | Avanzado | Recon (port scan) → explotación | **Correlación** de varias señales (analista SOC) |

## Formato consistente por taller

Cada taller reusa el **esqueleto del flagship API** (`services/docs/docs/workshops/api-breach.md`),
con contenido 100% distinto por dominio:

1. Requisitos (servicios + herramientas)
2. Objetivos (qué sabrás explicar al terminar)
3. Pasos de ataque (comandos copy-paste + observación esperada)
4. Tabla de evidencia esperada (request → comportamiento → evento/alerta → regla)
5. Investigación en Wazuh (queries concretas, campos a leer, preguntas de analista)
6. Mitigaciones
7. Reset rápido (apunta a la opción 15 del menú + manual)

Cada taller tiene además una **guía de instructor** (duración, servicios, evidencia esperada,
troubleshooting, reset) y un **readiness helper** que prueba el camino ataque→evidencia.

## Detalle por taller nuevo

### Taller 1 — Web Hacking → Detección (DVWA, principiante)

- **Ataque:** SQL Injection (`/vulnerabilities/sqli`) y Command Injection (`/vulnerabilities/exec`)
  en DVWA vía `curl`. Requiere autenticación a DVWA (`admin/admin`), security level `low` y la
  cookie de sesión (`PHPSESSID`). El readiness debe automatizar el login + set de security level.
- **Habilidad de detección:** a nivel **red/firma**. El ataque viaja por HTTP y lo detecta
  **Suricata** (signatures de SQLi/CMDi en DVWA → `eve.json` → Wazuh). Distinto del taller API,
  cuya detección es por eventos estructurados de aplicación.
- **Riesgo de factibilidad a verificar:** confirmar de qué fuente disparan las alertas — Suricata
  (probable, ve todo el bridge) y/o las reglas Wazuh `100001-100041` si Wazuh lee los logs de
  acceso de DVWA (incierto: el flagship solo conecta `opsn_api_logs`). La implementación debe
  verificar end-to-end qué camino funciona y escribir la guía sobre el que dispara de verdad.
- **Mitigación:** prepared statements / parametrización; validación y allowlist de entrada.

### Taller 3 — Phishing → Detección (GoPhish, intermedio)

- **Ataque:** lanzar la campaña GoPhish ya pre-configurada → la víctima (Desktop + Thunderbird,
  cuenta `admin@opensec.lab`) abre el correo y hace click en la landing → envía credenciales.
- **Habilidad de detección:** de **comportamiento** — eventos sent/opened/clicked/submitted de la
  campaña — y **correlación** email→web (el mismo usuario recibió, abrió y picó).
- **Riesgo de factibilidad a verificar:** la regla Wazuh "Click en landing page registrado" existe;
  confirmar su fuente (logs de GoPhish vs detección Suricata del GET a la landing) y que dispara
  end-to-end. La guía se escribe sobre lo que realmente se observe.
- **Mitigación:** concienciación, MFA, filtrado de correo, verificación de remitente (SPF/DKIM/DMARC).

### Taller 4 — Kill Chain → Correlación (red, avanzado)

- **Ataque (cadena):** (1) Recon — port scan al lab → Suricata "Escaneo de puertos SYN detectado".
  (2) Explotación — atacar el servicio hallado (web o API). (3) Observar la cadena completa.
- **Habilidad de detección:** **correlación** — en Wazuh, hilar "primero un scan, luego un ataque
  al servicio escaneado", pensando como analista SOC. Es la habilidad más realista y avanzada.
- **Decisión abierta (herramientas):** el Desktop no trae `nmap`/`sqlmap` preinstalados (solo
  `curl`). Opciones para el port scan: (a) usar `nc -z` en bucle (disponible), (b) `nmap` desde el
  host del usuario, (c) añadir `nmap` al `custom-init.sh` del Desktop. **Recomendación:** documentar
  `nc -z` como camino por defecto (cero dependencias) y `nmap` como alternativa; decidir en
  implementación si vale añadir `nmap` al Desktop.
- **Mitigación:** segmentación de red, rate-limiting, detección temprana de recon, correlación SIEM.

## Índice de ruta

- **Nueva página MkDocs** `services/docs/docs/workshops/index.md` (o `ruta.md`): presenta los 4
  talleres con dominio, dificultad y habilidad de detección, y sugiere el orden. Cada taller
  enlaza al siguiente. Entrada en `mkdocs.yml` nav bajo "Talleres".
- **CTA en el portal** (`services/portal/generate_portal.sh`): el portal ya enlaza el taller de API;
  ampliar a "Ruta de talleres" apuntando al índice. Sin gamificación.

## Deliverables (por taller nuevo: 1, 3, 4)

Para cada taller nuevo:
- [ ] `services/docs/docs/workshops/<taller>.md` (guía de estudiante, esqueleto del flagship)
- [ ] `services/docs/docs/workshops/<taller>-instructor.md` (guía de instructor)
- [ ] `tests/<taller>-readiness.sh` (prueba ataque→evidencia end-to-end, degradando sin Wazuh)
- [ ] Entrada en `services/docs/mkdocs.yml` nav
- [ ] Aserciones en `tests/static.sh` (docs existen + en nav)
- [ ] Reglas nuevas en Wazuh/Suricata **solo si** la verificación end-to-end muestra que falta
      cobertura (preferir reusar las existentes)

Transversal:
- [ ] `services/docs/docs/workshops/index.md` (índice de ruta) + nav
- [ ] CTA de ruta en el portal + aserción estática
- [ ] Actualizar el README/USER_GUIDE para mencionar la ruta

## Verificación

Lección del flagship: **verificar end-to-end, no asumir que las reglas disparan.** Por cada taller:
1. `make validate` + `make test-static` pasan.
2. El readiness del taller corre el ataque y confirma la **evidencia real** (alerta indexada en
   Wazuh o evento observable), igual que `api-breach-readiness.sh`.
3. Recorrido manual una vez (estudiante + instructor).
La fuente de detección de cada taller (Suricata vs logs de app vs eventos de servicio) se
**confirma durante la implementación**; la guía se escribe sobre lo que realmente dispara.

## Orden de implementación

Aunque el currículo es de 4, se implementa **incrementalmente** y se verifica cada taller
end-to-end antes del siguiente: Taller 1 (Web) → Taller 3 (Phishing) → Taller 4 (Kill Chain) →
índice de ruta + portal + docs. El taller 2 (API) ya existe y sirve de plantilla.
