#!/usr/bin/env bash
set -Eeuo pipefail

python3 - <<'PY'
import urllib.request
body = urllib.request.urlopen("http://127.0.0.1:18082", timeout=5).read().decode("utf-8", errors="replace")
if "hello from IOE" not in body:
    raise SystemExit("unexpected response")
print("healthy")
PY
