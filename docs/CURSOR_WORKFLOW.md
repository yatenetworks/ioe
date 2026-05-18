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

## Tracked vs local Cursor files

- **`.cursor/`** is local IDE configuration and **must not be committed** in this public repo (see `.gitignore`).
- **Tracked workflow guidance** lives in:
  - `.cursorrules`
  - `docs/CURSOR_WORKFLOW.md` (this file)
  - `docs/CURSOR_TASK_SKILLS.md`
- **`LOCAL_SESSION_HANDOFF.md`** is local-only and **must not be committed** (gitignored).
- Optional local copies under `.cursor/rules/` or `.cursor/skills/` may help on your machine; they are not part of the public repository.

## Model selection (IOE)

| Default (Auto / Composer 2) | Escalate (stronger model) |
|-----------------------------|-----------------------------|
| Routine implementation, docs, templates | Installer, root/sudo, shell safety, remote downloads |
| Local checks, small Bugbot fixes | ioectl core, remove/data deletion, Docker cleanup, lifecycle state |
| | Bugbot **High**; **Medium** after one focused fix attempt |
| | Same test fails **twice** |
| | Public/private boundary or positioning |
| | Architecture decisions (not routine implementation) |

If **two focused attempts** fail on Auto, stop looping: summarize state, run `scripts/update-local-handoff.sh`, and ask for escalation or human review.

See also `.cursorrules` §8.

## Stalled command recovery

When Cursor appears stuck during a long task, **inspect and continue** — do not restart from scratch unless state inspection shows it is safe.

### Expected slow operations

These may look stuck but are often normal:

- Docker image pull / extraction
- `npm` / `pip` install
- First start of a model or app runtime
- Template lifecycle healthcheck (including retries)
- Network downloads

### Inspect before stop or retry

| Check | Command / source |
|-------|------------------|
| Git state | `git status --short` |
| Processes | running process summary if available |
| Docker | `docker ps`, compose state when relevant |
| Logs | recent terminal output; `ioectl module logs <id>` for templates |

### Do not restart from scratch

Continue from the current branch, commits, and partial work unless inspection shows a clean reset is safe.

### Resume after manual stop

1. Read `.cursorrules`, this file, `docs/CURSOR_TASK_SKILLS.md`
2. Read `LOCAL_SESSION_HANDOFF.md` if present
3. Run `scripts/update-local-handoff.sh`
4. Run `git status --short`
5. Summarize state and continue from current git state

### Interrupted lifecycle tests

- `scripts/check-template-lifecycle.sh` cleans up on failure after `start` (see script `NEED_CLEANUP` trap).
- If unsure, best-effort from `public-runnable-preview`:

```bash
./ioectl module stop <module_id> || true
./ioectl module remove <module_id> || true
```

Confirm no leftover `ioe-*` test containers before retry.

### Two failures on the same command/test

