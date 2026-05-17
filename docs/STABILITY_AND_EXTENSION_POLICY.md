# Stability and Extension Policy

IOE is designed to avoid large rewrites by keeping the public core small and moving future changes into versioned extensions and adapters.

The goal is not to predict every future AI application. The goal is to provide a stable lifecycle that can accept new module types, runtimes, and adapters without breaking existing templates.

## Stable public core

The stable public core is the local module lifecycle:

```bash
ioectl validate module <module.yaml>
ioectl module install <module.yaml>
ioectl module start <module_id>
ioectl module status <module_id>
ioectl module logs <module_id>
ioectl module stop <module_id>
ioectl module remove <module_id>
```

This lifecycle should remain stable. New commands may be added, but existing commands should not be removed or changed in a breaking way without a major version.

## Stable behavior expectations

The following behavior should be treated as part of the standard direction:

- `status` should support structured output
- `validate` should support structured output
- non-interactive execution should never block on prompts
- `remove` should preserve persistent data by default
- destructive cleanup should require explicit confirmation
- log access should be available through the lifecycle
- long-running operations should report standard states

## Template versioning

Every module manifest should declare a template version:

```yaml
template_version: 1
```

The first public template line should stay simple. Future versions may add fields, but version 1 templates should remain readable and usable for as long as possible.

## Backward compatible additions

IOE should prefer backward-compatible changes:

- add optional fields instead of renaming required fields
- keep existing command names stable
- keep old template versions readable
- ignore unknown fields when it is safe to do so
- use clear validation warnings before turning warnings into errors
- provide migration notes when a template format changes

## Adapters instead of rewrites

IOE should not replace existing tools such as Docker, Docker Compose, OCI images, Linux package managers, or application frameworks.

When a new runtime or deployment style becomes useful, IOE should add an adapter layer around the stable lifecycle instead of replacing the core lifecycle.

Examples:

- a Docker Compose adapter
- a local process adapter
- another container runtime adapter
- a remote environment adapter

The public lifecycle should stay the same even when the implementation behind it changes.

## State model stability

The state model should be stable enough for users and automation tools to understand long-running operations.

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

Adapters may have internal states, but they should translate them into the public IOE state model when reporting status.

## Extension fields

Future-facing metadata should use namespaced extension fields when needed:

```yaml
extensions:
  ioe.example/feature:
    enabled: false
```

Extensions should be optional by default. A template should not require private or experimental extensions unless the documentation clearly says so.

## Model asset declarations

Model declarations may evolve over time, but the default model root should remain predictable:

```text
~/ioe-data/models/
```

Early public versions may validate model declarations without automatically downloading assets. More advanced behavior can be added later as optional capabilities.

## Public boundary

Public IOE documentation should stay focused on practical AI application environment installation:

- validation
- templates
- local lifecycle
- health checks
- logs
- model declarations
- data directory conventions
- safe contribution review

Experimental long-term runtime ideas should not be required for public template compatibility.

## Design principle

The public standard should be small enough to stay stable, and flexible enough to accept future adapters.

In practice, this means:

> Keep the lifecycle stable. Let adapters evolve.
