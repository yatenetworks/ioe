# Contributing

Thank you for your interest in contributing to IOE AI Env Installer.

IOE focuses on a practical open-source goal:

> Make AI application environment templates easier to validate, install, run, inspect, and remove on clean Linux servers.

## Useful contributions

Useful contributions include:

- documentation improvements
- module template examples
- template validation rules
- automation-friendly CLI output examples
- model asset declaration examples
- log source declaration examples
- Docker Compose safety improvements
- clean-server test reports
- compatibility notes for Linux distributions
- security review suggestions
- bug reports with clear reproduction steps

## Project principles

Please keep changes aligned with these principles:

- keep the project simple to inspect
- preserve user data by default
- avoid unnecessary system changes
- avoid hardcoded secrets
- keep storage paths predictable
- prefer clear logs and safe failure behavior
- prefer structured output for automation-sensitive commands
- avoid blocking prompts in non-interactive contexts
- keep public examples low-risk and easy to test
- reuse existing tools instead of replacing them

## Data path contract

Application data should use:

```text
~/ioe-data/apps/<module_id>/
```

Backups should use:

```text
~/ioe-data/backups/<module_id>/
```

Models should use:

```text
~/ioe-data/models/
```

Do not introduce random Docker volumes or unclear host paths without a clear reason.

## Do not commit secrets

Never commit:

- `.env`
- API keys
- SSH private keys
- database passwords
- cloud credentials
- local user data
- `~/ioe-data`

Use `.env.example` with placeholders.

## Template contributions

A good module template should include:

```text
module.yaml
docker-compose.yml
.env.example
README.md
healthcheck.sh
```

Templates should follow:

```text
docs/APP_TEMPLATE_POLICY.md
docs/MODULE_TEMPLATE_STANDARD.md
docs/AUTOMATION_FRIENDLY_CLI_STANDARD.md
docs/ADAPTER_INTERFACE_DRAFT.md
```

Templates must not include hardcoded secrets or unsafe defaults.

## Pull request guidelines

A good pull request should explain:

- what changed
- why it changed
- how it was tested
- any compatibility notes
- any security impact
- whether persistent data behavior changed

Keep changes focused and easy to review.

## Script status

The public installer entry names are reserved as:

```text
install-ioe.sh
install.sh
```

At the current public documentation stage, these scripts should not perform server installation unless the repository README clearly marks the preview installer as active and tested.
