#!/usr/bin/env bash
set -Eeuo pipefail

python3 - <<'PY'
import time
import urllib.error
import urllib.request

url = "http://127.0.0.1:18085/health"
deadline = time.time() + 180
last_error = None
ok_status = (200, 204)

while time.time() < deadline:
    try:
        with urllib.request.urlopen(url, timeout=5) as resp:
            if resp.status in ok_status:
                print("healthy")
                raise SystemExit(0)
            last_error = RuntimeError(f"unexpected HTTP status {resp.status}")
            print(f"unhealthy: HTTP {resp.status}", flush=True)
    except urllib.error.HTTPError as exc:
        last_error = exc
        print(f"unhealthy: HTTP {exc.code} {exc.reason}", flush=True)
    except Exception as exc:
        last_error = exc
        print(f"unhealthy: {exc}", flush=True)
    time.sleep(5)

raise RuntimeError(f"open-webui not healthy within 180s: {last_error}")
PY