Stop looping → update handoff → short diagnostic report → recommend model escalation or review (see [Model selection](#model-selection-ioe)).

See `.cursorrules` §9 and [CURSOR_TASK_SKILLS.md](CURSOR_TASK_SKILLS.md) (stalled recovery).

## Auto-run and Cursor UI

Auto-run depends partly on **Cursor UI settings** (Agent/Terminal auto-run, command allowlist).

**Recommended behavior:**

- Safe checks: run automatically (git status, `scripts/check-public-pr.sh`, `scripts/update-local-handoff.sh`, etc.).
- Destructive, root, Docker lifecycle, merge, force-push, branch deletion, and tag/release actions: confirmation-gated.

## Auto-run routine checks

Cursor should run routine **safe** checks directly when command execution is available.

**Do not** ask the user to manually run routine checks such as:

- `git status --short`
- `git diff --stat`
- `git log --oneline`
- `bash -n` checks
- `python3 -m py_compile`
- `scripts/check-public-pr.sh`
- `scripts/update-local-handoff.sh`
- grep-based public-safe / secret checks
- `ioectl validate module` checks

**Ask for confirmation** only for:

- root-only commands
- `sudo`
- destructive commands
- Docker lifecycle start/stop/remove (default)
- branch deletion
- force push
- `reset --hard`
- `clean -fdx`
- release/tag actions
- merge actions
- package installs or remote script downloads (`curl | bash`, etc.)

**Template lifecycle (Docker):** opt-in by default. If the task **explicitly** asks for lifecycle validation, Cursor should run:

```bash
scripts/check-template-lifecycle.sh <module_id>
```

instead of pasting install/start/status/logs/stop/remove commands for the user to run.

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

This uses Docker and is **not** part of the default PR script. Use it **only when lifecycle validation is explicitly requested**.

On failure after `start`, the script runs best-effort `stop`/`remove` so containers are less likely to be left behind.

## Local handoff script

From repo root (no root, no network):

```bash
scripts/update-local-handoff.sh
```

Writes or overwrites `LOCAL_SESSION_HANDOFF.md` with branch, commit, status, and recent log. The file must stay **local** and must **never** be committed (gitignored).

Cursor should run this at task start (after reading rules/docs/handoff) and again before stop, branch switch, or ~80–85% context.

## Bugbot and merge policy

- **Medium / High** Bugbot findings block merge until fixed or explicitly escalated.
- **Low** items (e.g. duplicated helper functions) may be deferred and recorded (e.g. v0.9 refactor) if called out in the PR or handoff notes.

## Session handoff (local only)

- File: `LOCAL_SESSION_HANDOFF.md` at the repo root
- **Gitignored** — never stage or commit

### Session start (required)

1. Read `.cursorrules`
2. Read this file (`docs/CURSOR_WORKFLOW.md`)
3. Read `docs/CURSOR_TASK_SKILLS.md`
4. Read `LOCAL_SESSION_HANDOFF.md` if present
5. Run `scripts/update-local-handoff.sh`
6. Read `README.md` and task-specific docs as needed
7. Do not apply private-repo strategy wording here

### Before stop / branch or repo switch / ~80–85% context

Run `scripts/update-local-handoff.sh`, then fill in notes below as needed:

| Field | Content |
|-------|---------|
| repo | e.g. `yatenetworks/ioe` |
| branch | current branch name |
| latest commit | short SHA + subject |
| open PR | URL or title if known |
| files changed | summary of this session |
| tests/checks run | commands and pass/fail |
| Bugbot/CI status | open items |
| unresolved risks | blockers |
| next safe step | one concrete action |

## Final report (every Cursor task)

End with:

- Branch
- Latest commit
- Files changed
- Tests/checks run
- Results
- Remaining risks
- PR readiness
- Low items deferred
- Handoff updated: yes/no

## Cursor UI limitation

Some terminal approvals are controlled by Cursor settings. If automatic execution is blocked by Cursor UI settings, enable safe Agent/Terminal auto-run or command allowlist settings. Keep destructive, root, Docker lifecycle, force-push, branch deletion, and merge actions approval-gated.

## IOE task skills

Tracked in [CURSOR_TASK_SKILLS.md](CURSOR_TASK_SKILLS.md). Use when the user names a skill or the task clearly matches:

| Skill | When to use |
|-------|-------------|
| IOE template skill | Add or update **one** AI app template (draft/testing, local ports, checks, lifecycle only if requested) |
| IOE Bugbot fix skill | Fix **Bugbot** Medium/High (minimal diff); record deferred Low items |
| IOE PR review skill | **Pre-merge review** — output **OK to merge** or **Do not merge** |
| IOE handoff skill | Refresh **LOCAL_SESSION_HANDOFF.md** via `scripts/update-local-handoff.sh` |

Trigger phrases in `.cursorrules`: “use IOE template skill”, “use Bugbot fix skill”, “use PR review skill”, “update handoff”.

## Related docs

- [AI app template contribution guide](AI_APP_TEMPLATE_CONTRIBUTION_GUIDE.md)
- [Compatibility report guide](COMPATIBILITY_REPORT_GUIDE.md)
- [Template review checklist](TEMPLATE_REVIEW_CHECKLIST.md)
