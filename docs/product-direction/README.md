# OpenSec Lab Product Direction

Date: 2026-05-24 (verificado 2026-06-15)
Status: Direction approved; flagship "API Breach to Detection" implementado y verificado
end-to-end el 2026-06-15 (macOS Docker Desktop / Apple Silicon). Camino ofensivo + indexación
de alertas en Wazuh confirmados por `tests/api-breach-readiness.sh` (9/9, reglas 100061/100063/100064).
Modo taller + doctor disponibles en el menú del script. Recorrido de las 3 audiencias (autoguiado
docs:4000, instructor/demo portal:8443) responde HTTP 200. AMD64 es la plataforma primaria; esta
corrida fue en ARM sin fallos ARM-específicos observados.

## Direction

OpenSec Lab should become a cybersecurity lab with two complementary modes:

1. **Free exploration:** users can install services and explore targets,
   tooling, traffic, logs, and attacks on their own.
2. **Guided workshops:** users, instructors, and communities can follow
   repeatable exercises with clear objectives, evidence, and explanations.

The product direction is not points, badges, or leaderboards. The value is a
complete learning loop:

1. Run a realistic attack or abuse path.
2. Generate real logs and alerts inside the lab.
3. Investigate the evidence in defensive tooling.
4. Understand the vulnerable behavior and the mitigation.
5. Reset or rerun the exercise consistently.

## First Flagship Experience

Start with one polished workshop:

**API Breach to Detection**

This is the best first scenario because the repo already has most of the
technical surface:

- `opsn-api` implements deliberate OWASP API Top 10 vulnerabilities.
- API actions write JSON events to `opsn_api_logs`.
- Wazuh reads the API log volume.
- Wazuh rules already map API events such as BOLA, mass assignment, and broken
  function authorization.
- Suricata has API-oriented signatures.
- Existing MkDocs content already explains the API attack path.

## Target Audience

- Self-directed learners who want a flexible lab to explore freely.
- Learners practicing API security and blue-team analysis through guided paths.
- Instructors running a workshop for a class, meetup, bootcamp, or internal team.
- Community organizers who need a repeatable lab with minimal live support.
- Security teams who want a lightweight local demo for appsec and detection
  engineering concepts.

## Product Modes

### Free Exploration Mode

This is the default lab experience. The user chooses services, opens the portal
or docs, and explores without being forced into a fixed path.

This mode should preserve:

- Modular service selection.
- Direct links to tools and vulnerable targets.
- Service docs, credentials, and troubleshooting.
- Room for users to run their own attacks, scripts, scans, and investigations.
- No requirement to follow a workshop or predefined sequence.

The portal should make free exploration feel first-class, not like a fallback.

### Guided Workshop Mode

This is an optional layer on top of the lab. It packages a specific learning path
with objectives, commands, expected evidence, explanations, and reset steps.

Guided workshops should help users who want structure, but they should never hide
or constrain the underlying lab.

## What "Instructor / Community Mode" Means

Instructor/community mode is a repeatable workshop packaging layer. It should not
add points, badges, or leaderboards. It should make the lab easy to facilitate.

For a selected workshop, the lab should provide:

- A student guide with steps, commands, URLs, and expected observations.
- An instructor guide with timing, expected detections, explanations, and
  troubleshooting.
- A readiness check that proves the required services and telemetry path work.
- A reset/cleanup path so the exercise can be rerun.
- Clear service requirements: profiles, RAM, ports, credentials, and expected
  runtime.

Implemented as interactive menu options (no subcommand args required):

- **Option 12** — Modo taller: instala los servicios requeridos y muestra URLs del taller.
- **Option 13** — Doctor: verifica el camino ataque→detección (API health, log write, Wazuh ping).
- **Option 15** — Reset del taller: borra alertas acumuladas y reinicia la API para re-correr el ejercicio.

## Product Principles

- Preserve free exploration as a primary use case.
- Prefer one excellent end-to-end workshop over many shallow scenarios.
- Keep the current modular install model.
- Make every scenario explain both attack behavior and defensive evidence.
- Keep workshop materials useful offline and inside MkDocs.
- Keep guided content optional and easy to ignore.
- Do not expand service surface until the current API, phishing, web, docs,
  portal, and validation story is coherent.
