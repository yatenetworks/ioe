# Local Runnable Preview

This document describes the IOE local runnable preview package and preview installer candidate.

## Goal

Provide a small, local-only preview that can validate and run simple application environment templates on a single Linux host.

## Status

Early testing preview. Not for production use.

## Paths (preview installer)

| Path | Purpose |
|------|---------|
| `/opt/ioe-preview` | Install root |
| `/opt/ioe-preview/public-runnable-preview` | Preview package |
| `/opt/ioe-data` | Module instance data (`IOE_DATA_DIR`) |
| `/var/log/ioe-preview-install.log` | Installer log |

## Installer scripts

| Script | Role |
|--------|------|
| `install-ioe.sh` | Local repair/self-check by default; remote download only if `IOE_PREVIEW_URL` + `IOE_PREVIEW_SHA256` are set |
| `scripts/test-ioectl-lifecycle.sh` | Full lifecycle test on an existing install tree |
## Scope

Included:

- minimal ioectl wrapper
- module manifest validation (module kind only in this package)
- local module install / start / status / logs / stop / remove
- three simple templates

Not included:

- production installer guarantees
- multi-server orchestration
- account management
- payment handling
- external service integration
- catalog or listing features
- remote node management

## Supported OS (installer)

- Debian 12
- Ubuntu 22.04 LTS
- Ubuntu 24.04 LTS

## Lifecycle test (installed server)

```bash
scripts/test-ioectl-lifecycle.sh
```

Expected:

    == SUCCESS: ioectl lifecycle test completed ==
