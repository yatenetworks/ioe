---
name: ioe-template-skill
description: Add or update one IOE AI app template in the public repo
---

# Skill: add or update one IOE AI app template

## Rules

- **One template per task** — do not batch unrelated templates.
- Templates are **draft / testing** by default; do not mark verified without evidence.
- **No installer or runtime changes** unless explicitly requested.
- **Local-only ports by default**; prefer `127.0.0.1` bindings.
- **No secrets**, tokens, or private keys in the repo.
- **No public exposure** of unauthenticated services.
- Follow public wording rules in `.cursorrules` and PR Compliance.

## Checks

From repo root:

```bash
scripts/check-public-pr.sh
```

If lifecycle validation is **explicitly requested**:

```bash
scripts/check-template-lifecycle.sh <template_id>
```

## Commit and push

- Commit and push **only after** checks pass (when the user asked for commit/push).
- Do not stage or commit `LOCAL_SESSION_HANDOFF.md`.

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
