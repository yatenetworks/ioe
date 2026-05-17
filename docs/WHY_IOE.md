# Why IOE?

AI applications are becoming easier to build, but they are still difficult to install, test, and run consistently on clean Linux servers.

The problem is not that the world needs another single-purpose install script. The problem is that every AI application tends to invent its own installation shape.

IOE focuses on a narrow layer:

> A common lifecycle for AI application environment templates.

## The pain today

Self-hosted AI application setup often includes:

- different installation steps for every project
- different `.env` files and variable names
- unclear default ports
- unclear data directories
- model downloads hidden inside custom scripts
- missing or inconsistent health checks
- logs spread across containers, files, or commands
- Docker Compose files that are hard to reuse safely
- install scripts that are not easy to re-run
- long-running setup steps that look frozen
- unclear uninstall behavior
- manual troubleshooting after each failed setup
- documentation that can drift away from actual behavior

Experienced operators can work through these problems, but they still lose time.

New users often get blocked by them.

Maintainers also lose time because they must explain the same setup problems repeatedly.

## Why not just write a CLI for each project?

A project-specific CLI can help one application, but it does not create a shared standard.

When every project writes its own CLI or install script, users still need to learn a new setup process each time.

IOE aims to make the common parts reusable:

```bash
ioectl validate module <module.yaml>
ioectl module install <module.yaml>
ioectl module start <module_id>
ioectl module status <module_id>
ioectl module logs <module_id>
ioectl module stop <module_id>
ioectl module remove <module_id>
```

The CLI is only the entry point. The larger goal is a consistent module template format that contributors can review, test, and improve together.

## What IOE adds

IOE adds a small lifecycle layer around existing tools.

It can standardize:

- module metadata
- expected files
- declared ports
- required resources
- environment variable documentation
- model asset declarations
- lifecycle hooks
- data and backup paths
- log access
- health check behavior
- status states
- validation rules
- local smoke testing
- safe remove behavior

This makes AI application templates easier to compare, test, and maintain.

## Automation-friendly by design

IOE should be easy to use from a terminal and easy to call from scripts.

For automation, IOE should support predictable structured output:

```bash
ioectl module status <module_id> --json
ioectl validate module <module.yaml> --json
```

When IOE is run without an interactive terminal, it should not wait for prompts. It should use safe defaults and fail clearly when a required confirmation cannot be provided.

This avoids fragile text parsing and makes IOE easier to integrate into other tools.

## Model assets should be visible

Many AI applications depend on model files. Without a shared place to declare them, each project tends to hide model preparation inside custom scripts.

IOE templates should be able to describe model assets in `module.yaml` so validation can reason about disk, memory, and optional accelerator requirements before installation starts.

The first public version should treat model declarations conservatively. Download behavior should be explicit, reviewable, and safe by default.

## Logs are part of the lifecycle

Troubleshooting is part of real deployment.

Users should not need to know whether a module uses Docker Compose logs, container logs, local process logs, or application log files.

A standard command should provide one entry point:

```bash
ioectl module logs <module_id> --tail 100
ioectl module logs <module_id> --follow
```

The adapter can decide how to collect logs behind the scenes.

## What IOE does not replace

IOE should not rewrite mature tools or standards.

IOE does not replace:

- Linux
- Docker
- Docker Compose
- OCI images
- YAML
- schema validation
- application frameworks
- package managers
- cloud platforms

Instead, IOE reuses these tools and defines a small lifecycle standard above them.

## Why this can help the community

A shared template lifecycle helps both sides.

For users:

- fewer one-off commands
- clearer paths and ports
- easier clean-server testing
- easier troubleshooting
- predictable logs
- less fear of removing the wrong data

For maintainers:

- fewer repeated install questions
- clearer contribution rules
- easier template review
- easier smoke testing
- less custom installer code
- a lower barrier for existing Docker Compose projects

## The first useful target

The first practical target is simple:

> Make existing Docker Compose based AI application projects easier to wrap as IOE modules with a small `module.yaml` file.

This allows existing projects to keep their normal Compose files while gaining a predictable lifecycle, data layout, validation, logs, and health checks.

## Current boundary

IOE is an early public standard and preview direction.

The current public goal is not to claim production readiness. The goal is to make local AI application environment templates easier to validate, install, inspect, run, and remove safely.
