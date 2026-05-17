# Local Module Lifecycle Preview

This document describes the public preview direction for IOE local module templates.

The current public focus is not a full platform. The current focus is a small local lifecycle for AI application environment templates.

## Concept

A local module template describes a small application environment with a manifest file and supporting files.

The intended lifecycle is:

```text
validate → install → start → status → logs → stop → remove
```

Example command shape:

```bash
ioectl validate module <module.yaml>
ioectl module install <module.yaml>
ioectl module start <module_id>
ioectl module status <module_id>
ioectl module logs <module_id>
ioectl module stop <module_id>
ioectl module remove <module_id>
```

## Automation-friendly preview direction

Local lifecycle commands should support structured output where it matters:

```bash
ioectl validate module <module.yaml> --json
ioectl module status <module_id> --json
```

Non-interactive runs should not block waiting for input. Safe defaults should be used, and destructive operations should require explicit confirmation flags.

## State model

A local module may pass through states such as:

```text
validating
installing
pulling_images
pulling_assets
initializing
starting
healthchecking
healthy
failed
stopped
```

This helps users see where a long-running setup is spending time.

## Current boundary

This is an early public preview direction.

The public installer is not active yet.

This document does not describe a production platform, hosted service, account system, payment system, or multi-server management system.

## What a local module should provide

A local module should provide:

- a `module.yaml` manifest
- a Docker Compose file when containers are used
- an `.env.example` file when configuration is needed
- clear port declarations
- predictable data paths
- model declarations when model assets are needed
- log source declarations where possible
- a basic health check
- safe stop and remove behavior

## Safety direction

Templates should:

- avoid hardcoded secrets
- avoid root requirements by default
- avoid privileged containers
- declare ports clearly
- include health checks
- declare log sources where possible
- use predictable data paths
- preserve persistent data by default
- document any public exposure

## Data layout direction

Local templates should use paths such as:

```text
~/ioe-data/apps/<module_id>/
~/ioe-data/backups/<module_id>/
~/ioe-data/models/
```

## Next public milestone

The next public milestone should be a tested local preview installer that can prepare dependencies and run local template validation on a clean Linux server.
