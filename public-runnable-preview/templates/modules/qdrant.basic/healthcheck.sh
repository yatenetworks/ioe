#!/usr/bin/env bash
set -Eeuo pipefail

python3 - <<'PY'
import urllib.request

urllib.request.urlopen("http://127.0.0.1:18083/readyz", timeout=5)
print("healthy")
PY
