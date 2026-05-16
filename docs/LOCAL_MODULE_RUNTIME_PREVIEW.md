# Local Module Runtime Preview

This is an early preview of IOE's local module template direction.

The current public project remains focused on documentation, installer foundations, and AI application environment templates.

## Concept

A local module template describes a small application environment using a manifest file.

A future local workflow may include:

- validate a module template
- install the template files locally
- start the local application environment
- check basic health status
- stop the local application environment

Example lifecycle:

    validate → install → start → status → stop

## Current Boundary

This is an early preview.

It is not a production-ready runtime.

It does not provide multi-server orchestration.

It does not manage accounts, payments, networking infrastructure, or external services.

## Safety Direction

Templates should:

- avoid hardcoded secrets
- avoid root requirements by default
- declare ports clearly
- include health checks
- use predictable data paths
- support safe backup and restore planning

## Data Layout Direction

Future local templates should use predictable paths such as:

    ~/ioe-data/apps/<module_id>/
    ~/ioe-data/backups/<module_id>/
    ~/ioe-data/models/
