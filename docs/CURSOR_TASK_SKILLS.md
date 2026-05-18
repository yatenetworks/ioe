# IOE Cursor task skills (public repository)

Routine task guidance for Cursor on the **public** IOE repository. Keep work **low-key**, **practical**, and **public-safe**. Do not add long-term strategy, production-ready claims, or grand platform language.

Tracked workflow docs: `.cursorrules`, [CURSOR_WORKFLOW.md](CURSOR_WORKFLOW.md), this file. The `.cursor/` directory is **local IDE configuration** and must **not** be committed.

When the user names a skill (see trigger phrases below), follow the matching section.

---

## IOE template skill

**Use when:** adding or updating **one** AI application environment template.

### Rules

- **One template per task** — do not batch unrelated templates.
- Templates are **draft / testing** by default; do not mark verified without evidence.
- **No installer or runtime changes** unless explicitly requested.
- **Local-only ports by default**; prefer `127.0.0.1` bindings.
- **No secrets**, tokens, or private keys in the repo.
- **No public exposure** of unauthenticated services.
- Follow public wording rules in `.cursorrules` and PR Compliance.

### Checks

From repo root:

```bash
scripts/check-public-pr.sh
```

If lifecycle validation is **explicitly requested**:

```bash
scripts/check-template-lifecycle.sh <template_id>
```

### Commit and push

- Commit and push **only after** checks pass (when the user asked for commit/push).
- Do not stage or commit `LOCAL_SESSION_HANDOFF.md`.

---

## IOE Bugbot fix skill

**Use when:** fixing Bugbot findings on a public PR.

### Rules

- **High / Medium** must be fixed before merge (or explicitly escalated to the user).
- **Low** may be deferred with a short note (PR, handoff, or deferred list).
- **Minimal fix only** — no broad refactor unless explicitly requested.
- Do not modify installer, runtime, or unrelated files unless the finding requires it.
- Respect public boundary and wording rules in `.cursorrules`.

### Checks

From repo root:

```bash
scripts/check-public-pr.sh
```

Run `scripts/check-template-lifecycle.sh <module_id>` only if the Bugbot item or task explicitly requires lifecycle validation.

### Commit and push

- Push and report when the user asked for commit/push and checks pass.

---

## IOE PR review skill

**Use when:** pre-merge review; output a verdict ChatGPT and the user can act on.

### Review checklist

1. **Latest commit** — subject, scope, and whether it matches the PR goal.
2. **PR Compliance** — public-safe wording; no disallowed strategy or production-ready hype.
3. **Bugbot** — open Medium/High block merge; Low only if recorded.
4. **Boundary** — no internal long-term strategy in public docs.
5. **Risk scan** — installer, runtime, template exposure, secrets, port bindings, destructive lifecycle.

### Checks (when command execution is available)

```bash
scripts/check-public-pr.sh
git log -1 --oneline
git diff --stat origin/main...HEAD
```

Use `gh pr view` / CI status when a PR number or URL is known.

### Output (required)

Provide a clear verdict:

- **OK to merge** — brief rationale and any Low items deferred, or
- **Do not merge** — blockers (Bugbot, CI, boundary, risk) and next safe fix step.

---

## IOE handoff skill

**Use when:** updating local task memory for the next session or ChatGPT.

### Rules

- Run `scripts/update-local-handoff.sh` from the repository root.
- The script refuses to write if `LOCAL_SESSION_HANDOFF.md` is not gitignored.
- **Never** stage or commit `LOCAL_SESSION_HANDOFF.md`.

### Handoff should include

- branch
- latest commit
- files changed (this session)
- tests/checks run and pass/fail
- CI / Bugbot status
- unresolved risks
- next safe step

Edit the generated file for open PR and notes when known.

### When to run

- Task start (after reading `.cursorrules`, `docs/CURSOR_WORKFLOW.md`, and this file)
- Before stop, branch switch, repo switch, or ~80–85% context

---

## IOE stalled-task recovery (workflow)

**Use when:** a command times out, Cursor was stopped mid-task, or progress is unclear.

### Rules

1. **Stalled command** — decide if the operation is an expected long runner (docker pull, image extract, npm/pip install, first model/runtime start, lifecycle healthcheck, network download).
2. **Before stop/retry** — inspect `git status --short`, processes (if available), `docker ps` / compose when Docker is involved, recent logs, and template healthcheck/logs.
3. **No scratch restart** — do not redo the whole task unless inspection shows it is safe.
4. **After manual stop** — read `.cursorrules`, `docs/CURSOR_WORKFLOW.md`, this file, `LOCAL_SESSION_HANDOFF.md`; run `scripts/update-local-handoff.sh`; `git status --short`; summarize; continue from current git state.
5. **Interrupted lifecycle** — rely on `scripts/check-template-lifecycle.sh` cleanup; if uncertain, `ioectl module stop` / `remove` best-effort; verify no leftover test containers.
6. **Two failures** — stop looping, update handoff, short diagnostic report, recommend escalation or review.
7. **Model escalation** — default Auto/Composer for routine work; escalate on Bugbot High, Medium after one focused fix, same test fails twice, installer/runtime/ioectl/remove/data deletion/Docker cleanup, or public/private boundary (see `.cursorrules` §8).

### Checks (safe, run directly)

```bash
git status --short
scripts/update-local-handoff.sh
scripts/check-public-pr.sh
```

When Docker may be involved:

```bash
docker ps -a --format '{{.Names}}\t{{.Status}}' | grep -E '^ioe-' || true
```

---

## Trigger phrases

| User says | Follow section |
|-----------|----------------|
| use IOE template skill | IOE template skill |
| use Bugbot fix skill | IOE Bugbot fix skill |
| use PR review skill | IOE PR review skill |
| update handoff | IOE handoff skill |
| stalled recovery / continue task | IOE stalled-task recovery |

---

## Final report (every task)

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
