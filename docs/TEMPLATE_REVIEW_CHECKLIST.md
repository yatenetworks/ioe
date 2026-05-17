# Template Review Checklist

Use this checklist when reviewing AI application environment module templates and examples.

## Required files

- [ ] `module.yaml` exists and matches [MODULE_TEMPLATE_STANDARD.md](MODULE_TEMPLATE_STANDARD.md).
- [ ] `docker-compose.yml` exists and is readable.
- [ ] `.env.example` exists with placeholders only.
- [ ] `README.md` explains ports, data paths, models, and logs.
- [ ] `healthcheck.sh` exists and is safe to run locally.

## module.yaml

- [ ] Module id and version are clear.
- [ ] Declared scripts and services match actual files.
- [ ] Data and model paths follow `~/ioe-data/...` conventions.
- [ ] No hardcoded secrets or production URLs that imply private infrastructure.

## docker-compose.yml

- [ ] Services have clear names and purposes.
- [ ] Image tags are explicit where practical.
- [ ] Ports are documented in README.
- [ ] No unnecessary host privileges or Docker socket mounts.
- [ ] Databases and internal services are not published publicly by default.

## Environment and data

- [ ] `.env.example` documents every required variable.
- [ ] Persistent data paths are predictable.
- [ ] `remove` does not delete user data by default.
- [ ] Backup path behavior is documented when relevant.

## Models and assets

- [ ] Model requirements are declared, not bundled as restricted files.
- [ ] Download steps include license or usage notes when applicable.
- [ ] Large assets are not committed to git without maintainer approval.

## Health and logs

- [ ] Health check verifies a meaningful ready state.
- [ ] Logs are reachable through documented commands or paths.
- [ ] Health checks and logs do not expose secrets.

## Security defaults

- [ ] Safe defaults for non-interactive use.
- [ ] No `chmod 777`, open admin ports, or default weak passwords.
- [ ] README warns about firewall and exposure when ports are used.

## Automation

- [ ] Template can be validated without manual prompts.
- [ ] Status and validation examples align with [AUTOMATION_FRIENDLY_CLI_STANDARD.md](AUTOMATION_FRIENDLY_CLI_STANDARD.md).

## AI app template status (community contributions)

- [ ] Template README states **draft**, **tested**, or **verified** (see [AI_APP_TEMPLATE_CONTRIBUTION_GUIDE.md](AI_APP_TEMPLATE_CONTRIBUTION_GUIDE.md)).
- [ ] **Draft** templates are not described as ready for general users.
- [ ] **Tested** templates note at least one supported OS where lifecycle was run.
- [ ] **Verified** templates link to or reference a compatibility report where applicable.
- [ ] Contribution matches [AI_APP_TEMPLATE_CONTRIBUTION_GUIDE.md](AI_APP_TEMPLATE_CONTRIBUTION_GUIDE.md) lifecycle and data-safety rules.

## Policy alignment

- [ ] Follows [APP_TEMPLATE_POLICY.md](APP_TEMPLATE_POLICY.md).
- [ ] Complies with [ACCEPTABLE_USE.md](../ACCEPTABLE_USE.md) and [THIRD_PARTY_POLICY.md](../THIRD_PARTY_POLICY.md).
