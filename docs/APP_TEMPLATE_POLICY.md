# Application Template Policy

This policy describes expectations for IOE-compatible AI application environment templates.

The goal is to make templates easier to review, test, and run safely on clean Linux servers.

## Template goals

A template should be:

- easy to inspect
- easy to validate
- easy to run locally
- clear about ports
- clear about data paths
- clear about model assets
- clear about logs
- clear about health checks
- conservative with host changes
- safe to remove without deleting persistent data by default

## Required direction

Templates should follow the IOE lifecycle:

```bash
ioectl validate module <module.yaml>
ioectl module install <module.yaml>
ioectl module start <module_id>
ioectl module status <module_id>
ioectl module logs <module_id>
ioectl module stop <module_id>
ioectl module remove <module_id>
```

Templates should be automation-friendly and should not require manual prompts during validation.

## Expected files

A simple template should include:

```text
module.yaml
docker-compose.yml
.env.example
README.md
healthcheck.sh
```

Additional scripts may be included when needed, but they should be declared in `module.yaml` and easy to review.

## Data and model paths

Templates should use the IOE data layout:

```text
~/ioe-data/apps/<module_id>/
~/ioe-data/backups/<module_id>/
~/ioe-data/models/
```

Templates should not write persistent data into unclear locations.

Model assets should be declared in `module.yaml` when possible.

## Logs

Templates should declare log sources where possible:

```yaml
logging:
  default_tail: 100
  sources:
    - type: docker-compose
      service: app
```

Users should be able to inspect logs through:

```bash
ioectl module logs <module_id> --tail 100
```

## Safety rules

Templates should avoid:

- hardcoded secrets
- public database ports by default
- privileged containers unless clearly justified
- broad host volume mounts
- hidden background services
- unreviewed binary downloads
- destructive cleanup by default
- changing firewall rules without explicit documentation

## Remove behavior

`remove` should preserve persistent user data by default.

Destructive cleanup must require explicit confirmation, such as:

```bash
ioectl module remove <module_id> --delete-data --confirm <module_id>
```

In non-interactive mode, destructive cleanup should be rejected unless explicit confirmation flags are present.

## Review checklist

Before a template is accepted, reviewers should check:

- license clarity
- source clarity
- port declarations
- environment variables
- data path behavior
- model asset declarations
- health check behavior
- log source behavior
- Docker Compose safety
- secret handling
- uninstall behavior
- clean-server test notes

## Current boundary

This is a public template policy draft.

It is not a production guarantee and not a promise that every field is final.

The immediate goal is to make local AI application environment templates easier to review and test.
