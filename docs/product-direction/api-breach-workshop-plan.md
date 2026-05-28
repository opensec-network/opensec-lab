# API Breach to Detection Workshop Plan

Date: 2026-05-24
Status: Proposed MVP plan

## Goal

Create the first complete OpenSec Lab workshop: a learner exploits vulnerable API
behaviors and then investigates the resulting Wazuh/Suricata evidence.

This workshop is an optional guided path. It should not replace the free
exploration experience. Users must still be able to run `opsn-api`, open the API
docs, craft their own requests, inspect logs, and experiment without following
the workshop.

## Proposed User Flow

1. Install or start the required profiles.
2. Run readiness checks.
3. Open the student workshop guide.
4. Confirm the API health endpoint responds.
5. Log in as `alice` and obtain `token_alice`.
6. Exploit BOLA by reading another user's profile.
7. Exploit mass assignment by modifying protected fields.
8. Exploit broken function authorization by calling `/api/admin/users`.
9. Open Wazuh and find the expected rules/events.
10. Answer reflection questions about authorization, logging, and mitigation.
11. Reset/rerun the lab if needed.

## Required Services

Minimum likely service set:

- `opsn-api`
- `opsn-wazuh`
- `opsn-suricata`
- `opsn-docs`
- `opsn-portal`
- `opsn-dns` if required by Wazuh profile/dependencies

The exact profile set must be verified during implementation.

## Deliverables

- [ ] `services/docs/docs/workshops/api-breach.md`
- [ ] `services/docs/docs/workshops/api-breach-instructor.md`
- [ ] MkDocs navigation entry for workshops.
- [ ] Portal CTA linking to the API workshop.
- [ ] Portal and docs preserve a clear free-exploration path for API users.
- [ ] Readiness check design for `api-breach`.
- [ ] Installer or helper command design for workshop mode.
- [ ] Static tests covering new docs/nav/portal references.
- [ ] Smoke or integration checks covering the API attack-to-log path.

## Test Plan

Initial tests should stay pragmatic:

- `make validate` must pass.
- `make test-static` must pass after existing portal label drift is resolved.
- Static tests should assert the new workshop docs exist and are in MkDocs nav.
- A targeted smoke test should verify:
  - API health endpoint responds.
  - Login as `alice` succeeds.
  - BOLA request writes a JSON log event.
  - Mass assignment writes a JSON log event.
  - Broken function authorization writes a JSON log event.

Full Wazuh UI verification may be heavier and can be a later integration gate,
but the first implementation should at least prove logs are generated in the
volume Wazuh consumes.

## Current Repo State Notes

- Points/leaderboard wording was removed from remaining docs and generated
  diagram artifacts.
- `make validate` passes.
- `make test-static` currently fails because the static test expects literal
  `DEFENSA`, while `services/portal/generate_portal.sh` currently uses
  `Blue Team — Defensa y Aprendizaje`.
- The worktree already had unrelated local modifications before this direction
  document was created, including README, compose, portal, and `.DS_Store`.

## Implementation Phases

### Phase 0: Coherence Cleanup

- Resolve the portal/test label mismatch.
- Decide whether old references to CTFd, BookStack, crAPI, and Portainer should
  remain as historical roadmap content or be removed from current-facing docs.
- Ensure README, USER_GUIDE, ROADMAP, portal, MkDocs, and tests describe the
  same supported product.
- Make the product model explicit: free exploration remains primary, guided
  workshops are optional.

### Phase 1: Workshop Content

- Add student and instructor guides.
- Add expected evidence tables:
  - request
  - vulnerable behavior
  - expected API log event
  - expected Wazuh rule
  - mitigation concept
- Add copy-paste commands and expected outputs.
- Keep links back to the general API service docs so users can leave the guided
  path and explore freely.

### Phase 2: Readiness Checks

- Design a `doctor api-breach` command or equivalent menu option.
- Check service availability, ports, profile state, API health, and log write
  path.
- Keep checks useful even if Wazuh is still starting.

### Phase 3: Workshop Mode

- Design `workshop api-breach` or an installer menu entry.
- It should tell an instructor exactly what will be installed, expected RAM, and
  expected startup time.
- It should print next steps and doc URLs after install.

### Phase 4: Validation

- Update static tests.
- Add targeted smoke tests.
- Run local validation and document any heavy manual checks.
