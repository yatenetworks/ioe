# IOE AI Env Installer

> A lightweight open-source tool for validating, installing, running, inspecting, and safely removing AI application environment templates on clean Linux servers.

Project website: https://ioe.cc

IOE AI Env Installer, short for **IOE AI Application Environment Installer**, focuses on one practical problem:

> AI applications are becoming easier to build, but still too inconsistent to install and operate on clean servers.

Many self-hosted AI projects use their own setup steps, environment variables, ports, data paths, health checks, model files, logs, and update notes. That creates repeated work for both users and maintainers.

IOE aims to add a small, predictable lifecycle layer around existing tools such as Linux, Docker, Docker Compose, YAML, and schema validation.

IOE does **not** try to replace containers, package managers, application frameworks, cloud platforms, or existing open standards.

## Why this project exists

Self-hosted AI application setup is often harder than it should be:

- every project has a different README
- every project has different `.env` rules
- ports and data directories are often unclear
- model assets are often downloaded in one-off scripts
- health checks may be missing or inconsistent
- logs may be scattered across containers, scripts, or files
- install scripts are hard to re-run safely
- uninstall behavior may be unclear
- long-running setup steps can look stuck
- users are unsure where data, backups, and models are stored
- maintainers repeatedly answer the same installation questions

IOE exists to reduce that repeated work.

The goal is to make AI application environments easier to:

- validate
- install
- start
- inspect
- read logs from
- stop
- remove safely
- test on a clean Linux server

## Core idea

IOE standardizes a simple lifecycle for AI application environment templates:

```bash
ioectl validate module <module.yaml>
ioectl module install <module.yaml>
ioectl module start <module_id>
ioectl module status <module_id>
ioectl module logs <module_id>
ioectl module stop <module_id>
ioectl module remove <module_id>
```

The command names are intentionally simple. The value is not the CLI alone. The value is the common template structure, state model, data layout, and lifecycle behavior behind the CLI.

## Automation-friendly CLI behavior

IOE should be easy for both people and automation tools to drive.

Planned CLI behavior:

```bash
ioectl module status <module_id> --json
ioectl validate module <module.yaml> --json
ioectl module logs <module_id> --tail 100
ioectl module logs <module_id> --follow
```

JSON output should be strict, predictable, and easy to parse. Human-readable output is useful, but tools should not need to scrape terminal text to understand module state.

Non-interactive runs should never block waiting for input. If IOE detects that it is running from a script or other non-TTY environment, it should use safe defaults and fail clearly when confirmation is required.

## What IOE standardizes

IOE is intended to provide a lightweight structure for:

- module metadata
- predictable local data paths
- declared ports
- required environment variables
- basic resource requirements
- optional model asset declarations
- lifecycle hooks
- health checks
- logs
- status states
- safe lifecycle commands
- template validation
- local smoke testing
- contribution review rules

This helps contributors publish templates that are easier to review and helps users test templates more consistently.

## What IOE does not replace

IOE does not replace:

- Docker
- Docker Compose
- OCI container images
- Linux package managers
- existing application frameworks
- existing API specifications
- cloud providers
- backup systems

IOE reuses existing tools and adds a small installation lifecycle layer for AI application environments.

## Stable lifecycle, flexible adapters

IOE keeps the public core small so it does not need to be redesigned every time the AI ecosystem changes.

The stable public lifecycle is:

```bash
ioectl validate module <module.yaml>
ioectl module install <module.yaml>
ioectl module start <module_id>
ioectl module status <module_id>
ioectl module logs <module_id>
ioectl module stop <module_id>
ioectl module remove <module_id>
```

The tools behind this lifecycle may evolve through adapters. For example, IOE can support Docker Compose first and add other runtime adapters later without changing the basic lifecycle.

Read more:

- [Why IOE?](docs/WHY_IOE.md)
- [Module Template Standard](docs/MODULE_TEMPLATE_STANDARD.md)
- [Stability and Extension Policy](docs/STABILITY_AND_EXTENSION_POLICY.md)
- [Automation-Friendly CLI Standard](docs/AUTOMATION_FRIENDLY_CLI_STANDARD.md)
- [Adapter Interface Draft](docs/ADAPTER_INTERFACE_DRAFT.md)

## Standard state model

