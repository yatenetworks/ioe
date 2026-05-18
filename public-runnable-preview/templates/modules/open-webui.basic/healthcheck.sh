#!/usr/bin/env bash
set -Eeuo pipefail

python3 - <<'PY'
import time
import urllib.error
import urllib.request

url = "http://127.0.0.1:18085/health"
deadline = time.time() + 180
last_error = None

while time.time() < deadline:
    try:
        with urllib.request.urlopen(url, timeout=5) as resp:
            if resp.status in (200, 301, 302, 307, 308):
                print("healthy")
                raise SystemExit(0)
    except urllib.error.HTTPError as exc:
        if exc.code in (200, 301, 302, 307, 308):
            print("healthy")
            raise SystemExit(0)
        last_error = exc
    except Exception as exc:
        last_error = exc
    time.sleep(5)

raise RuntimeError(f"open-webui not healthy within 180s: {last_error}")
PY
