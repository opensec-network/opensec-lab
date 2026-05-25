# OpenSec Lab Workshop Product Direction Design

Date: 2026-05-25
Status: Approved design, pending implementation plan
Branch: `feat/product-direction-workshops`

## Summary

OpenSec Lab will evolve into a cybersecurity lab with two first-class modes:

1. **Free exploration**: users can install services, open tools and targets, run
   their own attacks, inspect logs, and learn independently.
2. **Guided workshops**: users, instructors, and communities can follow optional
   structured exercises with objectives, commands, expected evidence,
   explanations, and reset/troubleshooting notes.

The first vertical slice will be **Taller: Ataque y detección en APIs**, an API
security workshop that takes learners from vulnerable API abuse to defensive
evidence in logs and Wazuh rule references.

This branch should prove the product direction without doing the final portal
visual redesign. The CLI remains the setup/control surface. The portal becomes
the post-install learning and navigation surface.

## Goals

- Preserve free exploration as a primary user path.
- Add one polished guided workshop for API security and detection.
- Add Spanish user-facing workshop content.
- Add a light portal structure update that exposes both product modes.
- Add a focused readiness/doctor check for the API workshop.
- Update validation so tests match the current supported product.

## Non-Goals

- Do not replace the command-line installer with a click-to-install web flow.
- Do not complete the final portal visual redesign in this slice.
- Do not add points, badges, leaderboards, scoring, or competitive mechanics.
- Do not add broad new services before the current product surface is coherent.
- Do not require full Wazuh UI automation as an MVP gate unless it becomes cheap
  and reliable.

## Product Model

### Free Exploration

Free exploration is the default lab experience. Users can choose services and
use the portal or docs to jump directly into tools and vulnerable targets.

This mode must keep:

- Direct access to service cards.
- Modular service selection.
- Service documentation, credentials, and troubleshooting.
- Room for users to run custom scans, payloads, scripts, and investigations.
- No requirement to follow a workshop sequence.

The portal must not make free exploration feel like a fallback path.

### Guided Workshops

Guided workshops are optional learning paths layered on top of the lab. A
workshop packages a specific scenario with:

- Student guide.
- Instructor guide.
- Required services and estimated runtime.
- Commands and expected outputs.
- Expected log events and rule references.
- Mitigation/reflection notes.
- Readiness and troubleshooting guidance.

Guided workshops help users who want structure, but they must not hide or
constrain the underlying lab.

## First Workshop

User-facing title:

**Taller: Ataque y detección en APIs**

Internal codename:

`api-breach`

This is the first workshop because the repo already has the required technical
surface:

- `opsn-api` implements deliberate OWASP API Top 10 vulnerabilities.
- API actions write JSON events to `opsn_api_logs`.
- Wazuh reads the API log volume.
- Wazuh rules already reference API events such as `bola_attempt`,
  `mass_assignment_attempt`, and `broken_function_auth`.
- Suricata has API-oriented signatures.
- Existing MkDocs content already explains API attack concepts.

## User Flows

### Flow A: Free Exploration

The user installs services, opens the portal, and sees direct service access as
first-class. They can open API, Wazuh, DVWA, Juice Shop, GoPhish, Docs, Mail, or
Desktop without entering a guided path.

Success condition: the workshop layer does not bury or weaken the current lab
dashboard.

### Flow B: Guided API Workshop

The user opens the portal or docs and chooses **Taller: Ataque y detección en
APIs**. The student guide walks them through:

1. Confirm the API is alive.
2. Login as `alice`.
3. Trigger BOLA.
4. Trigger mass assignment.
5. Trigger broken function authorization.
6. Inspect generated API log events.
7. Find corresponding Wazuh rule references.
8. Understand mitigations.

Success condition: a learner can complete the workshop without extra manual
explanation from the maintainer.

### Flow C: Instructor / Community

An instructor opens the instructor guide before a session. It provides:

- Required services.
- Estimated runtime.
- Prep checklist.
- Expected outputs.
- Expected log events.
- Expected Wazuh rule IDs.
- Common troubleshooting.
- Cleanup/reset notes.

Success condition: someone can run this in a small workshop or internal training
without reverse-engineering the lab.

## Architecture

The MVP is a thin vertical slice across four surfaces.

### 1. MkDocs Content

Add:

- `services/docs/docs/workshops/api-breach.md`
- `services/docs/docs/workshops/api-breach-instructor.md`

