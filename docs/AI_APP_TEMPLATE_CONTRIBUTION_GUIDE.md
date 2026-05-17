# AI app template contribution guide

IOE uses reusable **AI application environment templates** to make local deployment and testing more consistent on clean Linux servers.

This guide is for contributors who want to add or improve a template in the public repository. It applies to the **local runnable preview** and **testing preview** direction—not a hosted service or production installer guarantee.

## Core principles

- Templates should use the IOE lifecycle where possible.
- Templates should be testable with: validate, install, start, status, logs, stop, remove.
- Templates should avoid hidden side effects, undisclosed downloads, or unclear scripts.
- Templates must not include secrets (use `.env.example` with placeholders only).
- Templates must preserve user data unless explicitly documented otherwise.
- **Remove** must be safe and non-destructive by default.
- New templates start as **draft/testing** before they are considered **tested** or **verified**.

## Recommended template structure

A simple Docker-based template often includes:

```text
module.yaml
docker-compose.yml
README.md
healthcheck.sh
.env.example
```

Optional adapter notes may be included when documented in `module.yaml` and easy to review.

Follow [MODULE_TEMPLATE_STANDARD.md](MODULE_TEMPLATE_STANDARD.md) and [APP_TEMPLATE_POLICY.md](APP_TEMPLATE_POLICY.md).

## Lifecycle requirements

Contributors should verify these commands on a clean test system when possible:

```bash
ioectl validate module <module.yaml>
ioectl module install <module.yaml>
ioectl module start <module_id>
ioectl module status <module_id>
ioectl module logs <module_id>
ioectl module stop <module_id>
ioectl module remove <module_id>
```

Automation-friendly output (`--json` where supported) should remain predictable. Non-interactive runs should not block on prompts.

## Template states

| State | Meaning |
|-------|---------|
| **draft** | Early work; may be incomplete; not recommended for general users |
| **tested** | Lifecycle exercised on at least one supported OS (e.g. Debian 12, Ubuntu 22.04/24.04) |
| **verified** | Reviewed; tested on supported targets; compatibility report available; safe data handling and health checks documented |

### Draft

- May be written manually or with LLM assistance
- Not listed as ready for general use
- May lack full lifecycle coverage or compatibility notes

### Tested

- Contributor or maintainer ran the lifecycle on at least one supported OS
- Known limitations are documented in the template README
- A [compatibility report](COMPATIBILITY_REPORT_GUIDE.md) issue is encouraged

### Verified

- Maintainer review completed (see [TEMPLATE_REVIEW_CHECKLIST.md](TEMPLATE_REVIEW_CHECKLIST.md))
- Tested on supported OS targets where practical
- At least one compatibility report on file for the template revision
- Safe removal behavior confirmed (user data not deleted by default)
- Health check and ports documented clearly

## How to contribute

1. Open a **Template contribution proposal** issue (or link an existing discussion).
2. Open a pull request with the template files and a clear test summary.
3. Sign off commits per [DEVELOPER_CERTIFICATE_OF_ORIGIN.md](../DEVELOPER_CERTIFICATE_OF_ORIGIN.md).
4. Follow [THIRD_PARTY_POLICY.md](../THIRD_PARTY_POLICY.md) for upstream code and assets.

If you only want to suggest an app without submitting files, use the **AI app template request** issue template instead.

## LLM-assisted drafting

LLMs may help draft templates by reading upstream README files, Compose files, Dockerfiles, and `.env.example` files.

**LLM-generated templates must be treated as draft/unverified** until a human runs the lifecycle on a real system, reviews security defaults, and files a compatibility report where appropriate.

Do not commit generated secrets, private URLs, or unreviewed download scripts.

## Review expectations

Maintainers use:

- [TEMPLATE_REVIEW_CHECKLIST.md](TEMPLATE_REVIEW_CHECKLIST.md)
- [SECURITY_REVIEW_CHECKLIST.md](SECURITY_REVIEW_CHECKLIST.md)
- [DEPENDENCY_POLICY.md](DEPENDENCY_POLICY.md)

Keep pull requests focused and easy to inspect.

## What this guide does not cover

- Multi-server orchestration
- Account billing or authentication systems
- Central template catalog or listing features
- Production installer guarantees

IOE’s public focus remains a small, reviewable **AI application environment template** layer for local testing and self-hosted use.
