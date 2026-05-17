# Adapter Interface Draft

IOE should keep the public lifecycle stable while allowing the implementation behind it to evolve.

Adapters translate IOE lifecycle commands into runtime-specific actions.

## Why adapters exist

Different applications may run through different backends:

- Docker Compose
- a local process manager
- another container runtime
- a remote execution environment

IOE should not redesign the public lifecycle every time a new backend is added.

The rule is:

> Keep the lifecycle stable. Let adapters evolve.

## Standard lifecycle methods

An adapter should eventually provide methods equivalent to:

```text
validate(module)
install(module)
start(module_id)
status(module_id)
logs(module_id, options)
stop(module_id)
remove(module_id, options)
healthcheck(module_id)
```

The public CLI can remain stable while the adapter decides how to implement each method.

## First adapter target

The first practical target should be a Docker Compose adapter.

Reason:

- many self-hosted applications already provide `docker-compose.yml`
- wrapping an existing Compose project with `module.yaml` is low-friction
- users can understand what will run
- clean-server smoke tests are straightforward

A minimal Compose-based module should require little more than:

```text
module.yaml
docker-compose.yml
.env.example
README.md
healthcheck.sh
```

## Adapter responsibilities

An adapter may handle:

- validating required runtime files
- preparing environment variables
- creating expected local data paths
- starting services
- stopping services
- reading status
- collecting logs
- running health checks
- preserving user data during remove

## Adapter boundaries

Adapters should not hide unsafe behavior.

Adapters should avoid:

- silently changing host firewall rules
- silently deleting persistent data
- silently enabling privileged containers
- silently exposing databases publicly
- silently downloading unreviewed binaries

## State reporting

Adapters should report state using the standard IOE state model, not runtime-specific language only.

For example, a Compose adapter can translate runtime details into:

```text
pulling_images
initializing
healthchecking
healthy
failed
stopped
```

This keeps `ioectl module status <module_id> --json` stable across adapters.

## Extension model

Adapter-specific fields should be placed under runtime-specific sections or namespaced extensions.

Example:

```yaml
runtime:
  adapter: docker-compose
  compose_file: docker-compose.yml
```

Experimental features should be optional by default.
