#!/usr/bin/env bash
# IOE local runnable preview: local repair/self-check by default (testing only).
# Remote download/reinstall only when BOTH IOE_PREVIEW_URL and IOE_PREVIEW_SHA256 are set.
set -Eeuo pipefail

INSTALL_DIR="/opt/ioe-preview"
DATA_DIR="/opt/ioe-data"
ARCHIVE="${INSTALL_DIR}/ioe-public-runnable-preview.tar.gz"
LOG_FILE="/var/log/ioe-preview-install.log"
LOCK_FILE="/var/lock/ioe-preview-install.lock"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() {
  printf '[%s] %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$*" | tee -a "${LOG_FILE}"
}

fatal() {
  log "ERROR: $*"
  echo "Install failed. See log: ${LOG_FILE}" >&2
  exit 1
}

on_err() {
  local exit_code=$?
  log "ERROR: install script failed at line ${BASH_LINENO[0]} (exit ${exit_code})"
  echo "Install failed. See log: ${LOG_FILE}" >&2
  exit "${exit_code}"
}
trap on_err ERR

require_root() {
  if [[ "${EUID}" -eq 0 ]]; then
    return 0
  fi
  if command -v sudo >/dev/null 2>&1; then
    echo "Re-running installer as root via sudo -H" >&2
    exec sudo -H bash "$0" "$@"
  fi
  echo "ERROR: This installer must be run as root or via sudo" >&2
  exit 1
}

acquire_lock() {
  install -d -m 0755 "$(dirname "${LOCK_FILE}")"
  exec 200>"${LOCK_FILE}"
  if ! flock -n 200; then
    fatal "Another IOE preview install is already running (lock: ${LOCK_FILE})"
  fi
}

remote_install_requested() {
  [[ -n "${IOE_PREVIEW_URL:-}" || -n "${IOE_PREVIEW_SHA256:-}" ]]
}

validate_remote_install_config() {
  if [[ -n "${IOE_PREVIEW_URL:-}" && -z "${IOE_PREVIEW_SHA256:-}" ]]; then
    fatal "IOE_PREVIEW_SHA256 is required when IOE_PREVIEW_URL is set (download/reinstall mode)"
  fi
  if [[ -z "${IOE_PREVIEW_URL:-}" && -n "${IOE_PREVIEW_SHA256:-}" ]]; then
    fatal "IOE_PREVIEW_URL is required when IOE_PREVIEW_SHA256 is set (download/reinstall mode)"
  fi
  if [[ ! "${IOE_PREVIEW_URL}" =~ ^https?:// ]]; then
    fatal "IOE_PREVIEW_URL must start with http:// or https://"
  fi
  if [[ ! "${IOE_PREVIEW_SHA256}" =~ ^[a-f0-9]{64}$ ]]; then
    fatal "IOE_PREVIEW_SHA256 must be a 64-character lowercase hex SHA256 value"
  fi
}

detect_os() {
  if [[ ! -f /etc/os-release ]]; then
    fatal "Unsupported system: missing /etc/os-release"
  fi
  # shellcheck source=/dev/null
  source /etc/os-release
  ID="${ID:-}"
  VERSION_ID="${VERSION_ID:-}"
  VERSION_CODENAME="${VERSION_CODENAME:-}"
  UBUNTU_CODENAME="${UBUNTU_CODENAME:-}"

  case "${ID}:${VERSION_ID}" in
    debian:12 | debian:12.*)
      OS_FAMILY="debian"
      OS_VERSION_ID="12"
      DOCKER_CODENAME="${VERSION_CODENAME:-bookworm}"
      ;;
    ubuntu:22.04 | ubuntu:22.04.*)
      OS_FAMILY="ubuntu"
      OS_VERSION_ID="22.04"
      DOCKER_CODENAME="${UBUNTU_CODENAME:-${VERSION_CODENAME:-jammy}}"
      ;;
    ubuntu:24.04 | ubuntu:24.04.*)
      OS_FAMILY="ubuntu"
      OS_VERSION_ID="24.04"
      DOCKER_CODENAME="${UBUNTU_CODENAME:-${VERSION_CODENAME:-noble}}"
      ;;
    *)
      fatal "Unsupported OS: ${PRETTY_NAME:-unknown}. Supported: Debian 12, Ubuntu 22.04, Ubuntu 24.04"
      ;;
  esac
  log "Detected OS: ${PRETTY_NAME:-${ID} ${VERSION_ID}} (docker codename: ${DOCKER_CODENAME})"
}

