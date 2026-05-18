# IOE Local Runnable Preview

This is a **local-only** runnable preview for IOE application environment templates.

It is intended for **testing and development only** and is not for production use.

## Tested targets

The preview installer has been exercised on fresh VPS images for:

- Debian 12
- Ubuntu 22.04 LTS
- Ubuntu 24.04 LTS

Several common VPS providers were used during private testing. This is early preview validation, not a broad compatibility guarantee.

## Recommended minimum

- 1 CPU
- 1 GB RAM (swap recommended)
- 10 GB+ disk
- Docker with Docker Compose plugin

A 512 MB instance without swap has been exercised successfully in private tests, but that configuration is **not** recommended for new deployments.

## What this preview can do

- validate a module manifest
- install a local module template
- start a local module with Docker Compose
- check basic health status
- view container logs
- stop the local module

Lifecycle:

    validate → install → start → status → logs → stop → remove

## Included templates

- hello.basic (port 18080)
- static.web.basic (port 18081)
- http.echo.basic (port 18082)
- qdrant.basic (port 18083, draft / testing)
- ollama.basic (port 18084, draft / testing)
- open-webui.basic (port 18085, draft / testing)

## Install entrypoints (testing only)

### Remote fresh install (preferred)

Use the **public** `install-ioe.sh` (or `scripts/install-remote.sh` when published) from the repository root—not the copy inside an extracted tarball—for a fresh VPS install. That entrypoint downloads the preview archive, verifies SHA256, installs Docker when needed, and lays out `/opt/ioe-preview`.

Example (from the public repository root on a supported VPS):

```bash
curl -fsSL https://raw.githubusercontent.com/yatenetworks/ioe/main/install-ioe.sh | bash
```

The root `install-ioe.sh` downloads the preview archive, verifies SHA256, and lays out `/opt/ioe-preview`. You may override `IOE_PREVIEW_URL` and `IOE_PREVIEW_SHA256` when testing a different package build.

Remote install layout:

- install root: `/opt/ioe-preview`
- preview tree: `/opt/ioe-preview/public-runnable-preview`
- data directory: `/opt/ioe-data` (via `IOE_DATA_DIR`)
- log file: `/var/log/ioe-preview-install.log`

### Package-internal `install-ioe.sh` (local repair / self-check)

After you extract the preview package, `public-runnable-preview/install-ioe.sh` is for **local repair and self-check by default**. It does **not** download a remote archive or verify a tarball SHA256 unless you **explicitly** set both `IOE_PREVIEW_URL` and `IOE_PREVIEW_SHA256`.

Default behavior (from the extracted tree, as root):

```bash
cd /opt/ioe-preview/public-runnable-preview
sudo ./install-ioe.sh
```

This checks required files, ensures `/opt/ioe-data` and `/etc/ioe-preview/env`, creates or reuses `.venv`, installs `requirements.txt`, and runs light `ioectl` checks. Success ends with:

`== SUCCESS: IOE local preview repair completed ==`

To force download/reinstall from inside the package (unusual), set **both** variables:

```bash
export IOE_PREVIEW_URL="https://..."
export IOE_PREVIEW_SHA256="<64-char-hex>"
sudo ./install-ioe.sh
```

The remote installer remains the preferred fresh-install entrypoint.

## Manual setup (development copy)

```bash
cd public-runnable-preview
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
export IOE_DATA_DIR="${IOE_DATA_DIR:-/opt/ioe-data}"   # optional; defaults to ~/ioe-data if unset

./ioectl validate module templates/modules/hello.basic/module.yaml
```

## Full lifecycle test (already installed tree)

After install, on the server:

```bash
/opt/ioe-preview/public-runnable-preview/scripts/test-ioectl-lifecycle.sh
```

Override preview directory if needed:

```bash
IOE_WORKDIR=/path/to/public-runnable-preview IOE_DATA_DIR=/opt/ioe-data \
  /opt/ioe-preview/public-runnable-preview/scripts/test-ioectl-lifecycle.sh
```

## Boundary

This preview is local-only. It does not provide production installer guarantees, multi-server orchestration, account management, payment handling, external service integration, or catalog features.

## Safety

Module templates should not require root access or Docker socket access. `module remove` is non-destructive by default (user data under `IOE_DATA_DIR` is not deleted automatically).
