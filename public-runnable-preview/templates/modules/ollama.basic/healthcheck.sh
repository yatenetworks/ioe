#!/usr/bin/env bash
set -Eeuo pipefail

python3 - <<'PY'
import urllib.request

urllib.request.urlopen("http://127.0.0.1:18084/api/tags", timeout=10)
print("healthy")
PY
