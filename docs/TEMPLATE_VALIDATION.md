# Template Validation

IOE template validation is intended to help contributors and users check a module template before running it.

Validation should catch common mistakes early.

## Why validation matters

AI application templates often fail for simple reasons:

- missing required fields
- invalid module identifiers
- unclear ports
- missing `.env.example`
- missing health check details
- unclear data paths
- unclear model asset requirements
- hardcoded secrets
- unsafe Docker Compose settings
- missing license information
- unclear remove behavior

A template should be reviewed before it is installed on a server.

## Planned validation command

```bash
ioectl validate module <module.yaml>
```

Validation should be local and predictable.

It should not contact remote services unless a future command explicitly says so.

Structured output should be available:

```bash
ioectl validate module <module.yaml> --json
```

## Validation may check

- `module_id` format
- `template_version`
- required metadata
- license field
- source declaration
- runtime adapter declaration
- Docker Compose file presence for Compose modules
- resource profile
- port declarations
- storage paths
- model declarations
- lifecycle hooks
- health check definitions
- log source declarations
- unsafe secret patterns
- use of privileged containers
- use of Docker socket
- public database exposure
- cleanup policy
- non-interactive destructive behavior

## Model validation

Model declarations may be checked for:

- required fields
- safe target paths under `~/ioe-data/models/`
- path traversal attempts
- estimated disk usage
- optional accelerator requirements
- checksum format when provided

Early public implementations may validate model metadata before implementing automatic model download.

## Health check validation

Health checks may be checked for:

- supported check types
- valid URLs or ports
- timeout values
- `all` or `any` logic
- required local scripts
- safe command usage

## JSON validation result

A validation result should be easy to parse:

```json
{
  "valid": false,
  "module_id": "text.demo.basic",
  "template_version": 1,
  "errors": [
    {
      "code": "missing_healthcheck",
      "message": "No health check was declared."
    }
  ],
  "warnings": []
}
```

## Validation should not mean approval

Passing validation means the template has a complete and reviewable structure.

It does not guarantee:

- production readiness
- application security
- upstream code safety
- legal suitability for every use case
- compatibility with every Linux distribution

Users and maintainers should still review the template and upstream project.

## Current boundary

This repository is currently focused on public documentation and template standardization.

An active public installer will be added only after clean-server testing.
