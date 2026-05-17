#!/usr/bin/env bash
# Full ioectl lifecycle test for an already-installed preview directory.
# Does not download, install system packages, or extract archives.
set -Eeuo pipefail

PREVIEW_DIR="${IOE_WORKDIR:-/opt/ioe-preview/public-runnable-preview}"
DATA_DIR="${IOE_DATA_DIR:-/opt/ioe-data}"
LOG_FILE="${IOE_LIFECYCLE_TEST_LOG:-/var/log/ioe-preview-lifecycle-test.log}"

declare -a MODULES=(hello.basic static.web.basic http.echo.basic)
declare -a PORTS=(18080 18081 18082)
TEST_CONTAINER_NAMES=(ioe-hello-basic ioe-static-web-basic ioe-http-echo-basic)

log() {
  printf '[%s] %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$*" | tee -a "${LOG_FILE}"
}

fatal() {
  log "ERROR: $*"
  echo "Lifecycle test failed. See log: ${LOG_FILE}" >&2
  exit 1
}

require_root() {
  if [[ "${EUID}" -eq 0 ]]; then
    return 0
  fi
  if command -v sudo >/dev/null 2>&1; then
    exec sudo -H env IOE_WORKDIR="${IOE_WORKDIR:-}" IOE_DATA_DIR="${IOE_DATA_DIR:-}" bash "$0" "$@"
  fi
  fatal "This test must be run as root or via sudo"
}

assert_no_traceback_output() {
  local label=$1
  local file=$2
  if grep -qE 'Traceback|ConnectionRefusedError|urllib\.error|Exception:' "${file}"; then
    log "Unexpected error output during ${label}:"
    grep -E 'Traceback|ConnectionRefusedError|urllib\.error|Exception:' "${file}" | tee -a "${LOG_FILE}" || true
    fatal "${label} produced traceback or connection error text"
  fi
}

run_ioectl() {
  local label=$1
  shift
  local out
  out="$(mktemp)"
  if ! "${PREVIEW_DIR}/ioectl" "$@" >"${out}" 2>&1; then
    cat "${out}" | tee -a "${LOG_FILE}"
    rm -f "${out}"
    fatal "${label} failed: ioectl $*"
  fi
  cat "${out}" | tee -a "${LOG_FILE}"
  assert_no_traceback_output "${label}" "${out}"
  rm -f "${out}"
}

run_ioectl_start() {
  local module_id=$1
  local port=$2
  local out
  out="$(mktemp)"
  if ! "${PREVIEW_DIR}/ioectl" module start "${module_id}" >"${out}" 2>&1; then
    cat "${out}" | tee -a "${LOG_FILE}"
    assert_no_traceback_output "start ${module_id}" "${out}"
    echo "ERROR: module start failed for ${module_id}" >&2
    echo "Possible reason: required host port ${port} may already be in use." >&2
    rm -f "${out}"
    exit 1
  fi
  cat "${out}" | tee -a "${LOG_FILE}"
  assert_no_traceback_output "start ${module_id}" "${out}"
  rm -f "${out}"
}

wait_for_http_ready() {
  local module_id="$1"
  local port="$2"
  local attempts="${IOE_TEST_READY_ATTEMPTS:-30}"
  local delay="${IOE_TEST_READY_DELAY:-2}"
  local i

  for ((i = 1; i <= attempts; i++)); do
    if curl -fsSI "http://127.0.0.1:${port}/" >>"${LOG_FILE}" 2>&1; then
      log "Module ${module_id} is HTTP ready on port ${port} (attempt ${i}/${attempts})"
      return 0
    fi
    sleep "${delay}"
  done

  echo "ERROR: module did not become ready: ${module_id} on port ${port}" >&2
  return 1
}

assert_no_leftover_test_containers() {
  local container
  for container in "${TEST_CONTAINER_NAMES[@]}"; do
    if docker ps -aq --filter "name=^/${container}$" | grep -q .; then
      log "ERROR: leftover IOE test container detected: ${container}"
      docker ps -a --filter "name=^/${container}$" | tee -a "${LOG_FILE}" || true
      echo "ERROR: leftover IOE test container detected: ${container}" >&2
      docker ps -a --filter "name=^/${container}$" >&2 || true
      exit 1
    fi
  done
}

test_module() {
  local module_id=$1
  local port=$2
  local yaml="${PREVIEW_DIR}/templates/modules/${module_id}/module.yaml"
  local tmp

  log "Testing module ${module_id} on port ${port}"

  run_ioectl "validate ${module_id}" validate module "${yaml}"
  "${PREVIEW_DIR}/ioectl" module remove "${module_id}" >>"${LOG_FILE}" 2>&1 || true

  run_ioectl "install ${module_id}" module install "${yaml}"
  run_ioectl_start "${module_id}" "${port}"
  if ! wait_for_http_ready "${module_id}" "${port}"; then
    "${PREVIEW_DIR}/ioectl" module logs "${module_id}" --tail 50 >>"${LOG_FILE}" 2>&1 || true
    "${PREVIEW_DIR}/ioectl" module logs "${module_id}" --tail 50 >&2 || true
    exit 1
  fi
  run_ioectl "status running ${module_id}" module status "${module_id}"

  tmp="$(mktemp)"
  if ! "${PREVIEW_DIR}/ioectl" module logs "${module_id}" --tail 20 >"${tmp}" 2>&1; then
    cat "${tmp}" | tee -a "${LOG_FILE}"
    rm -f "${tmp}"
    fatal "logs ${module_id} failed"
  fi
  cat "${tmp}" | tee -a "${LOG_FILE}"
  assert_no_traceback_output "logs ${module_id}" "${tmp}"
  rm -f "${tmp}"

  run_ioectl "stop ${module_id}" module stop "${module_id}"
  run_ioectl "status after stop ${module_id}" module status "${module_id}"
  run_ioectl "remove ${module_id}" module remove "${module_id}"
}

main() {
  require_root "$@"
  install -d -m 0755 "$(dirname "${LOG_FILE}")"
  : > "${LOG_FILE}"

  [[ -x "${PREVIEW_DIR}/ioectl" ]] || fatal "Missing ioectl: ${PREVIEW_DIR}/ioectl"
  [[ -f "${PREVIEW_DIR}/.venv/bin/activate" ]] || fatal "Missing venv: ${PREVIEW_DIR}/.venv"

  export IOE_DATA_DIR="${DATA_DIR}"
  cd "${PREVIEW_DIR}"
  # shellcheck source=/dev/null
  source .venv/bin/activate
  if [[ -f /etc/ioe-preview/env ]]; then
    # shellcheck source=/dev/null
    source /etc/ioe-preview/env
  fi

  if ! docker compose version >/dev/null 2>&1 && ! command -v docker-compose >/dev/null 2>&1; then
    fatal "Docker Compose is required for lifecycle test"
  fi

  local i
  for i in "${!MODULES[@]}"; do
    test_module "${MODULES[$i]}" "${PORTS[$i]}"
  done

  assert_no_leftover_test_containers

  log "== SUCCESS: ioectl lifecycle test completed =="
  echo "== SUCCESS: ioectl lifecycle test completed =="
}

main "$@"
