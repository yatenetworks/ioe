# Template Validation

IOE may support template validation for AI application environments.

The goal is to help contributors check whether an application template is complete, safe, and predictable before use.

Future validation may check:

- required fields
- template_version
- module_id format
- lifecycle_mode
- declared capabilities
- resource requirements
- healthcheck
- security policy
- recovery policy
- cleanup policy

Example future command:

    ioectl validate module module.yaml

Current boundary:

This is a validation direction only.

It does not deploy applications.

It does not run containers.

It does not contact servers.

It does not manage accounts, payments, networking infrastructure, or multi-server orchestration.
