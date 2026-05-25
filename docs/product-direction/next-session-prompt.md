# Next Session Prompt

Use this prompt to continue the work in a fresh session.

```text
We are in /Users/anegron/Desktop/In_Progress/OSN/opensec-lab-v1.

Goal: continue from the completed workshop product-direction MVP. The direction
is to make OpenSec Lab a guided, repeatable cybersecurity learning kit while
preserving free exploration as a primary use case. Guided workshops are optional;
users should still be able to install services and explore by themselves. Do not
add points, competitive mechanics, or gamified status systems.

Start by reading:
- docs/superpowers/plans/2026-05-25-workshop-product-direction.md
- docs/superpowers/specs/2026-05-25-workshop-product-direction-design.md
- docs/product-direction/README.md
- docs/product-direction/api-breach-workshop-plan.md

Current implementation state:
- Phase 0 through Phase 4 of
  `docs/superpowers/plans/2026-05-25-workshop-product-direction.md` are complete.
- `make validate` passes.
- `make test-static` passes.
- Runtime readiness is available at `bash tests/api-breach-readiness.sh`.
- In the Phase 4 environment, runtime readiness was not executed successfully
  because `opsn-api` was not available at `http://localhost:8025`.
- Do not push or PR unless explicitly asked.

Recommended next work:
1. Start a fresh session before any publish, review, PR, or follow-up scope.
2. Review git status before staging anything.
3. Preserve unrelated dirty worktree changes.
4. Do not stage `docs/superpowers/.DS_Store`.
5. Do not push or open a PR unless explicitly asked.

Preserve unrelated dirty worktree changes. Do not stage `.DS_Store` unless the
user explicitly asks.
```
