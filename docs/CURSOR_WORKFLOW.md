# Cursor workflow (public repository)

This document describes how IOE uses Cursor, ChatGPT, and human review together on the public repository.

## Roles

| Role | Responsibility |
|------|----------------|
| **Cursor** | Routine implementation, file edits, local checks, commit/push when asked, routine Bugbot fixes |
| **ChatGPT** | Roadmap, boundaries, risk judgment, key PR review, merge recommendation |
| **User** | Final confirmation and merge click on GitHub |

## Public repository rules

- Positioning: **IOE AI Env Installer** — AI application environment templates on clean Linux servers.
- Wording stays **low-key** and **public-safe**.
- Do **not** publish internal long-term strategy, production-ready claims, or grand platform language.
- Follow wording rules in `.cursorrules` and PR Compliance (same patterns as CI).

## Checks before opening or updating a PR

From the repository root (no root, no Docker):

```bash
scripts/check-public-pr.sh
```

This runs:

- `bash -n` on known shell scripts
- `python3 -m py_compile` on preview Python tools
- `ioectl validate` for every `public-runnable-preview/templates/modules/*/module.yaml`
- Public-safe wording grep
- Secret-like pattern grep

Requires `public-runnable-preview/.venv` (or system `jsonschema`) for validate steps.

## Optional template lifecycle test (Docker)

When changing a template or debugging lifecycle behavior:

```bash
scripts/check-template-lifecycle.sh <module_id>
```

Example:

```bash
scripts/check-template-lifecycle.sh qdrant.basic
```

This uses Docker and is **not** part of the default PR script. Run on a test machine when appropriate.

## Bugbot and merge policy

- **Medium / High** Bugbot findings block merge until fixed or explicitly escalated.
- **Low** items (e.g. duplicated helper functions) may be deferred and recorded (e.g. v0.9 refactor) if called out in the PR or handoff notes.

## Session handoff (local only)

- File: `LOCAL_SESSION_HANDOFF.md` at the repo root
- **Gitignored** — never commit
- Cursor updates it near session end or before switching branches (~80–85% context)
- Include: branch, latest commit, open PRs, test results, open Bugbot items, next safe step

## Session start (Cursor)

1. Read `.cursorrules`
2. Read `LOCAL_SESSION_HANDOFF.md` if present
3. Read `README.md` and task-specific docs as needed
4. Do not apply private-repo strategy wording in this repository

## Final report (every Cursor task)

End with:

- Branch
- Latest commit
- Files changed
- Tests/checks run
- Results
- Remaining risks
- Whether PR is ready
- Whether any Low items should be deferred

## Related docs

- [AI app template contribution guide](AI_APP_TEMPLATE_CONTRIBUTION_GUIDE.md)
- [Compatibility report guide](COMPATIBILITY_REPORT_GUIDE.md)
- [Template review checklist](TEMPLATE_REVIEW_CHECKLIST.md)