warn_low_memory() {
  local mem_kb swap_kb
  mem_kb="$(awk '/MemTotal:/ {print $2}' /proc/meminfo)"
  swap_kb="$(awk '/SwapTotal:/ {print $2}' /proc/meminfo)"
  if [[ "${mem_kb}" -lt 1048576 && "${swap_kb}" -eq 0 ]]; then
    log "WARNING: Low memory detected. 1GB RAM with swap is recommended for preview testing."
  fi
}

docker_ready() {
  command -v docker >/dev/null 2>&1 || return 1
  docker info >/dev/null 2>&1 || return 1
  if docker compose version >/dev/null 2>&1; then
    return 0
  fi
  if command -v docker-compose >/dev/null 2>&1 && docker-compose version >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

install_base_packages() {
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    tar \
    python3 \
    python3-venv \
    python3-pip
}

install_docker() {
  if docker_ready; then
    log "Docker and Docker Compose already available; skipping Docker install"
    docker --version | tee -a "${LOG_FILE}"
    if docker compose version >/dev/null 2>&1; then
      docker compose version | tee -a "${LOG_FILE}"
    else
      docker-compose version | tee -a "${LOG_FILE}"
    fi
    return 0
  fi

  export DEBIAN_FRONTEND=noninteractive
  install -d -m 0755 /etc/apt/keyrings
  curl -fsSL "https://download.docker.com/linux/${OS_FAMILY}/gpg" \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg

  local repo_url="https://download.docker.com/linux/${OS_FAMILY}"
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] ${repo_url} ${DOCKER_CODENAME} stable" \
    > /etc/apt/sources.list.d/docker.list

  apt-get update -y
  apt-get install -y --no-install-recommends \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

  systemctl enable --now docker
  docker --version | tee -a "${LOG_FILE}"
  docker compose version | tee -a "${LOG_FILE}"
}

download_preview_archive() {
  log "Downloading preview archive from ${IOE_PREVIEW_URL}"
  if ! curl -fL --retry 3 --retry-delay 2 -o "${ARCHIVE}" "${IOE_PREVIEW_URL}"; then
    log "ERROR: failed to download preview archive from ${IOE_PREVIEW_URL}"
    log "Please check IOE_PREVIEW_URL and network access."
    echo "ERROR: failed to download preview archive from ${IOE_PREVIEW_URL}" >&2
    echo "Please check IOE_PREVIEW_URL and network access." >&2
    exit 1
  fi
}

verify_preview_archive_sha256() {
  log "Verifying SHA256 of ${ARCHIVE}"
  local actual
  actual="$(sha256sum "${ARCHIVE}" | awk '{print $1}')"
  if [[ "${actual}" != "${IOE_PREVIEW_SHA256}" ]]; then
    log "ERROR: SHA256 mismatch for ${ARCHIVE}"
    log "Expected: ${IOE_PREVIEW_SHA256}"
    log "Actual:   ${actual}"
    echo "ERROR: SHA256 mismatch for ${ARCHIVE}" >&2
    echo "Expected: ${IOE_PREVIEW_SHA256}" >&2
    echo "Actual:   ${actual}" >&2
    exit 1
  fi
}

download_and_extract_preview() {
  local preview_dir="${INSTALL_DIR}/public-runnable-preview"
  rm -rf "${preview_dir}"
  install -d -m 0755 "${INSTALL_DIR}" "${DATA_DIR}"

  download_preview_archive
  verify_preview_archive_sha256

  log "Extracting archive to ${INSTALL_DIR}"
  tar -xzf "${ARCHIVE}" -C "${INSTALL_DIR}"

  [[ -d "${preview_dir}" ]] || fatal "Preview directory not found after extract: ${preview_dir}"
  PREVIEW_DIR="${preview_dir}"
}

assert_preview_tree() {
  local required=(
    ioectl
    requirements.txt
    templates/modules/hello.basic/module.yaml
    templates/modules/static.web.basic/module.yaml
    templates/modules/http.echo.basic/module.yaml
  )
  local path
  for path in "${required[@]}"; do
    [[ -e "${PREVIEW_DIR}/${path}" ]] || fatal "Missing required file: ${PREVIEW_DIR}/${path}"
  done
}

