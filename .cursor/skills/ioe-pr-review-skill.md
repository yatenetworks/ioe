---
name: ioe-pr-review-skill
description: Pre-merge review for IOE public PRs (ChatGPT-ready verdict)
---

# Skill: pre-merge review

## Rules

Review the current branch / PR for merge readiness:

1. **Latest commit** — subject, scope, and whether it matches the PR goal.
2. **PR Compliance** — public-safe wording; no disallowed strategy or production-ready hype.
3. **Bugbot** — open Medium/High block merge; Low only if recorded.
4. **Public / private boundary** — no internal long-term strategy leaked into public docs.
5. **Risk scan** — installer, runtime, template exposure, secrets, port bindings, destructive lifecycle.

## Checks (when command execution is available)

```bash
scripts/check-public-pr.sh
git log -1 --oneline
git diff --stat origin/main...HEAD
```

Use `gh pr view` / CI status when a PR number or URL is known.

## Output (required)

Provide a clear verdict for ChatGPT and the user:

- **OK to merge** — with brief rationale and any Low items deferred, or
- **Do not merge** — list blockers (Bugbot, CI, boundary, risk) and the next safe fix step.

Also include the standard IOE final report fields:

- Branch, Latest commit, Files changed, Tests/checks run, Results, Remaining risks, PR readiness, Low items deferred, Handoff updated
