#!/usr/bin/env bash
# =============================================================================
# IOE AI Env Installer — remote entrypoint (local preview / testing only)
#
# Downloads the public runnable preview package, verifies SHA256, installs Docker
# when missing, runs light validation, and prints next-step commands.
#
# Not for production use. Tested targets: Debian 12, Ubuntu 22.04 LTS, Ubuntu 24.04 LTS.
# =============================================================================
set -Eeuo pipefail

IOE_PREVIEW_URL="${IOE_PREVIEW_URL:-https://job788.net/ioe-public-runnable-preview-v0.8-repair-20260517.tar.gz}"
IOE_PREVIEW_SHA256="${IOE_PREVIEW_SHA256:-3811988d4ecf721c58896d8b60aaff8dba68191604b73fe4d257187d92b53b21}"
INSTALLER_URL="${IOE_INSTALLER_URL:-https://raw.githubusercontent.com/yatenetworks/ioe/main/install-ioe.sh}"

INSTALL_DIR="/opt/ioe-preview"
PREVIEW_DIR="${INSTALL_DIR}/public-runnable-preview"
DATA_DIR="/opt/ioe-data"
ARCHIVE="${INSTALL_DIR}/ioe-public-runnable-preview.tar.gz"
LOG_FILE="/var/log/ioe-preview-install.log"
LOCK_FILE="/var/lock/ioe-preview-install.lock"

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

show_help() {
  cat <<'NOTICE'
IOE AI Env Installer — local runnable preview (testing only)

This script is the remote install entrypoint for early local preview testing.
It is not a production installer and does not provide a hosted service.

Tested targets:
  - Debian 12
  - Ubuntu 22.04 LTS
  - Ubuntu 24.04 LTS

What it does:
  - downloads the preview package archive
  - verifies SHA256
  - installs Docker only if missing (apt-get, --no-install-recommends)
  - extracts to /opt/ioe-preview
  - uses /opt/ioe-data for module data
  - runs light ioectl validation only
  - does not automatically start all modules

Override download (optional):
  IOE_PREVIEW_URL
  IOE_PREVIEW_SHA256

After install:
  cd /opt/ioe-preview/public-runnable-preview
  ./install-ioe.sh
  bash scripts/test-ioectl-lifecycle.sh

Read first:
  - README.md
  - public-runnable-preview/README.md
  - public-runnable-preview/docs/LOCAL_RUNNABLE_PREVIEW.md
NOTICE
}

show_status_json() {
  cat <<'JSON'
{
  "installer": "install-ioe.sh",
  "active": true,
  "status": "preview-testing",
  "mode": "local-preview-remote-install",
  "makes_system_changes": true,
  "testing_only": true,
  "install_dir": "/opt/ioe-preview",
  "data_dir": "/opt/ioe-data",
  "standard_direction": {
    "lifecycle": [
      "validate",
      "install",
      "start",
      "status",
      "logs",
      "stop",
      "remove"
    ],
    "structured_output": true,
    "non_interactive_safe_defaults": true
  }
}
JSON
}

require_root() {
  if [[ "${EUID}" -eq 0 ]]; then
    return 0
  fi

  local script_path
  script_path="$(readlink -f "$0" 2>/dev/null || true)"

  if [[ -n "${script_path}" && -f "${script_path}" ]]; then
    if command -v sudo >/dev/null 2>&1; then
      echo "Re-running installer as root via sudo -H" >&2
      exec sudo -H bash "${script_path}" "$@"
    fi
    echo "ERROR: sudo is required to run this installer as root" >&2
    exit 1
  fi

  cat >&2 <<EOF
Please download the installer first, then run it with sudo:
  curl -fsSL ${INSTALLER_URL} -o install-ioe.sh
  chmod +x install-ioe.sh
  sudo ./install-ioe.sh
EOF
  exit 1
}

