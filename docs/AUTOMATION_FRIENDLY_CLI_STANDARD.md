# Automation-Friendly CLI Standard

IOE should be easy to use by people and easy to call from scripts, CI jobs, local control tools, and other automation systems.

The CLI should not require fragile terminal text parsing when a structured response is needed.

## JSON output

Commands that report state, validation results, or health information should support `--json`.

Examples:

```bash
ioectl validate module <module.yaml> --json
ioectl module status <module_id> --json
ioectl module logs <module_id> --tail 100 --json
```

## JSON shape goals

JSON output should be:

- strict
- documented
- predictable
- stable across patch releases
- easy to parse
- free of decorative terminal formatting

A status response may look like this:

```json
{
  "module_id": "text.demo.basic",
  "state": "healthy",
  "health": "passing",
  "adapter": "docker-compose",
  "uptime_seconds": 360,
  "ports": [
    {
      "name": "http",
      "host_port": 18080,
      "public": false
    }
  ],
  "paths": {
    "app_data": "~/ioe-data/apps/text.demo.basic/",
    "backups": "~/ioe-data/backups/text.demo.basic/"
  },
  "checks": [
    {
      "name": "http",
      "status": "passing"
    }
  ]
}
```

A validation response may look like this:

```json
{
  "valid": true,
  "module_id": "text.demo.basic",
  "template_version": 1,
  "errors": [],
  "warnings": []
}
```

## Non-interactive behavior

If standard input is not a TTY, IOE should behave as if `--non-interactive` is enabled.

In non-interactive mode, IOE should:

- avoid prompts
- use safe defaults
- return clear exit codes
- print actionable errors
- refuse destructive actions unless explicit confirmation flags are present

This avoids blocked automation runs.

## Exit codes

Exit codes should be stable and simple.

Recommended starting set:

```text
0  success
1  general error
2  usage or validation error
3  module not found
4  dependency missing
5  health check failed
6  operation timed out
7  destructive action not confirmed
```

## Human output and JSON output

Human-readable output should be optimized for a terminal.

JSON output should be optimized for tools.

The two modes should not be mixed. When `--json` is used, IOE should not print progress bars, colors, banners, or decorative text to standard output.

## Progress events

Long-running operations may optionally emit progress events in a structured form in later versions.

For the first public standard, a stable `status --json` response is more important than a complex event stream.
