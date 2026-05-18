# flowise.basic

**Status:** draft / testing only (not verified).

Local testing preview template for [Flowise](https://github.com/FlowiseAI/Flowise) using the official `flowiseai/flowise` Docker image. Intended for IOE lifecycle exercises on a single Linux host with Docker.

## What it runs

- Image: `flowiseai/flowise:1.3.5`
- Local URL: `http://127.0.0.1:18086` (maps to container port `3000`)
- Data directory: `data/` under the installed module app path (`<IOE_DATA_DIR>/apps/flowise.basic/data/`)

## Security notes (testing preview)

- **Localhost bind only** (`127.0.0.1:18086`). Do **not** expose Flowise to the public Internet without authentication, TLS, and firewall rules.
- This template does not ship production auth configuration. Treat it as **local testing only**.
- Credentials, API keys, and provider tokens entered in the Flowise UI are **user-managed** and must **not** be committed to this repository.
- This template is for local runnable preview work, not production deployment.

## Lifecycle commands

Run from `public-runnable-preview` with `IOE_DATA_DIR` set if needed:

```bash
./ioectl validate module templates/modules/flowise.basic/module.yaml
./ioectl module install templates/modules/flowise.basic/module.yaml
./ioectl module start flowise.basic
./ioectl module status flowise.basic
./ioectl module logs flowise.basic
./ioectl module stop flowise.basic
./ioectl module remove flowise.basic
```

`module remove` stops the container and removes the install copy under the app directory. It does **not** delete Flowise data in `data/` by default (non-destructive remove per IOE data rules).

## Health check

`healthcheck.sh` calls `http://127.0.0.1:18086/` and accepts HTTP `200` or `204` only (retries up to 180s).

## Known limitations

- Draft template; not reviewed as verified.
- No backup/restore automation beyond placeholders.
- First start may take longer while the Docker image is pulled.
- Resource limits are not enforced by IOE in this preview.
