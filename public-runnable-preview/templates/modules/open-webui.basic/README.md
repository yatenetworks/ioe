# open-webui.basic

**Status:** draft / testing only (not verified).

Local testing preview template for [Open WebUI](https://github.com/open-webui/open-webui) using the official `ghcr.io/open-webui/open-webui` container image. Intended for IOE lifecycle exercises on a single Linux host with Docker.

## What it runs

- Image: `ghcr.io/open-webui/open-webui:v0.6.15`
- Host HTTP UI port: `18085` (maps to container port `8080`)
- Data directory: `data/` under the installed module app path (`<IOE_DATA_DIR>/apps/open-webui.basic/data/`)
- Default Ollama URL (optional): `http://host.docker.internal:18084` (use when `ollama.basic` is running on the host)

## Security notes (testing preview)

- **Localhost bind only** (`127.0.0.1:18085`). Do **not** expose this UI to the public Internet without authentication, TLS, and firewall rules.
- `WEBUI_AUTH=false` is set for **local draft testing only** on loopback. Do not reuse this setting on a publicly reachable host.
- This template is for local runnable preview work, not production deployment.

## Lifecycle commands

Run from `public-runnable-preview` with `IOE_DATA_DIR` set if needed:

```bash
./ioectl validate module templates/modules/open-webui.basic/module.yaml
./ioectl module install templates/modules/open-webui.basic/module.yaml
./ioectl module start open-webui.basic
./ioectl module status open-webui.basic
./ioectl module logs open-webui.basic
./ioectl module stop open-webui.basic
./ioectl module remove open-webui.basic
```

`module remove` stops the container and removes the install copy under the app directory. It does **not** delete UI data in `data/` by default (non-destructive remove per IOE data rules).

## Optional: Ollama backend

This template does **not** install or start Ollama. To chat with models in the UI:

1. Start `ollama.basic` (host port `18084`) if needed.
2. Pull models in Ollama (see `ollama.basic` README).
3. Open `http://127.0.0.1:18085/` in a browser on the same host.

If Ollama is not running, the UI may still start; model lists will be empty until a backend is available.

## Health check

`healthcheck.sh` calls `http://127.0.0.1:18085/health`.

## Known limitations

- Draft template; not reviewed as verified.
- No backup/restore automation beyond placeholders.
- First start may take longer while the Docker image is pulled; `healthcheck.sh` waits up to 180s.
- `OFFLINE_MODE=true` avoids automatic model downloads on startup (RAG may be limited until models are configured).
- Resource limits are not enforced by IOE in this preview.
