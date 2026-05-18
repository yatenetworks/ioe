# litellm.basic

**Status:** draft / testing only (not verified).

Local testing preview template for [LiteLLM](https://github.com/BerriAI/litellm) proxy using the official `litellm/litellm` Docker image. Intended for IOE lifecycle exercises on a single Linux host with Docker.

**Higher risk than simple templates:** LiteLLM handles API keys, proxy access, and provider configuration. Treat this module as local preview work only.

## What it runs

- Image: `litellm/litellm:v1.17.8`
- Local URL: `http://127.0.0.1:18087` (maps to container port `4000`)
- Config: `config.example.yaml` in the template directory (example only); the running container uses an inline compose config with `os.environ/...` key references
- Data directory: `data/` under the installed module app path (`<IOE_DATA_DIR>/apps/litellm.basic/data/`)

## Security notes (testing preview)

- **Localhost bind only** (`127.0.0.1:18087`). Do **not** expose the LiteLLM proxy to the public Internet without authentication, TLS, and firewall rules.
- **Local testing only** — not production-ready.
- Provider **API keys are user-managed**. Copy `.env.example` to `.env` locally; **never** commit real keys, tokens, or production master keys.
- `config.example.yaml` uses `os.environ/...` references only — no real secrets in the repository.
- The compose file sets a **local placeholder** `LITELLM_MASTER_KEY` for container startup on loopback. Replace via your own `.env` for real testing; do not reuse publicly.

## Optional: provider keys for inference

Basic **startup and healthcheck** do not require valid provider keys. To call models through the proxy, set keys in a local `.env` (from `.env.example`) after install.

## Lifecycle commands

Run from `public-runnable-preview` with `IOE_DATA_DIR` set if needed:

```bash
./ioectl validate module templates/modules/litellm.basic/module.yaml
./ioectl module install templates/modules/litellm.basic/module.yaml
./ioectl module start litellm.basic
./ioectl module status litellm.basic
./ioectl module logs litellm.basic
./ioectl module stop litellm.basic
./ioectl module remove litellm.basic
```

`module remove` stops the container and removes the install copy under the app directory. It does **not** delete `data/` by default (non-destructive remove per IOE data rules).

## Health check

`healthcheck.sh` calls `http://127.0.0.1:18087/health/liveliness` (unauthenticated liveness probe) and accepts HTTP `200` or `204` only (retries up to 180s).

## Known limitations

- Draft template; not reviewed as verified.
- No backup/restore automation beyond placeholders.
- First start may take longer while the Docker image is pulled.
- Inference fails until valid provider keys are configured locally.
- Resource limits are not enforced by IOE in this preview.
