# Contributing

Thank you for your interest in contributing to IOE AI Env Installer.

This project is a simple open-source tool for setting up AI application environments on clean Linux servers.

## Contribution Scope

Useful contributions include:

- Installer script improvements
- Docker Compose templates
- Application template fixes
- Documentation improvements
- Security hardening
- Backup and restore improvements
- Compatibility testing on Linux distributions
- Bug reports with logs and reproduction steps

## Project Principles

Please keep changes aligned with these principles:

- Keep deployment simple
- Preserve user data
- Avoid unnecessary system changes
- Do not overwrite existing configuration without care
- Do not hardcode secrets
- Keep storage paths predictable
- Prefer clear logs and safe failure behavior
- Keep optional features disabled by default

## Data Path Contract

Application data must use:

```text
~/ioe-data/apps/<app_name>/
```

Backups must use:

```text
~/ioe-data/backups/<app_name>/
```

Models should use:

```text
~/ioe-data/models/
```

Do not introduce random Docker volumes or unclear host paths.

## Do Not Commit Secrets

Never commit:

- `.env`
- API keys
- SSH private keys
- Database passwords
- Cloud credentials
- Local user data
- `~/ioe-data`

## Code Checks

Before submitting changes, run checks when possible.

For shell scripts:

```bash
bash -n install-ioe.sh
```

For Python:

```bash
python -m py_compile $(find backend -name "*.py")
```

For frontend code, if Node.js is available:

```bash
npm run build
```

## Pull Request Guidelines

A good pull request should include:

- What changed
- Why it changed
- How it was tested
- Any compatibility notes
- Any security impact

Keep changes focused and easy to review.

## Application Templates

Application templates should follow:

```text
docs/APP_TEMPLATE_POLICY.md
```

Templates must not include hardcoded secrets or unsafe defaults.