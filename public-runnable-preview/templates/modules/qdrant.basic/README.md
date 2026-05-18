# qdrant.basic

**Status:** draft / testing only (not verified).

Local testing preview template for [Qdrant](https://github.com/qdrant/qdrant) using the official `qdrant/qdrant` Docker image. Intended for IOE lifecycle exercises on a single Linux host with Docker.

## What it runs

- Image: `qdrant/qdrant:v1.13.5`
- Host HTTP API port: `18083` (maps to container port `6333`)
- Data directory: `storage/` under the installed module app path (`<IOE_DATA_DIR>/apps/qdrant.basic/storage/`)

## Security notes (testing preview)

- Authentication is **not** enabled in this draft template.
- Bind to localhost for testing. **Do not expose Qdrant to the public Internet** without proper authentication, TLS, and firewall rules.
- This template is for local runnable preview work, not production deployment.

## Lifecycle commands

Run from `public-runnable-preview` with `IOE_DATA_DIR` set if needed:

```bash
./ioectl validate module templates/modules/qdrant.basic/module.yaml
./ioectl module install templates/modules/qdrant.basic/module.yaml
./ioectl module start qdrant.basic
./ioectl module status qdrant.basic
./ioectl module logs qdrant.basic
./ioectl module stop qdrant.basic
./ioectl module remove qdrant.basic
```

`module remove` stops the container and removes the install copy under the app directory. It does **not** delete persistent vector data in `storage/` by default (non-destructive remove per IOE data rules).

## Health check

`healthcheck.sh` calls `http://127.0.0.1:18083/readyz`.

## Known limitations

- Draft template; not reviewed as verified.
- No backup/restore automation beyond placeholders.
- Resource limits are not enforced by IOE in this preview.
