# Module Manifest Draft

This is an early public-safe draft for describing installable AI application modules.

The goal is to make AI application environments easier to validate, install, back up, restore, and maintain.

This draft is not a final public API.

## Basic Fields

A module manifest may include:

- module_id
- template_version
- name
- description
- source
- license
- capabilities
- resource_profile
- lifecycle_mode
- healthcheck
- security_policy
- recovery_policy
- cleanup_policy

## Lifecycle Modes

Supported lifecycle modes:

- ephemeral
- standby
- persistent
- critical

## Data Layout

Persistent data should follow the IOE data layout:

- ~/ioe-data/apps/<module_id>/
- ~/ioe-data/backups/<module_id>/
- ~/ioe-data/models/

## Safety Rules

AI application templates should not require root access by default.

Templates should avoid hardcoded secrets.

Templates should declare required ports, volumes, and health checks clearly.

## Current Status

This is an early draft.

The current public project remains focused on installer foundations and application template policy.