assert_local_preview_directory() {
  if [[ "$(basename "${SCRIPT_DIR}")" != "public-runnable-preview" ]]; then
    fatal "This script must live in a directory named public-runnable-preview (found: ${SCRIPT_DIR})"
  fi
  PREVIEW_DIR="${SCRIPT_DIR}"
  log "Local repair mode: using preview tree at ${PREVIEW_DIR}"
}

reject_shipped_artifacts_in_tree() {
  if find "${PREVIEW_DIR}" \( -name .venv -o -name __pycache__ -o -name '*.pyc' \) 2>/dev/null | grep -q .; then
    fatal "Preview tree must not contain .venv, __pycache__, or .pyc files (remote install only)"
  fi
}

ensure_data_dir() {
  install -d -m 0755 "${DATA_DIR}"
  log "Data directory: ${DATA_DIR}"
}

setup_python_env() {
  cd "${PREVIEW_DIR}"
  if [[ ! -d .venv ]]; then
    log "Creating Python virtual environment at ${PREVIEW_DIR}/.venv"
    python3 -m venv .venv
  else
    log "Using existing virtual environment at ${PREVIEW_DIR}/.venv"
  fi
  # shellcheck source=/dev/null
  source .venv/bin/activate
  python -m pip install --upgrade pip
  pip install -r requirements.txt
}

write_env_defaults() {
  install -d -m 0755 /etc/ioe-preview
  cat > /etc/ioe-preview/env <<EOF
# IOE local runnable preview environment (testing only)
export IOE_DATA_DIR=${DATA_DIR}
EOF
  chmod 0644 /etc/ioe-preview/env
  log "Wrote ${DATA_DIR} default via /etc/ioe-preview/env (IOE_DATA_DIR)"
}

run_light_checks() {
  cd "${PREVIEW_DIR}"
  # shellcheck source=/dev/null
  source .venv/bin/activate
  # shellcheck source=/dev/null
  source /etc/ioe-preview/env

  ./ioectl --help >/dev/null
  ./ioectl -h >/dev/null
  ./ioectl help >/dev/null
  ./ioectl validate module templates/modules/hello.basic/module.yaml
  ./ioectl validate module templates/modules/static.web.basic/module.yaml
  ./ioectl validate module templates/modules/http.echo.basic/module.yaml
  log "Light install checks passed"
}

print_local_success() {
  echo "== SUCCESS: IOE local preview repair completed =="
}

print_remote_next_steps() {
  cat <<EOF

IOE local runnable preview remote install completed (testing only).

Data directory: ${DATA_DIR}
Preview directory: ${PREVIEW_DIR}
Log file: ${LOG_FILE}

Next steps:

cd ${PREVIEW_DIR}
source .venv/bin/activate
source /etc/ioe-preview/env
./ioectl validate module templates/modules/hello.basic/module.yaml
./ioectl module install templates/modules/hello.basic/module.yaml
./ioectl module start hello.basic
./ioectl module status hello.basic
./ioectl module logs hello.basic --tail 50
./ioectl module stop hello.basic
./ioectl module remove hello.basic

Full lifecycle test (optional):

${PREVIEW_DIR}/scripts/test-ioectl-lifecycle.sh

EOF
}

run_local_repair() {
  assert_local_preview_directory
  assert_preview_tree
  ensure_data_dir
  write_env_defaults
  if ! command -v python3 >/dev/null 2>&1; then
    fatal "python3 is required for local repair (install python3 and python3-venv)"
  fi
  setup_python_env
  run_light_checks
  print_local_success
  log "Local preview repair completed successfully"
}

run_remote_install() {
  validate_remote_install_config
  detect_os
  warn_low_memory
  install_base_packages
  install_docker
  download_and_extract_preview
  reject_shipped_artifacts_in_tree
  assert_preview_tree
  setup_python_env
  write_env_defaults
  run_light_checks
  print_remote_next_steps
  log "Remote preview install completed successfully"
}

main() {
  require_root "$@"
  install -d -m 0755 "$(dirname "${LOG_FILE}")"
  : > "${LOG_FILE}"

  if remote_install_requested; then
    log "Remote download/reinstall mode (IOE_PREVIEW_URL + IOE_PREVIEW_SHA256)"
    acquire_lock
    run_remote_install
  else
    log "Local repair/self-check mode (no remote download)"
    run_local_repair
  fi
}

main "$@"
