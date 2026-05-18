# ollama.basic

**Status:** draft / testing only (not verified).

Local testing preview template for [Ollama](https://github.com/ollama/ollama) using the official `ollama/ollama` Docker image. Intended for IOE lifecycle exercises on a single Linux host with Docker.

## What it runs

- Image: `ollama/ollama:0.6.6`
- Host HTTP API port: `18084` (maps to container port `11434`)
- Data directory: `data/` under the installed module app path (`<IOE_DATA_DIR>/apps/ollama.basic/data/`)

## Security notes (testing preview)

- Authentication is **not** enabled in this draft template.
- Bind to localhost for testing. **Do not expose the Ollama API to the public Internet** without proper authentication, TLS, and firewall rules.
- This template is for local runnable preview work, not production deployment.

## Lifecycle commands

Run from `public-runnable-preview` with `IOE_DATA_DIR` set if needed:

```bash
./ioectl validate module templates/modules/ollama.basic/module.yaml
./ioectl module install templates/modules/ollama.basic/module.yaml
./ioectl module start ollama.basic
./ioectl module status ollama.basic
./ioectl module logs ollama.basic
./ioectl module stop ollama.basic
./ioectl module remove ollama.basic
```

`module remove` stops the container and removes the install copy under the app directory. It does **not** delete downloaded models in `data/` by default (non-destructive remove per IOE data rules).

## Health check

`healthcheck.sh` calls `http://127.0.0.1:18084/api/tags`.

## Optional: pull a model (user action)

This template does **not** download models during `install` or `start`. Models can be large; pull only when you choose to test inference.

After the module is **healthy**, from the host (with the container running):

```bash
docker exec ioe-ollama-basic ollama pull llama3.2:1b
```

Or call the local API (example):

```bash
curl -fsS http://127.0.0.1:18084/api/pull -d '{"name":"llama3.2:1b"}'
```

Replace the model name with any tag you intend to test. Downloaded blobs are stored under `data/` in the module app directory.

## Known limitations

- Draft template; not reviewed as verified.
- No backup/restore automation beyond placeholders.
- First start may take longer while the Docker image is pulled (not a model pull).
- Resource limits are not enforced by IOE in this preview.
- GPU is not required by the manifest; local inference may be slow on CPU-only hosts.