Update:

- `services/docs/mkdocs.yml` with a Spanish `Talleres` nav section.

The student guide should link back to the general API service docs so a user can
leave the guided path and explore freely.

### 2. Portal

Update `services/portal/generate_portal.sh` structurally, not as a final visual
redesign.

The portal should expose:

- `Explorar libremente`
- `Talleres guiados`
- `Taller: Ataque y detección en APIs`
- Direct service access cards remain prominent.

The portal copy must be Spanish. The CTA should send users to the workshop docs
or Docs service path.

### 3. Readiness / Doctor Check

Add a focused readiness helper first, rather than deeply expanding the installer
UX immediately.

Recommended shape:

- A shell helper at `tests/api-breach-readiness.sh` for MVP readiness.
- Designed so `opensec-lab.sh doctor api-breach` can call it later.
- User-facing output in Spanish.

Minimum checks:

- API health responds when the API service is running.
- Login as `alice` returns `token_alice`.
- BOLA request produces or verifies the expected `bola_attempt` behavior.
- Mass assignment request produces or verifies `mass_assignment_attempt`.
- Admin endpoint request produces or verifies `broken_function_auth`.
- Failure messages explain what to start or inspect.

The MVP should prove the API/log event path. Full Wazuh UI validation can remain
manual or instructor-facing unless a cheap API-based check is available.

### 4. Tests

Update static and targeted smoke validation to match the new product direction.

Static tests should cover:

- Workshop student page exists.
- Workshop instructor page exists.
- MkDocs nav includes the new workshop section.
- Portal contains Spanish mode labels.
- Portal contains the API workshop CTA.
- Current portal section expectations are aligned with current Spanish copy.
- Previously removed points/leaderboard terminology is not reintroduced.

Targeted smoke validation should be available for the API workshop path when the
API service is running.

## Language Standard

All user-facing shipped content must be Spanish.

This includes:

- Portal labels, CTAs, cards, descriptions, status text, errors, and helper
  text.
- MkDocs workshop pages.
- Student guide.
- Instructor guide.
- Readiness/doctor output.
- Installer/menu additions if added.
- Test assertions for visible user-facing copy.

Internal planning files can remain English when useful, but anything shown to a
learner, instructor, or community user must be Spanish.

## Implementation Phases

### Phase 0: Baseline Cleanup

Goal: make the branch coherent before adding new features.

- Keep or remove current product-direction docs intentionally.
- Fix the stale static test expectation around `DEFENSA`.
- Preserve the no-points/leaderboard cleanup.
- Avoid staging `.DS_Store`.

Exit criteria:

- `make validate` passes.
- `make test-static` passes, unless there is a documented unrelated blocker.

### Phase 1: Spanish Workshop Docs

Goal: create the first guided workshop in MkDocs.

- Add student guide.
- Add instructor guide.
- Add MkDocs nav entry in Spanish.
- Keep links back to free API exploration docs.

Exit criteria:

- Static tests prove docs exist and nav links are present.

### Phase 2: Portal Structure Update

Goal: expose both product modes without doing the final visual redesign.

- Add Spanish copy for free exploration and guided workshops.
- Add API workshop CTA.
- Keep service cards/direct access prominent.

Exit criteria:

- Portal generator contains expected Spanish copy.
- Static tests pass.

### Phase 3: Readiness / Doctor Check

Goal: make the workshop practical for users and instructors.

- Add focused readiness helper for the API workshop.
- Check API availability and API attack/log event behavior.
- Print clear Spanish output.
- Keep the helper suitable for future `opensec-lab.sh doctor api-breach`
  integration.

Exit criteria:

- Helper has shell syntax validation.
- A local or documented smoke path proves the API checks work when services are
  running.
- Failure messages are clear and Spanish.

## Validation Plan

Run:

```bash
make validate
make test-static
```

When API services are available, run the targeted API workshop smoke/readiness
check.

Known current branch issue before implementation:

- `make test-static` currently fails because it expects `DEFENSA`, while the
  current portal copy says `Blue Team — Defensa y Aprendizaje`. The
  implementation should align this assertion with final Spanish portal copy.

## Implementation Detail Decisions

- The MVP readiness helper will live at `tests/api-breach-readiness.sh`.
- Future CLI integration can wrap or move that helper into
  `opensec-lab.sh doctor api-breach` once the readiness behavior is proven.
