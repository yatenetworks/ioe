---
name: ioe-handoff-skill
description: Update local IOE session handoff for the next agent or ChatGPT
---

# Skill: update local task memory

## Rules

- Use `scripts/update-local-handoff.sh` from the repository root.
- Ensure `LOCAL_SESSION_HANDOFF.md` is **gitignored** before writing (the script enforces this).
- **Never** stage or commit `LOCAL_SESSION_HANDOFF.md`.

## Handoff should include

- branch
- latest commit
- files changed (this session)
- tests/checks run and pass/fail
- CI / Bugbot status
- unresolved risks
- next safe step

Edit the generated file to fill optional sections (open PR, notes) when known.

## When to run

- Task start (after reading `.cursorrules` and `docs/CURSOR_WORKFLOW.md`)
- Before stop, branch switch, repo switch, or ~80–85% context

## Final report (required)

End with:

- **Branch**
- **Latest commit**
- **Files changed**
- **Tests/checks run**
- **Results**
- **Remaining risks**
- **PR readiness**
- **Low items deferred**
- **Handoff updated:** yes/no
