# Module Template Standard

This document describes the public IOE module template direction.

The standard is intentionally small. It should make common AI application environment templates easier to validate, install, run, inspect, and remove without replacing existing tools.

## Minimal template directory

A simple IOE module template should look like this:

```text
templates/modules/<module_id>/
├── module.yaml
├── docker-compose.yml
├── .env.example
├── README.md
└── healthcheck.sh
```

Additional files may be added when needed, but the minimal shape should stay easy to inspect.

## Stable lifecycle

IOE standardizes these commands:

```bash
ioectl validate module <module.yaml>
ioectl module install <module.yaml>
ioectl module start <module_id>
ioectl module status <module_id>
ioectl module logs <module_id>
ioectl module stop <module_id>
ioectl module remove <module_id>
```

These commands should remain stable. New commands may be added later, but existing command names should not be changed casually.

## Automation-friendly output

Commands that report state or validation results should support structured output:

```bash
ioectl validate module <module.yaml> --json
ioectl module status <module_id> --json
ioectl module logs <module_id> --tail 100 --json
```

Human-readable output is useful for terminals. JSON output is useful for scripts, automation tools, and control software.

JSON output should be predictable, documented, and easy to parse.

## Non-interactive behavior

If IOE is running in a non-interactive context, it should not wait for input.

Safe behavior should be:

- use safe defaults when possible
- fail clearly when confirmation is required
- never perform destructive cleanup without explicit flags
- never prompt forever in scripts

Destructive operations should require explicit user intent.

## `module.yaml`

A module manifest describes how an application environment should be validated and run.

Example:

```yaml
module_id: text.demo.basic
template_version: 1
name: Text Demo Basic Module
description: Example AI application environment module manifest.
source:
  type: local
  path: templates/modules/text.demo.basic
license: MIT
runtime:
  adapter: docker-compose
  compose_file: docker-compose.yml
capabilities:
  - capability.demo.text
resource_profile:
  cpu_min: 1
  ram_mb_min: 512
  disk_mb_min: 512
  accelerator_required: false
ports:
  - name: http
    host_port: 18080
    container_port: 8080
    public: false
storage:
  data_root: ${IOE_DATA_DIR:-~/ioe-data}
  app_data: apps/text.demo.basic/
  backups: backups/text.demo.basic/
models:
  - name: demo-small-model
    source: registry:example/demo-small-model
    target_path: llm/demo-small-model
    required: false
    size_gb_estimate: 2
    required_vram_gb: 0
lifecycle:
  install: null
  start: null
  stop: null
  remove: null
  healthcheck: healthcheck.sh
healthchecks:
  mode: all
  checks:
    - name: http
      type: http
      url: http://127.0.0.1:18080/health
      timeout_seconds: 10
    - name: container
      type: container
      target: text-demo
logging:
  default_tail: 100
  sources:
    - type: docker-compose
      service: app
cleanup_policy:
  preserve_data_by_default: true
  destructive_cleanup_requires_confirmation: true
security_policy:
  needs_root: false
  needs_docker_socket: false
  privileged: false
  public_exposure: false
extensions: {}
```

## Runtime adapter

The first practical adapter should be `docker-compose` because many existing self-hosted applications already provide Compose files.

A template should be able to keep its existing `docker-compose.yml` and add a small `module.yaml` around it.

This makes IOE adoption possible without forcing existing projects to rewrite their application layout.

## Lifecycle hooks

Lifecycle hooks should be declared in one place:

```yaml
lifecycle:
  pre_install: scripts/pre-install.sh
  post_install: scripts/post-install.sh
  healthcheck: healthcheck.sh
```

Hooks should be optional and reviewable.

Templates should avoid hidden downloads, hardcoded secrets, privileged host changes, and unclear background behavior.

## Model declarations

AI applications often depend on model assets. IOE should allow templates to declare model requirements instead of hiding them inside scripts.

Example:

```yaml
models:
  - name: demo-small-model
    source: registry:example/demo-small-model
    target_path: llm/demo-small-model
    required: false
    size_gb_estimate: 2
    required_vram_gb: 0
    checksum: null
```

Model paths are resolved under:

```text
~/ioe-data/models/
```

For example:

```text
~/ioe-data/models/llm/demo-small-model
```

Model download and cache behavior should be explicit, safe, and reviewable. Early public versions may validate model declarations before implementing automatic downloads.

## Health checks

A module may define one or more health checks:

```yaml
healthchecks:
  mode: all
  checks:
    - name: http
      type: http
      url: http://127.0.0.1:18080/health
      timeout_seconds: 10
    - name: container
      type: container
      target: app
```

Recommended modes:

- `all`: all checks must pass
- `any`: at least one check must pass

Recommended check types:

- `http`
- `tcp`
- `container`
- `command`

## Logs

A module should declare how logs can be read:

```yaml
logging:
  default_tail: 100
  sources:
    - type: docker-compose
      service: app
```

The CLI should expose logs through one command:

```bash
ioectl module logs <module_id> --tail 100
ioectl module logs <module_id> --follow
```

The adapter decides whether logs come from Docker Compose, a container runtime, a local process, or a file.

## State model

`status` should expose more than `running` or `stopped`.

Recommended states:

```text
new
validating
valid
installing
pulling_images
pulling_assets
preparing_data
initializing
starting
healthchecking
healthy
degraded
failed
stopping
stopped
removing
removed
```

A module status response should include enough information to show where a long-running setup is spending time.

## Data layout

The default IOE data root is:

```text
~/ioe-data/
```

The default paths are:

```text
~/ioe-data/apps/<module_id>/
~/ioe-data/backups/<module_id>/
~/ioe-data/models/
```

The data root should be configurable later through an environment variable or config file, but templates should work with the default layout.

## Safe remove behavior

`remove` should stop and remove runtime resources when safe, but it should preserve persistent user data by default.

Destructive cleanup should require explicit intent, for example:

```bash
ioectl module remove <module_id> --delete-data --confirm <module_id>
```

In non-interactive mode, IOE should never assume destructive cleanup is allowed.

## Security expectations

Templates should avoid:

- hardcoded admin credentials
- privileged containers
- unnecessary host networking
- unnecessary Docker socket access
- broad host volume mounts
- public database ports
- unclear binary downloads
- hidden background services

## Compatibility model

The template standard should be stable at the lifecycle level and flexible at the adapter level.

This means:

- `template_version` is required
- version 1 templates should remain supported where possible
- new fields should usually be optional
- unknown fields may be ignored when safe
- breaking changes should require a major version or clear migration path
- runtime-specific behavior should be handled by adapters, not by changing the lifecycle

The public lifecycle should stay recognizable even if future adapters support more runtime types.

See also: [Stability and Extension Policy](STABILITY_AND_EXTENSION_POLICY.md).
