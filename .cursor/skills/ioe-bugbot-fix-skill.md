---
name: ioe-bugbot-fix-skill
description: Fix Bugbot findings on IOE public PRs with minimal scoped changes
---

# Skill: fix Bugbot findings

## Rules

- **High / Medium** must be fixed before merge (or explicitly escalated to the user).
- **Low** may be deferred with a short note (PR, handoff, or deferred list).
- **Minimal fix only** — no broad refactor unless explicitly requested.
- Do not modify installer, runtime, or unrelated files unless the finding requires it.
- Respect public boundary and wording rules in `.cursorrules`.

## Checks

From repo root:

```bash
scripts/check-public-pr.sh
```

Run `scripts/check-template-lifecycle.sh <module_id>` only if the Bugbot item or task explicitly requires lifecycle validation.

## Commit and push

- Push and report when the user asked for commit/push and checks pass.

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