Long-running setup steps should not look like a frozen process. IOE modules should expose a small state model through `status`:

```text
new -> validating -> installing -> pulling_assets -> initializing -> starting -> healthchecking -> healthy
```

Failure and stop states should also be explicit:

```text
degraded
failed
stopping
stopped
removing
removed
```

This makes it easier for users and automation tools to see whether a module is downloading assets, initializing data, waiting for health checks, or actually failing.

## Standard data layout

IOE templates should use predictable local paths. The default data root is:

```text
~/ioe-data/
```

The default layout is:

```text
~/ioe-data/
├── apps/
│   └── <module_id>/
├── backups/
│   └── <module_id>/
└── models/
```

Application data should be placed under:

```text
~/ioe-data/apps/<module_id>/
```

Backups should be placed under:

```text
~/ioe-data/backups/<module_id>/
```

Model files should be placed under:

```text
~/ioe-data/models/
```

The data root should be configurable later, but the default must remain clear and predictable.

## Local runnable preview

An early **local preview / testing only** installer is available for supported Linux targets.

- tested on Debian 12, Ubuntu 22.04 LTS, and Ubuntu 24.04 LTS during private preview work
- local Docker-based module lifecycle preview
- install layout: `/opt/ioe-preview` with data under `/opt/ioe-data`
- lifecycle commands: validate, install, start, status, logs, stop, remove
- not a production installer, not a hosted service, and not a public roadmap commitment

Package and details:

- [public-runnable-preview/README.md](public-runnable-preview/README.md)
- [public-runnable-preview/docs/LOCAL_RUNNABLE_PREVIEW.md](public-runnable-preview/docs/LOCAL_RUNNABLE_PREVIEW.md)

Remote install entrypoint (run on a test VPS as root):

```bash
curl -fsSL https://raw.githubusercontent.com/yatenetworks/ioe/main/install-ioe.sh | bash
```

After install:

```bash
cd /opt/ioe-preview/public-runnable-preview
./install-ioe.sh
bash scripts/test-ioectl-lifecycle.sh
```

## Installer scripts

`install-ioe.sh` is the canonical remote install entrypoint for the local runnable preview (testing only).

`install.sh` is a compatibility wrapper that delegates to `install-ioe.sh`.

`public-runnable-preview/install-ioe.sh` is the package-internal script for local repair and self-check on an already extracted tree. It does not download the archive unless both `IOE_PREVIEW_URL` and `IOE_PREVIEW_SHA256` are set.

The preview installer:

- downloads and verifies the preview package
- installs Docker only when missing (using `apt-get` and `--no-install-recommends`)
- runs light validation only
- does not automatically start all modules
- is intended for early testing, not production deployment

## Public documentation

Start here:

- [Why IOE](docs/WHY_IOE.md)
- [Template ecosystem model](docs/TEMPLATE_ECOSYSTEM_MODEL.md)
- [Module template standard](docs/MODULE_TEMPLATE_STANDARD.md)
- [Module manifest draft](docs/MODULE_MANIFEST_DRAFT.md)
- [Template validation](docs/TEMPLATE_VALIDATION.md)
- [Automation-friendly CLI standard](docs/AUTOMATION_FRIENDLY_CLI_STANDARD.md)
- [Adapter interface draft](docs/ADAPTER_INTERFACE_DRAFT.md)
- [Application template policy](docs/APP_TEMPLATE_POLICY.md)
- [Local module lifecycle preview](docs/LOCAL_MODULE_RUNTIME_PREVIEW.md)
- [Local runnable preview package](public-runnable-preview/docs/LOCAL_RUNNABLE_PREVIEW.md)

Example files:

- [Example AI module manifest](examples/ai-module.example.yaml)
- [Example local module template](examples/local-module-template.example.yaml)

## Template contribution direction

A future IOE-compatible template should be simple to review:

```text
templates/modules/<module_id>/
├── module.yaml
├── docker-compose.yml
├── .env.example
├── README.md
└── healthcheck.sh
```

Contributors should avoid hardcoded secrets, unclear data paths, privileged containers, public database ports, and unsafe defaults.

## Design goals

IOE should be:

- small enough to inspect
- clear enough for new users
- useful for maintainers
- safe by default
- automation-friendly
- conservative with local system changes