acquire_lock() {
  install -d -m 0755 "$(dirname "${LOCK_FILE}")"
  exec 200>"${LOCK_FILE}"
  if ! flock -n 200; then
    fatal "Another IOE preview install is already running (lock: ${LOCK_FILE})"
  fi
}

validate_remote_config() {
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
      DOCKER_CODENAME="${VERSION_CODENAME:-bookworm}"
      ;;
    ubuntu:22.04 | ubuntu:22.04.*)
      OS_FAMILY="ubuntu"
      DOCKER_CODENAME="${UBUNTU_CODENAME:-${VERSION_CODENAME:-jammy}}"
      ;;
    ubuntu:24.04 | ubuntu:24.04.*)
      OS_FAMILY="ubuntu"
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
    fatal "failed to download preview archive from ${IOE_PREVIEW_URL}"
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
  rm -rf "${PREVIEW_DIR}"
  install -d -m 0755 "${INSTALL_DIR}" "${DATA_DIR}"

  download_preview_archive
  verify_preview_archive_sha256

  log "Extracting archive to ${INSTALL_DIR}"
  tar -xzf "${ARCHIVE}" -C "${INSTALL_DIR}"
  [[ -d "${PREVIEW_DIR}" ]] || fatal "Preview directory not found after extract: ${PREVIEW_DIR}"
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

reject_shipped_artifacts_in_tree() {
  if find "${PREVIEW_DIR}" \( -name .venv -o -name __pycache__ -o -name '*.pyc' \) 2>/dev/null | grep -q .; then
    fatal "Preview tree must not contain .venv, __pycache__, or .pyc files"
  fi
}

setup_python_env() {
  cd "${PREVIEW_DIR}"
  if [[ ! -d .venv ]]; then
    log "Creating Python virtual environment at ${PREVIEW_DIR}/.venv"
    python3 -m venv .venv
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
}

run_light_checks() {
  cd "${PREVIEW_DIR}"
  # shellcheck source=/dev/null
  source .venv/bin/activate
  # shellcheck source=/dev/null
  source /etc/ioe-preview/env

  ./ioectl --help >/dev/null
  ./ioectl validate module templates/modules/hello.basic/module.yaml
  ./ioectl validate module templates/modules/static.web.basic/module.yaml
  ./ioectl validate module templates/modules/http.echo.basic/module.yaml
  log "Light install checks passed"
}

print_next_steps() {
  cat <<EOF

IOE local runnable preview remote install completed (testing only).

Install root: ${INSTALL_DIR}
Preview directory: ${PREVIEW_DIR}
Data directory: ${DATA_DIR}
Log file: ${LOG_FILE}

Next steps:

cd ${PREVIEW_DIR}
./install-ioe.sh
bash scripts/test-ioectl-lifecycle.sh

Optional manual lifecycle commands (after the steps above):

source .venv/bin/activate
source /etc/ioe-preview/env
./ioectl module install templates/modules/hello.basic/module.yaml
./ioectl module start hello.basic
./ioectl module status hello.basic
./ioectl module logs hello.basic --tail 50
./ioectl module stop hello.basic
./ioectl module remove hello.basic

EOF
}

run_remote_install() {
  validate_remote_config
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
  print_next_steps
  log "Remote preview install completed successfully"
}

case "${1:-}" in
  -h|--help|help)
    show_help
    exit 0
    ;;
  --status|status)
    if [[ "${2:-}" == "--json" ]]; then
      show_status_json
    else
      echo "preview-testing: local runnable preview remote installer (testing only)"
    fi
    exit 0
    ;;
  --json)
    show_status_json
    exit 0
    ;;
  "")
    require_root "$@"
    install -d -m 0755 "$(dirname "${LOG_FILE}")"
    : > "${LOG_FILE}"
    acquire_lock
    run_remote_install
    ;;
  *)
    echo "Unknown option: $1" >&2
    echo "Run: bash install-ioe.sh --help" >&2
    exit 2
    ;;
esac
