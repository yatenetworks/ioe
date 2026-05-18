#!/usr/bin/env bash
# Opt-in Docker lifecycle test for one module template (run manually from repo root).
set -Eeuo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: scripts/check-template-lifecycle.sh <module_id>" >&2
  echo "Example: scripts/check-template-lifecycle.sh qdrant.basic" >&2
  exit 2
fi

MODULE_ID="$1"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PREVIEW="${ROOT}/public-runnable-preview"
MANIFEST="templates/modules/${MODULE_ID}/module.yaml"

if [[ ! -f "${PREVIEW}/${MANIFEST}" ]]; then
  echo "ERROR: manifest not found: ${PREVIEW}/${MANIFEST}" >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: docker is required for lifecycle test" >&2
  exit 1
fi

cd "${PREVIEW}"

if [[ -d .venv ]]; then
  # shellcheck source=/dev/null
  source .venv/bin/activate
elif ! python3 -c "import jsonschema" 2>/dev/null; then
  echo "ERROR: activate public-runnable-preview/.venv or install requirements.txt" >&2
  exit 1
fi

run_step() {
  local label="$1"
  shift
  echo ">> ${label}"
  if "$@"; then
    echo "OK: ${label}"
  else
    echo "FAIL: ${label}" >&2
    exit 1
  fi
}

echo "== IOE template lifecycle test: ${MODULE_ID} =="
echo "Preview dir: ${PREVIEW}"
echo

run_step "validate" ./ioectl validate module "${MANIFEST}"
run_step "install" ./ioectl module install "${MANIFEST}"
run_step "start" ./ioectl module start "${MODULE_ID}"
run_step "status" ./ioectl module status "${MODULE_ID}"
run_step "logs" ./ioectl module logs "${MODULE_ID}" --tail 30
run_step "stop" ./ioectl module stop "${MODULE_ID}"
run_step "remove" ./ioectl module remove "${MODULE_ID}"

echo
echo "== RESULT: PASS (lifecycle completed for ${MODULE_ID}) =="
