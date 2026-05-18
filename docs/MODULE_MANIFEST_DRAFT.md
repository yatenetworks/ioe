# Module Manifest Draft

This is an early public draft for describing IOE-compatible AI application environment modules.

The manifest should make a module easier to validate before it is installed.

This draft is not final.

## Purpose

A `module.yaml` file should describe:

- what the module is
- where it comes from
- which adapter runs it
- what ports it uses
- what resources it needs
- whether it needs model assets
- where it stores data
- how logs are read
- how health is checked
- what lifecycle hooks exist
- what safety assumptions apply

## Example fields

```yaml
module_id: example.basic
template_version: 1
name: Example Basic Module
description: Example AI application environment module.
source:
  type: local
  path: templates/modules/example.basic
license: MIT
runtime:
  adapter: docker-compose
  compose_file: docker-compose.yml
capabilities:
  - capability.example
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
  app_data: apps/example.basic/
  backups: backups/example.basic/
models:
  - name: demo-small-model
    source: registry:example/demo-small-model
    target_path: llm/demo-small-model
    required: false
    size_gb_estimate: 2
    required_vram_gb: 0
lifecycle:
  healthcheck: healthcheck.sh
healthchecks:
  mode: all
  checks:
    - name: http
      type: http
      url: http://127.0.0.1:18080/health
      timeout_seconds: 10
logging:
  default_tail: 100
  sources:
    - type: docker-compose
      service: app
security_policy:
  needs_root: false
  needs_docker_socket: false
  privileged: false
  public_exposure: false
recovery_policy:
  restart: true
  recreate: true
  restore_from_backup: false
cleanup_policy:
  preserve_data_by_default: true
  destructive_cleanup_requires_confirmation: true
extensions: {}
```

## Field notes

### `module_id`

A stable lowercase identifier for the module.

Recommended format:

```text
name.category
```

Examples:

```text
hello.basic
static.web.basic
http.echo.basic
qdrant.basic
ollama.basic
```

### `template_version`

The template format version.

Use an integer so future validators can support multiple template versions.

### `runtime`

Declares which adapter should run the module.

The first public adapter target should be:

```yaml
runtime:
  adapter: docker-compose
```

### `source`

The source should be clear and reviewable.

Common types may include:

- `local`
- `image`
- `git`

### `resource_profile`

Declare minimum expected resources so users can avoid unrealistic installs on very small servers.

### `models`

Declare model assets when a module depends on them.

Model target paths should resolve under:

```text
~/ioe-data/models/
```

Early validators may only validate model metadata and warn about missing required assets.

### `ports`

Declare host ports and whether they are intended to be public.

Public exposure should be false by default unless the template clearly documents why it needs public access.

### `storage`

Persistent data should use the IOE data layout.

The default data root is:

```text
~/ioe-data/
```

### `lifecycle`

Lifecycle hooks should be optional, explicit, and reviewable.

### `healthchecks`

Health checks should be predictable. Multiple checks may be combined with `all` or `any`.

### `logging`

Log sources should be declared so `ioectl module logs <module_id>` can work through the adapter.

### `security_policy`

Templates should be conservative by default.

### `cleanup_policy`

Persistent user data should be preserved by default.

Destructive cleanup should require explicit confirmation.

## Current status

This manifest is an early draft for public review and template discussion.

The immediate focus is local validation and clean-server testing.
