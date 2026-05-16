#!/usr/bin/env bash
# =============================================================================
#  IOE AI Application Environment Installer v0.1.0-beta (IOE AI Env Installer)
#  Repository : https://github.com/yatenetworks/ioe.git
#
#  Usage:
#    bash install-ioe.sh [--mirror] [--no-firewall] [--port 3000]
#    curl -fsSL https://raw.githubusercontent.com/yatenetworks/ioe/main/install-ioe.sh | bash -s -- [--mirror] [--no-firewall] [--port 3000]
#
#  Optional environment overrides:
#    IOE_DATA_ROOT=$HOME/ioe-data
#    IOE_APPS_DIR=$HOME/ioe-data/apps
#    IOE_BACKUP_DIR=$HOME/ioe-data/backups
#    IOE_MODEL_DIR=$HOME/ioe-data/models
#    IOE_INSTALL_DIR=/mnt/data/ioe
#    IOE_PANEL_PORT=4000
#    PANEL_VERSION=v0.1.0
#    IOE_FIREWALL_MODE=standard|none
#    IOE_MIN_DISK_MB=10240
#    IOE_MIN_MEM_MB=900
#    IOE_AUTO_SWAP=1
#    IOE_SWAP_SIZE_GB=4
#
#  Design principles:
#    - Non-interactive by default; suitable for fresh environments.
#    - Preserve existing SSH configuration; avoid user lockout.
#    - Do not overwrite existing Docker daemon config or firewall rules.
#    - Detect and adapt to LXC / OpenVZ / WSL / non-systemd environments.
#    - Optional extension features start disabled.
# =============================================================================
set -Eeuo pipefail
umask 027

# ─────────────────────────────────────────────────────────────────────────────
# Argument Parsing
# ─────────────────────────────────────────────────────────────────────────────
FORCE_MIRROR=0
NO_FIREWALL=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --mirror)
            FORCE_MIRROR=1
            shift
            ;;
        --no-firewall|--skip-firewall)
            NO_FIREWALL=1
            shift
            ;;
        --port|--panel-port)
            [[ $# -lt 2 ]] && { echo "[ERROR] Missing value for $1" >&2; exit 1; }
            export IOE_PANEL_PORT="$2"
            shift 2
            ;;
        --help|-h)
            cat <<'EOF'
IOE AI Env Installer
Full name: IOE AI Application Environment Installer.

Usage:
  bash install-ioe.sh [options]

Options:
  --mirror              Force Docker registry mirror acceleration.
  --no-firewall         Do not change UFW/firewalld rules.
  --port <port>         Set panel port, same as IOE_PANEL_PORT=<port>.
  -h, --help            Show this help.

Environment:
  PANEL_VERSION=v0.1.0
  IOE_DATA_ROOT=$HOME/ioe-data
  IOE_APPS_DIR=$HOME/ioe-data/apps
  IOE_BACKUP_DIR=$HOME/ioe-data/backups
  IOE_MODEL_DIR=$HOME/ioe-data/models
  IOE_INSTALL_DIR=/opt/ioe-matrix
  IOE_PANEL_PORT=3000
  IOE_FIREWALL_MODE=standard|none
  IOE_AUTO_SWAP=1
  IOE_SWAP_SIZE_GB=4

Security model:
  This installer does not modify SSH configuration by default.
  Port 22 remains reachable to prevent accidental lockout.
  Use 'ioectl security' after installation for hardening guidance.
EOF
            exit 0
            ;;
        *)
            echo "[WARN] Unknown argument ignored: $1" >&2
            shift
            ;;
    esac
done

# ─────────────────────────────────────────────────────────────────────────────
# Constants
# ─────────────────────────────────────────────────────────────────────────────
readonly INSTALLER_VERSION="0.1.0-beta"
readonly INSTALLER_PROFILE="ioe-ai-env"
readonly PANEL_REPO="https://github.com/yatenetworks/ioe.git"
readonly PANEL_VERSION="${PANEL_VERSION:-main}"

# Application data paths
# Data layout defaults to ~/ioe-data (e.g. /root/ioe-data when run as root).
readonly IOE_DATA_ROOT="${IOE_DATA_ROOT:-${HOME}/ioe-data}"
readonly DATA_DIR="${IOE_APPS_DIR:-${IOE_DATA_ROOT}/apps}"
readonly BACKUP_DIR="${IOE_BACKUP_DIR:-${IOE_DATA_ROOT}/backups}"
readonly IOE_DATA_DIR="${IOE_INTERNAL_DATA_DIR:-${IOE_DATA_ROOT}}"
readonly MODEL_DIR="${IOE_MODEL_DIR:-${IOE_DATA_ROOT}/models}"
readonly INSTALL_DIR="${IOE_INSTALL_DIR:-/opt/ioe-matrix}"
readonly PANEL_DIR="${INSTALL_DIR}/ioe"

# Runtime infrastructure paths
readonly IOE_RUNTIME_DIR="${IOE_RUNTIME_DIR:-/opt/ioe-runtime}"
readonly IOE_PLUGIN_DIR="${IOE_PLUGIN_DIR:-${IOE_RUNTIME_DIR}/plugins}"
readonly IOE_HOOK_DIR="${IOE_HOOK_DIR:-${IOE_RUNTIME_DIR}/hooks}"
readonly IOE_STATE_DIR="${IOE_STATE_DIR:-/var/lib/ioe}"
readonly IOE_CONF_DIR="${IOE_CONF_DIR:-/etc/ioe}"
readonly IOE_SOCKET_DIR="${IOE_SOCKET_DIR:-/run/ioe}"

# Stable path for ioectl bootstrap environment
readonly IOE_INSTALL_ENV="${IOE_INSTALL_ENV:-/etc/ioe/install.env}"

# Installer internals
readonly LOCK_FILE="${IOE_LOCK_FILE:-/var/lock/ioe-install.lock}"
readonly LOG_FILE="${IOE_LOG_FILE:-/var/log/ioe-install.log}"
readonly LOG_MAX_LINES="${IOE_LOG_MAX_LINES:-5000}"
readonly LOG_MAX_BYTES="${IOE_LOG_MAX_BYTES:-10485760}"
readonly CRED_FILE="${IOE_CRED_FILE:-/root/.ioe-credentials}"
readonly MIN_DISK_MB="${IOE_MIN_DISK_MB:-10240}"
readonly MIN_MEM_MB="${IOE_MIN_MEM_MB:-900}"
readonly AUTO_SWAP="${IOE_AUTO_SWAP:-1}"
readonly SWAP_SIZE_GB="${IOE_SWAP_SIZE_GB:-4}"
PANEL_PORT="${IOE_PANEL_PORT:-3000}"
readonly HEALTHCHECK_TIMEOUT="${IOE_HEALTHCHECK_TIMEOUT:-120}"
readonly TOTAL_STEPS=13

FIREWALL_MODE="${IOE_FIREWALL_MODE:-standard}"
[[ "${NO_FIREWALL}" -eq 1 ]] && FIREWALL_MODE="none"

# Registry mirrors for restricted networks
readonly -a REGISTRY_MIRRORS=(
    "https://docker.m.daocloud.io"
    "https://mirror.baidubce.com"
    "https://hub-mirror.c.163.com"
    "https://dockerhub.azk8s.cn"
    "https://registry.docker-cn.com"
)

# ─────────────────────────────────────────────────────────────────────────────
# Colors & Logging
# ─────────────────────────────────────────────────────────────────────────────
BOLD="\033[1m"; GREEN="\033[32m"; RED="\033[31m"
YELLOW="\033[33m"; BLUE="\033[34m"; CYAN="\033[36m"; RESET="\033[0m"

STEP_N=0

_rotate_log_if_needed() {
    [[ -f "${LOG_FILE}" ]] || return 0
    local size
    size=$(stat -c%s "${LOG_FILE}" 2>/dev/null || echo 0)
    if [[ "${size}" -gt "${LOG_MAX_BYTES}" ]]; then
        tail -"${LOG_MAX_LINES}" "${LOG_FILE}" > "${LOG_FILE}.tmp" 2>/dev/null \
            && mv "${LOG_FILE}.tmp" "${LOG_FILE}" || true
    fi
}

_log() {
    mkdir -p "$(dirname "${LOG_FILE}")" 2>/dev/null || true
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "${LOG_FILE}" 2>/dev/null || true
    _rotate_log_if_needed
}

_progress_bar() {
    local pct="${1:-0}"
    [[ "${pct}" =~ ^[0-9]+$ ]] || pct=0
    (( pct < 0 )) && pct=0
    (( pct > 100 )) && pct=100
    local width=28
    local filled=$(( pct * width / 100 ))
    local empty=$(( width - filled ))
    local bar=""
    local i
    for ((i=0; i<filled; i++)); do bar+="#"; done
    for ((i=0; i<empty; i++)); do bar+="-"; done
    printf "\r%s[%s] %3d%%%s" "${CYAN}" "${bar}" "${pct}" "${RESET}"
    [[ "${pct}" -ge 100 ]] && printf "\n"
}

info()    { echo -e "${BLUE}[INFO]${RESET} $*";              _log "INFO  $*"; }
success() { echo -e "${GREEN}[✓]${RESET} $*";                _log "OK    $*"; }
warn()    { echo -e "${YELLOW}[!]${RESET} $*";               _log "WARN  $*"; }
fatal()   { echo -e "\n${RED}[✗]${RESET} ${BOLD}$*${RESET}"; _log "FATAL $*"; echo -e "${YELLOW}  → Full log: ${LOG_FILE}${RESET}"; exit 1; }

step() {
    STEP_N=$((STEP_N+1))
    local pct=$(( (STEP_N - 1) * 100 / TOTAL_STEPS ))
    _progress_bar "${pct}"
    echo -e "\n${CYAN}${BOLD}━━ Step ${STEP_N}/${TOTAL_STEPS}: $*${RESET}"
    _log "STEP ${STEP_N}/${TOTAL_STEPS}: $*"
}

# ─────────────────────────────────────────────────────────────────────────────
# Progress Spinner
# ─────────────────────────────────────────────────────────────────────────────
_SPINNER_PID=0

_spinner_start() {
    local msg="$1"
    printf "  %s: " "${msg}"
    (
        local i=0 chars='/-\|'
        while true; do
            printf '\b%s' "${chars:$i:1}"
            i=$(( (i+1) % 4 ))
            sleep 0.2
        done
    ) &
    _SPINNER_PID=$!
}

_spinner_stop() {
    local rc="${1:-0}" label="${2:-done}"
    if [[ "${_SPINNER_PID}" -ne 0 ]]; then
        kill "${_SPINNER_PID}" 2>/dev/null || true
        wait "${_SPINNER_PID}" 2>/dev/null || true
        _SPINNER_PID=0
    fi
    if [[ "${rc}" -eq 0 ]]; then
        printf '\b%b\n' "${GREEN}✓ ${label}${RESET}"
    else
        printf '\b%b\n' "${RED}✗ failed${RESET}"
    fi
}

_run_spin() {
    local label="$1"; shift
    _spinner_start "${label}"
    local rc=0
    "$@" >>"${LOG_FILE}" 2>&1 || rc=$?
    _spinner_stop "${rc}"
    return "${rc}"
}

# ─────────────────────────────────────────────────────────────────────────────
# Resilient Helpers
# ─────────────────────────────────────────────────────────────────────────────
_curl_first_success() {
    local out="$1"; shift
    local url
    for url in "$@"; do
        if curl -fsSL --connect-timeout 10 --retry 2 --retry-delay 3 \
               -o "${out}" "${url}" 2>/dev/null; then
            return 0
        fi
        _log "WARN  unreachable: ${url}"
    done
    return 1
}

_retry() {
    local max="$1"; shift
    local attempt=0
    while [[ "${attempt}" -lt "${max}" ]]; do
        attempt=$((attempt+1))
        "$@" && return 0
        if [[ "${attempt}" -lt "${max}" ]]; then
            local wait=$(( attempt * 5 ))
            warn "  Attempt ${attempt}/${max} failed — retrying in ${wait}s..."
            sleep "${wait}"
        fi
    done
    return 1
}

_is_valid_port() {
    local p="$1"
    [[ "${p}" =~ ^[0-9]+$ ]] && [[ "${p}" -ge 1 ]] && [[ "${p}" -le 65535 ]]
}

_shell_quote() {
    printf '%q' "$1"
}

# ─────────────────────────────────────────────────────────────────────────────
# Global State & Traps
# ─────────────────────────────────────────────────────────────────────────────
INSTALL_SUCCESS=0
ARCH="" OS="" OS_VER="" OS_CODENAME=""
PUBLIC_IP="" LOCAL_IP=""
VIRT_TYPE="none"
HAS_SYSTEMD=0
SKIP_FIREWALL=0
SKIP_SYSCTL=0
USER_SET_PANEL_PORT=0
[[ -n "${IOE_PANEL_PORT:-}" ]] && USER_SET_PANEL_PORT=1

IOE_GPU_PRESENT=0
IOE_GPU_VENDOR="none"
IOE_GPU_MODEL=""
IOE_GPU_RUNTIME_READY=0

trap '_on_err ${LINENO} "${BASH_COMMAND}"' ERR
trap '_on_exit' EXIT

_on_err() {
    [[ "${_SPINNER_PID}" -ne 0 ]] && { kill "${_SPINNER_PID}" 2>/dev/null || true; }
    echo ""
    fatal "Failed at line $1: $2"
}

_on_exit() {
    [[ "${INSTALL_SUCCESS}" -eq 1 ]] && { rm -f "${LOCK_FILE}"; return; }

    warn "Installation incomplete — attempting safe rollback of panel containers only..."
    if command -v docker >/dev/null 2>&1 && [[ -d "${PANEL_DIR}" ]]; then
        cd "${PANEL_DIR}" 2>/dev/null && docker compose down --remove-orphans >/dev/null 2>&1 || true
    fi
    rm -f "${LOCK_FILE}" 2>/dev/null || true
    echo -e "${YELLOW}  Data directories preserved. Fix the issue and re-run install-ioe.sh.${RESET}"
}

# ─────────────────────────────────────────────────────────────────────────────
# Banner
# ─────────────────────────────────────────────────────────────────────────────
banner() {
    echo -e "${CYAN}${BOLD}"
    cat <<'BANNER'
  ██╗ ██████╗ ███████╗    ███╗   ███╗ █████╗ ████████╗██████╗ ██╗██╗  ██╗
  ██║██╔═══██╗██╔════╝    ████╗ ████║██╔══██╗╚══██╔══╝██╔══██╗██║╚██╗██╔╝
  ██║██║   ██║█████╗      ██╔████╔██║███████║   ██║   ██████╔╝██║ ╚███╔╝
  ██║██║   ██║██╔══╝      ██║╚██╔╝██║██╔══██║   ██║   ██╔══██╗██║ ██╔██╗
  ██║╚██████╔╝███████╗    ██║ ╚═╝ ██║██║  ██║   ██║   ██║  ██║██║██╔╝ ██╗
  ╚═╝ ╚═════╝ ╚══════╝    ╚═╝     ╚═╝╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝╚═╝╚═╝  ╚═╝
BANNER
    echo -e "${RESET}  ${BOLD}IOE AI Env Installer${RESET} v${INSTALLER_VERSION}"
    echo -e "  Profile    : ${INSTALLER_PROFILE}"
    echo -e "  Repository : ${PANEL_REPO}"
    echo -e "  Version    : ${PANEL_VERSION}"
    echo -e "  $(date '+%Y-%m-%d %H:%M:%S %Z')\n"
}

# =============================================================================
# Environment Detection Helpers
# =============================================================================
_detect_virtualization() {
    VIRT_TYPE="$(systemd-detect-virt 2>/dev/null || true)"
    [[ -z "${VIRT_TYPE}" ]] && VIRT_TYPE="none"

    if grep -qiE '(microsoft|wsl)' /proc/version 2>/dev/null; then
        VIRT_TYPE="wsl"
    fi

    HAS_SYSTEMD=0
    [[ -d /run/systemd/system ]] && command -v systemctl &>/dev/null && HAS_SYSTEMD=1

    case "${VIRT_TYPE}" in
        wsl|docker|podman|container)
            SKIP_FIREWALL=1
            SKIP_SYSCTL=1
            ;;
        lxc|openvz)
            SKIP_SYSCTL=1
            ;;
    esac

    [[ "${FIREWALL_MODE}" == "none" ]] && SKIP_FIREWALL=1

    info "Environment: virt=${VIRT_TYPE}, systemd=${HAS_SYSTEMD}, firewall_mode=${FIREWALL_MODE}, skip_firewall=${SKIP_FIREWALL}, skip_sysctl=${SKIP_SYSCTL}"
}

_port_in_use() {
    local port="$1"
    command -v ss >/dev/null 2>&1 || return 1
    ss -H -ltn 2>/dev/null | awk -v p=":${port}" '{print $4}' | grep -Eq "(^|[^0-9])${port}$|${p}$"
}

_choose_panel_port() {
    _is_valid_port "${PANEL_PORT}" || fatal "Invalid panel port: ${PANEL_PORT}. Use 1-65535."

    if [[ -f "${PANEL_DIR}/.env" ]]; then
        local env_port
        env_port=$(grep '^PANEL_PORT=' "${PANEL_DIR}/.env" | tail -n1 | cut -d= -f2 || echo "")
        if [[ -n "${env_port}" ]]; then
            if _is_valid_port "${env_port}"; then
                PANEL_PORT="${env_port}"
                info "Using PANEL_PORT=${PANEL_PORT} from existing .env"
            else
                warn "Ignoring invalid PANEL_PORT in existing .env: ${env_port}"
            fi
        fi
    fi

    if _port_in_use "${PANEL_PORT}"; then
        if [[ "${USER_SET_PANEL_PORT}" -eq 1 ]]; then
            fatal "Configured panel port ${PANEL_PORT} is already in use. Set IOE_PANEL_PORT to another port."
        fi

        warn "Default port ${PANEL_PORT} is already in use. Searching for a free port..."
        local p
        for p in $(seq 3001 3099); do
            if ! _port_in_use "${p}"; then
                PANEL_PORT="${p}"
                warn "Using available panel port: ${PANEL_PORT}"
                return
            fi
        done
        fatal "No free panel port found in range 3001-3099. Set IOE_PANEL_PORT manually."
    fi
}

_get_local_ip() {
    local ip_addr=""
    if command -v ip >/dev/null 2>&1; then
        ip_addr=$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}' || true)
    fi
    if [[ -z "${ip_addr}" ]]; then
        ip_addr=$(hostname -I 2>/dev/null | awk '{print $1}' || true)
    fi
    [[ -z "${ip_addr}" ]] && ip_addr="127.0.0.1"
    printf '%s\n' "${ip_addr}"
}

_get_public_ip() {
    local ip_addr=""
    ip_addr=$(curl -sf --connect-timeout 4 https://api.ipify.org 2>/dev/null || true)
    [[ -z "${ip_addr}" ]] && ip_addr=$(curl -sf --connect-timeout 4 https://ifconfig.me 2>/dev/null || true)
    [[ -z "${ip_addr}" ]] && ip_addr=$(curl -sf --connect-timeout 4 https://icanhazip.com 2>/dev/null || true)
    ip_addr=$(printf '%s' "${ip_addr}" | tr -d '[:space:]')
    [[ -z "${ip_addr}" ]] && ip_addr="${LOCAL_IP:-127.0.0.1}"
    printf '%s\n' "${ip_addr}"
}

_auto_gpu_probe() {
    IOE_GPU_PRESENT=0
    IOE_GPU_VENDOR="none"
    IOE_GPU_MODEL=""
    IOE_GPU_RUNTIME_READY=0

    info "Probing AI acceleration hardware..."

    if command -v nvidia-smi &>/dev/null; then
        IOE_GPU_PRESENT=1
        IOE_GPU_VENDOR="nvidia"
        IOE_GPU_MODEL="$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -n 1 || true)"
        [[ -z "${IOE_GPU_MODEL}" ]] && IOE_GPU_MODEL="nvidia-unknown"

        if command -v docker >/dev/null 2>&1 && docker info 2>/dev/null | grep -qi 'nvidia'; then
            IOE_GPU_RUNTIME_READY=1
            success "NVIDIA GPU detected and Docker GPU runtime appears available: ${IOE_GPU_MODEL}"
        else
            success "NVIDIA GPU detected: ${IOE_GPU_MODEL}"
            warn "Docker GPU runtime is not configured yet. Install NVIDIA Container Toolkit later if GPU containers are needed."
        fi
    else
        info "No NVIDIA GPU detected. Defaulting to CPU execution."
    fi
}

# =============================================================================
# Self-Update Check (only when following 'main' branch)
# =============================================================================
_check_self_update() {
    local latest_ver
    latest_ver=$(curl -sf --connect-timeout 5 --max-time 8 \
        "https://raw.githubusercontent.com/yatenetworks/ioe/main/INSTALLER_VERSION" 2>/dev/null || true)
    latest_ver=$(printf '%s' "${latest_ver}" | tr -d '[:space:]')
    if [[ -n "${latest_ver}" && "${latest_ver}" != "${INSTALLER_VERSION}" ]]; then
        warn "A newer installer version is available: ${latest_ver} (current: ${INSTALLER_VERSION})."
        warn "Consider updating before installation: curl -fsSL https://raw.githubusercontent.com/yatenetworks/ioe/main/install-ioe.sh | bash"
    fi
}

# =============================================================================
# Step 1 — Lock & Root
# =============================================================================
preflight_lock_and_root() {
    step "Preflight checks"

    [[ "${EUID}" -ne 0 ]] && fatal "Root required. Run: sudo bash install-ioe.sh"

    mkdir -p "$(dirname "${LOCK_FILE}")"

    if command -v flock &>/dev/null; then
        exec 200>>"${LOCK_FILE}"
        flock -w 10 200 2>/dev/null \
            || fatal "Another installer is running or the lock is busy: ${LOCK_FILE}"
        echo $$ >&200
    else
        if [[ -f "${LOCK_FILE}" ]]; then
            local pid
            pid=$(cat "${LOCK_FILE}" 2>/dev/null || echo 0)
            if [[ "${pid}" =~ ^[0-9]+$ ]] && kill -0 "${pid}" 2>/dev/null; then
                fatal "Another installer is already running (PID ${pid})."
            fi
            warn "Removing stale lock file: ${LOCK_FILE}"
            rm -f "${LOCK_FILE}"
        fi
        echo $$ > "${LOCK_FILE}"
    fi

    mkdir -p "$(dirname "${LOG_FILE}")"
    if [[ -f "${LOG_FILE}" ]]; then
        local lines
        lines=$(wc -l < "${LOG_FILE}" 2>/dev/null || echo 0)
        [[ "${lines}" -gt "${LOG_MAX_LINES}" ]] \
            && tail -"${LOG_MAX_LINES}" "${LOG_FILE}" > "${LOG_FILE}.tmp" \
            && mv "${LOG_FILE}.tmp" "${LOG_FILE}" || true
        mv "${LOG_FILE}" "${LOG_FILE}.prev" 2>/dev/null || true
    fi
    echo "═══ IOE AI Env Install Log — $(date) ═══" > "${LOG_FILE}"
    chmod 640 "${LOG_FILE}" 2>/dev/null || true

    success "Root confirmed"
}

# =============================================================================
# Step 2 — System Detection
# =============================================================================
detect_system() {
    step "System detection"

    [[ ! -f /etc/os-release ]] && fatal "/etc/os-release not found — unsupported environment."

    OS=$(grep '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
    OS_VER=$(grep '^VERSION_ID=' /etc/os-release | cut -d= -f2 | tr -d '"' || echo "")
    OS_CODENAME=$(grep '^VERSION_CODENAME=' /etc/os-release | cut -d= -f2 | tr -d '"' 2>/dev/null || \
                  grep '^UBUNTU_CODENAME='  /etc/os-release | cut -d= -f2 | tr -d '"' 2>/dev/null || echo "")

    case "$(uname -m)" in
        x86_64|amd64)  ARCH="amd64" ;;
        aarch64|arm64) ARCH="arm64" ;;
        armv7l)        ARCH="arm" ;;
        *) fatal "Unsupported CPU architecture: $(uname -m)" ;;
    esac

    _detect_virtualization

    command -v podman   &>/dev/null && warn "Podman detected — ensure no port/network conflicts with Docker."
    command -v k3s      &>/dev/null && warn "K3s detected — ensure no port/namespace conflicts."
    command -v microk8s &>/dev/null && warn "MicroK8s detected — check port availability."

    if command -v getenforce &>/dev/null; then
        info "SELinux: $(getenforce 2>/dev/null || echo 'unavailable')"
    fi

    LOCAL_IP=$(_get_local_ip)
    PUBLIC_IP=$(_get_public_ip)

    success "OS: ${OS} ${OS_VER} (${OS_CODENAME:-no-codename}) | Arch: ${ARCH} | Local IP: ${LOCAL_IP} | Public IP: ${PUBLIC_IP}"
}

# =============================================================================
# Step 3 — Network
# =============================================================================
preflight_network() {
    step "Network connectivity"

    local -a endpoints=("https://github.com" "https://raw.githubusercontent.com" "https://registry-1.docker.io")
    local ok=0
    local ep
    for ep in "${endpoints[@]}"; do
        curl -Is --connect-timeout 8 --max-time 12 "${ep}" >/dev/null 2>&1 && { ok=1; break; }
        _log "WARN  slow/unreachable: ${ep}"
    done
    [[ "${ok}" -eq 0 ]] && fatal \
        "No network connectivity.\n  → DNS check:  dig github.com\n  → Firewall:   iptables -L\n  → Proxy:      env | grep -i proxy"

    _choose_panel_port

    success "Network OK (panel port: ${PANEL_PORT})"
}

# =============================================================================
# Step 4 — Hardware
# =============================================================================
preflight_hardware() {
    step "Hardware requirements"

    local disk_free
    disk_free=$(df -m / | awk 'NR==2{print $4}')
    [[ "${disk_free}" -lt "${MIN_DISK_MB}" ]] \
        && fatal "Only ${disk_free}MB free on /. ${MIN_DISK_MB}MB minimum required.\n  → Free space: docker system prune -af"
    success "Disk: ${disk_free}MB available"

    local inode_pct
    inode_pct=$(df -i / 2>/dev/null | awk 'NR==2{gsub(/%/,"",$5); print $5}' || echo 0)
    [[ "${inode_pct}" -gt 80 ]] \
        && warn "Inode usage at ${inode_pct}% — risk of 'No space left' despite free disk."

    local mem_total
    mem_total=$(free -m | awk '/^Mem:/{print $2}')
    [[ "${mem_total}" -lt "${MIN_MEM_MB}" ]] \
        && fatal "Only ${mem_total}MB RAM — ${MIN_MEM_MB}MB minimum required."

    if [[ "${mem_total}" -lt 2048 ]]; then
        warn "RAM: ${mem_total}MB — install can proceed; 2GB+ recommended for heavier container workloads."
    else
        success "RAM: ${mem_total}MB"
    fi
}

# =============================================================================
# Step 4b — Adaptive Swap Provisioning
# =============================================================================
_force_swap_fix() {
    [[ "${AUTO_SWAP}" == "1" ]] || { info "Auto swap disabled by IOE_AUTO_SWAP=${AUTO_SWAP}."; return 0; }

    local mem_total swap_total disk_free swap_mb
    mem_total=$(free -m | awk '/^Mem:/{print $2}')
    swap_total=$(free -m | awk '/^Swap:/{print $2}')
    disk_free=$(df -m / | awk 'NR==2{print $4}')
    swap_mb=$(( SWAP_SIZE_GB * 1024 ))

    case "${VIRT_TYPE:-none}" in
        wsl|docker|podman|container|openvz)
            info "Swap auto-provision skipped in ${VIRT_TYPE} environment."
            return 0
            ;;
    esac

    # Container workloads on 2-4 GB RAM machines benefit from swap.
    if [[ "${mem_total}" -lt 4000 && "${swap_total}" -lt 2048 ]]; then
        if [[ "${disk_free}" -lt $(( swap_mb + 2048 )) ]]; then
            if [[ "${mem_total}" -lt "${MIN_MEM_MB}" ]]; then
                fatal "Memory critically low (${mem_total}MB) and insufficient disk for swap. Install cannot proceed."
            else
                warn "Low RAM (${mem_total}MB) and insufficient disk for ${SWAP_SIZE_GB}GB swap. Continuing, but performance may be degraded."
            fi
            return 0
        fi

        info "Low RAM (${mem_total}MB) detected. Provisioning ${SWAP_SIZE_GB}GB swap for container workload stability..."

        if [[ -f /swapfile ]]; then
            warn "/swapfile already exists. Enabling it."
            swapon /swapfile 2>/dev/null || true
        else
            fallocate -l "${SWAP_SIZE_GB}G" /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count="${swap_mb}" >>"${LOG_FILE}" 2>&1
            chmod 600 /swapfile
            mkswap /swapfile >>"${LOG_FILE}" 2>&1 || { warn "mkswap failed. Continuing without swap."; return 0; }
            swapon /swapfile >>"${LOG_FILE}" 2>&1 || { warn "swapon failed. Continuing without swap."; return 0; }
        fi

        grep -qE '^/swapfile[[:space:]]+none[[:space:]]+swap' /etc/fstab 2>/dev/null \
            || echo '/swapfile none swap sw 0 0' >> /etc/fstab

        success "Swap configured: ${SWAP_SIZE_GB}GB enabled."
    else
        info "Swap check OK: RAM=${mem_total}MB, Swap=${swap_total}MB."
    fi
}

# =============================================================================
# Step 5 — Base Packages
# =============================================================================
install_base_packages() {
    step "System packages"
    export DEBIAN_FRONTEND=noninteractive

    case "${OS}" in
        ubuntu|debian|raspbian)
            _run_spin "Updating package index" apt-get update -qq
            _run_spin "Installing dependencies" \
                apt-get install -y -qq \
                    curl git openssl ca-certificates gnupg lsb-release \
                    ufw fail2ban jq net-tools util-linux iproute2 procps uuid-runtime \
                    -o Dpkg::Options::="--force-confdef" \
                    -o Dpkg::Options::="--force-confold"
            ;;
        rocky|almalinux|centos|rhel|ol|anolis|alinux|openeuler|openEuler|tencentos)
            _run_spin "Updating package cache" dnf makecache -q
            _run_spin "Installing dependencies" \
                dnf install -y -q \
                    curl git openssl ca-certificates gnupg \
                    firewalld fail2ban jq net-tools util-linux yum-utils iproute procps-ng
            ;;
        *)
            fatal "Unsupported OS: ${OS}. Supported: ubuntu, debian, rocky, almalinux, centos, rhel and compatible distributions."
            ;;
    esac
    success "Packages ready"
}

# =============================================================================
# Step 6 — Conservative Security Baseline
# =============================================================================
configure_security() {
    step "Security baseline"
    _configure_firewall
    _configure_fail2ban
    _configure_sysctl
    _configure_journald
    _security_notice
}

_configure_firewall() {
    if [[ "${SKIP_FIREWALL}" -eq 1 ]]; then
        warn "Firewall configuration skipped. mode=${FIREWALL_MODE}, virt=${VIRT_TYPE}"
        return
    fi

    if command -v ufw &>/dev/null; then
        local has_rules=0 is_enabled=0
        ufw status 2>/dev/null | grep -q "Status: active" && is_enabled=1
        local rule_count
        rule_count=$(ufw status numbered 2>/dev/null | grep -c '^\[' || true)
        [[ "${rule_count}" -gt 0 ]] && has_rules=1

        if [[ "${is_enabled}" -eq 1 || "${has_rules}" -eq 1 ]]; then
            info "Existing UFW configuration detected — preserving all rules."
            local p
            for p in 22 80 443 "${PANEL_PORT}"; do
                ufw allow "${p}"/tcp >/dev/null 2>&1 || true
            done
            success "UFW: required ports ensured without reset (22/80/443/${PANEL_PORT})"
        else
            info "Fresh UFW environment — applying baseline policy."
            ufw --force reset >/dev/null 2>&1
            ufw default deny incoming >/dev/null 2>&1
            ufw default allow outgoing >/dev/null 2>&1
            ufw allow 22/tcp >/dev/null 2>&1
            ufw allow 80/tcp >/dev/null 2>&1
            ufw allow 443/tcp >/dev/null 2>&1
            ufw allow "${PANEL_PORT}"/tcp >/dev/null 2>&1
            ufw --force enable >/dev/null 2>&1
            success "UFW baseline configured: 22/80/443/${PANEL_PORT}"
        fi
        return
    fi

    if command -v firewall-cmd &>/dev/null && [[ "${HAS_SYSTEMD}" -eq 1 ]] && systemctl is-active firewalld &>/dev/null; then
        firewall-cmd --permanent --add-service=ssh   >/dev/null 2>&1 || true
        firewall-cmd --permanent --add-service=http  >/dev/null 2>&1 || true
        firewall-cmd --permanent --add-service=https >/dev/null 2>&1 || true
        firewall-cmd --permanent --add-port="${PANEL_PORT}"/tcp >/dev/null 2>&1 || true
        firewall-cmd --reload >/dev/null 2>&1 || true
        success "firewalld: required ports ensured (ssh/http/https/${PANEL_PORT})"
        return
    fi

    warn "No supported firewall manager found. Ensure cloud security group allows 22/80/443/${PANEL_PORT}."
}

_configure_fail2ban() {
    command -v fail2ban-server &>/dev/null || return
    if [[ "${HAS_SYSTEMD}" -ne 1 ]]; then
        warn "fail2ban service start skipped because systemd is unavailable."
        return
    fi

    if [[ ! -f /etc/fail2ban/jail.local ]]; then
        cat > /etc/fail2ban/jail.local <<'EOF'
[DEFAULT]
bantime  = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
EOF
        chmod 644 /etc/fail2ban/jail.local 2>/dev/null || true
    else
        info "Existing fail2ban jail.local preserved."
    fi

    systemctl enable fail2ban >/dev/null 2>&1 || true
    systemctl restart fail2ban >/dev/null 2>&1 || true
    success "fail2ban: SSH brute-force protection enabled or preserved"
}

_configure_sysctl() {
    if [[ "${SKIP_SYSCTL}" -eq 1 ]]; then
        warn "sysctl tuning skipped in ${VIRT_TYPE} environment."
        return
    fi
    if [[ -f /etc/sysctl.d/99-ioe.conf ]]; then
        info "sysctl 99-ioe.conf already present — skipping."
        return
    fi
    cat > /etc/sysctl.d/99-ioe.conf <<'EOF'
# IOE AI Env Installer — conservative kernel tuning for containerized workloads
net.ipv4.conf.all.rp_filter           = 1
net.ipv4.conf.default.rp_filter       = 1
net.ipv4.icmp_echo_ignore_broadcasts  = 1
net.ipv4.conf.all.accept_source_route = 0
net.core.somaxconn                    = 65535
fs.inotify.max_user_watches           = 1048576
fs.inotify.max_user_instances         = 1024
vm.max_map_count                      = 262144
EOF
    sysctl -p /etc/sysctl.d/99-ioe.conf >/dev/null 2>&1 || true
    success "Kernel parameters applied"
}

_configure_journald() {
    [[ "${HAS_SYSTEMD}" -eq 1 ]] || { warn "journald limit skipped because systemd is unavailable."; return; }
    command -v journalctl &>/dev/null || return
    [[ -f /etc/systemd/journald.conf.d/ioe.conf ]] && { info "journald IOE limit already exists — skipping."; return; }
    mkdir -p /etc/systemd/journald.conf.d
    cat > /etc/systemd/journald.conf.d/ioe.conf <<'EOF'
[Journal]
SystemMaxUse=1G
MaxFileSec=7day
EOF
    systemctl reload systemd-journald 2>/dev/null || true
    success "journald limits: 1GB max, 7-day retention"
}

_security_notice() {
    warn "Installer keeps SSH reachable to prevent lockout."
    warn "After first login, run: ioectl security"
    warn "Recommended later: disable SSH password login, enable HTTPS, configure backup, and restrict panel access if possible."
}

# =============================================================================
# Step 7 — Docker
# =============================================================================
install_docker() {
    step "Docker engine"

    if command -v docker &>/dev/null; then
        local ver driver
        ver=$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo "unknown")
        driver=$(docker info --format '{{.Driver}}' 2>/dev/null || echo "unknown")
        success "Docker already installed (v${ver}, storage=${driver})"
        if [[ "${driver}" != "overlay2" && "${driver}" != "unknown" ]]; then
            warn "Docker storage driver is '${driver}', not overlay2. Existing Docker storage is preserved to avoid breaking current images/containers."
        fi
    else
        case "${OS}" in
            ubuntu|debian|raspbian)
                _run_spin "Installing Docker (GPG-verified)" _install_docker_deb
                ;;
            rocky|almalinux|centos|rhel|ol|anolis|alinux|openeuler|openEuler|tencentos)
                _run_spin "Installing Docker (GPG-verified)" _install_docker_rpm
                ;;
            *)
                fatal "Cannot auto-install Docker on '${OS}'. Install Docker manually and re-run."
                ;;
        esac

        if [[ "${HAS_SYSTEMD}" -eq 1 ]]; then
            systemctl enable docker >/dev/null 2>&1 || true
            systemctl start docker  >/dev/null 2>&1 || true
        else
            warn "systemd unavailable — attempting background dockerd start."
            if command -v dockerd >/dev/null 2>&1; then
                nohup dockerd >/var/log/ioe-dockerd.log 2>&1 &
                sleep 5
            else
                warn "dockerd binary not found after install attempt."
            fi
        fi
        success "Docker installed"
    fi

    info "Waiting for Docker daemon..."
    local retry=0
    until docker info >/dev/null 2>&1; do
        retry=$((retry+1))
        if [[ "${retry}" -gt 20 ]]; then
            if [[ "${HAS_SYSTEMD}" -ne 1 ]]; then
                fatal "Docker daemon not running. Check /var/log/ioe-dockerd.log or start Docker manually and re-run."
            else
                fatal "Docker daemon timeout.\n  → Check: systemctl status docker\n  → Logs: journalctl -u docker -n 50"
            fi
        fi
        sleep 2
    done

    docker compose version >/dev/null 2>&1 || _run_spin "Installing Compose plugin" _install_compose_plugin
    success "Docker Compose $(docker compose version --short 2>/dev/null || echo 'available')"
}

_install_docker_deb() {
    apt-get remove -y docker docker-engine docker.io containerd runc >/dev/null 2>&1 || true
    apt-get install -y -qq ca-certificates curl gnupg lsb-release >/dev/null 2>&1
    install -m 0755 -d /etc/apt/keyrings

    local gpg_tmp
    gpg_tmp=$(mktemp)
    _curl_first_success "${gpg_tmp}" \
        "https://download.docker.com/linux/${OS}/gpg" \
        "https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/${OS}/gpg" \
        || fatal "Cannot fetch Docker GPG key."
    rm -f /etc/apt/keyrings/docker.gpg
    gpg --dearmor -o /etc/apt/keyrings/docker.gpg < "${gpg_tmp}"
    rm -f "${gpg_tmp}"
    chmod a+r /etc/apt/keyrings/docker.gpg

    if [[ -z "${OS_CODENAME}" ]]; then
        OS_CODENAME=$(lsb_release -cs 2>/dev/null || echo "")
        [[ -z "${OS_CODENAME}" ]] && fatal "Cannot determine OS codename."
    fi

    if [[ "${OS}" == "debian" && "${OS_CODENAME}" == "trixie" ]]; then
        warn "Debian 13/trixie detected. Docker official repo support may depend on Docker release timing."
        warn "If Docker repo update fails, use Debian 12/bookworm or install Docker manually before re-running."
    fi

    cat > /etc/apt/sources.list.d/docker.list <<EOF
# IOE AI Env Installer — managed Docker CE source
deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${OS} ${OS_CODENAME} stable
EOF

    if ! apt-get update -qq; then
        if [[ "${OS}" == "debian" && "${OS_CODENAME}" == "trixie" ]]; then
            fatal "Docker APT repository failed for Debian 13/trixie.\n  Safer options:\n  1) Use Debian 12/bookworm or Ubuntu 24.04 LTS.\n  2) Install Docker manually, then re-run this installer.\n  3) Check /etc/apt/sources.list.d/docker.list."
        fi
        fatal "Docker APT repository update failed. Check network, DNS, proxy, and OS codename: ${OS_CODENAME}."
    fi

    apt-get install -y -qq \
        docker-ce docker-ce-cli containerd.io \
        docker-buildx-plugin docker-compose-plugin
}

_install_docker_rpm() {
    dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo >/dev/null 2>&1 \
        || fatal "Cannot add Docker CE repo."
    _retry 3 dnf install -y -q \
        docker-ce docker-ce-cli containerd.io \
        docker-buildx-plugin docker-compose-plugin
}

_install_compose_plugin() {
    case "${OS}" in
        ubuntu|debian|raspbian)
            apt-get install -y -qq docker-compose-plugin
            ;;
        rocky|almalinux|centos|rhel|ol|anolis|alinux|openeuler|openEuler|tencentos)
            dnf install -y -q docker-compose-plugin
            ;;
        *)
            warn "Cannot auto-install Compose plugin on ${OS}. Install manually."
            ;;
    esac
}

# =============================================================================
# Step 8 — Docker Daemon & Time Sync
# =============================================================================
configure_docker_and_timesync() {
    step "Docker daemon config & time sync"
    _configure_docker_daemon
    _configure_timesync
}

_configure_docker_daemon() {
    local daemon_file="/etc/docker/daemon.json"
    local use_mirror="${FORCE_MIRROR}"

    if [[ "${use_mirror}" -eq 0 ]]; then
        if ! curl -sf --connect-timeout 5 --max-time 6 https://registry-1.docker.io/v2/ >/dev/null 2>&1; then
            warn "Docker Hub looks unreachable. Automatically enabling mirror acceleration."
            use_mirror=1
        fi
    fi

    if [[ -f "${daemon_file}" ]]; then
        info "Existing daemon.json preserved — no changes made."
        if [[ "${use_mirror}" -eq 1 ]]; then
            warn "Mirror acceleration was requested/detected, but existing daemon.json will not be overwritten."
            warn "  → Add registry-mirrors manually to: ${daemon_file}"
        fi
        return
    fi

    local mirrors_block=""
    if [[ "${use_mirror}" -eq 1 ]]; then
        local mirror_list=""
        local m
        for m in "${REGISTRY_MIRRORS[@]}"; do mirror_list+="\"${m}\","; done
        mirror_list="${mirror_list%,}"
        mirrors_block="\"registry-mirrors\": [${mirror_list}],"
    fi

    mkdir -p /etc/docker
    cat > "${daemon_file}" <<EOF
{
  ${mirrors_block}
  "storage-driver": "overlay2",
  "default-ulimits": {
    "nofile": { "Name": "nofile", "Hard": 65535, "Soft": 65535 }
  },
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "50m",
    "max-file": "3"
  }
}
EOF
    chown root:root "${daemon_file}" 2>/dev/null || true
    chmod 640 "${daemon_file}"

    if [[ "${HAS_SYSTEMD}" -eq 1 ]] && systemctl is-active docker >/dev/null 2>&1; then
        if systemctl reload docker 2>/dev/null; then
            info "Docker daemon reloaded."
        else
            warn "Docker reload unsupported; restart skipped to avoid interrupting running containers."
            warn "  Apply daemon.json later with: systemctl restart docker"
        fi
    fi

    [[ "${use_mirror}" -eq 1 ]] && success "daemon.json: overlay2 + mirrors + ulimits + log limits" || success "daemon.json: overlay2 + ulimits + log limits configured"
}

_configure_timesync() {
    if [[ "${HAS_SYSTEMD}" -ne 1 ]]; then
        warn "Time sync service configuration skipped because systemd is unavailable."
        return
    fi

    if systemctl list-unit-files 2>/dev/null | grep -q '^systemd-timesyncd.service'; then
        systemctl enable --now systemd-timesyncd >/dev/null 2>&1 || true
        success "Time sync: systemd-timesyncd active"
        return
    fi

    case "${OS}" in
        ubuntu|debian|raspbian)
            apt-get install -y -qq chrony >>"${LOG_FILE}" 2>&1 || true
            ;;
        rocky|almalinux|centos|rhel|ol|anolis|alinux|openeuler|openEuler|tencentos)
            dnf install -y -q chrony >>"${LOG_FILE}" 2>&1 || true
            ;;
    esac

    if command -v chronyd &>/dev/null; then
        systemctl enable --now chronyd >/dev/null 2>&1 || true
        success "Time sync: chrony active"
    else
        warn "No time sync service found; system time may drift."
    fi
}

# =============================================================================
# Step 9 — Local Runtime
# =============================================================================
prepare_runtime_infrastructure() {
    step "Local runtime"

    mkdir -p "${IOE_DATA_ROOT}" "${DATA_DIR}" "${BACKUP_DIR}" "${MODEL_DIR}" "${INSTALL_DIR}" "${IOE_DATA_DIR}/telemetry"
    chmod 755 "${DATA_DIR}" "${MODEL_DIR}" 2>/dev/null || true
    chmod 700 "${IOE_DATA_DIR}" 2>/dev/null || true

    mkdir -p \
        "${IOE_RUNTIME_DIR}/plugins"       \
        "${IOE_RUNTIME_DIR}/hooks"         \
        "${IOE_RUNTIME_DIR}/net"           \
        "${IOE_RUNTIME_DIR}/policies"      \
        "${IOE_RUNTIME_DIR}/adapters"      \
        "${IOE_RUNTIME_DIR}/capabilities"  \
        "${IOE_RUNTIME_DIR}/runtimes"      \
        "${IOE_RUNTIME_DIR}/transports"    \
        "${IOE_RUNTIME_DIR}/schedulers"    \
        "${IOE_RUNTIME_DIR}/wasm"          \
        "${IOE_RUNTIME_DIR}/federation"    \
        "${IOE_RUNTIME_DIR}/sandbox"
    chmod 755 "${IOE_RUNTIME_DIR}" 2>/dev/null || true

    mkdir -p \
        "${IOE_STATE_DIR}/state"     \
        "${IOE_STATE_DIR}/events"    \
        "${IOE_STATE_DIR}/cache"     \
        "${IOE_STATE_DIR}/snapshots" \
        "${IOE_STATE_DIR}/queues"
    chmod 755 "${IOE_STATE_DIR}" 2>/dev/null || true

    mkdir -p "${IOE_CONF_DIR}" "${IOE_SOCKET_DIR}" "$(dirname "${IOE_INSTALL_ENV}")"
    chmod 755 "${IOE_CONF_DIR}" "${IOE_SOCKET_DIR}" 2>/dev/null || true

    if [[ ! -f "${IOE_CONF_DIR}/node-id" ]]; then
        local node_id
        node_id=$(uuidgen 2>/dev/null \
               || cat /proc/sys/kernel/random/uuid 2>/dev/null \
               || { tr -dc 'a-f0-9' < /dev/urandom | head -c32; echo; })
        echo "${node_id}" > "${IOE_CONF_DIR}/node-id"
        chmod 644 "${IOE_CONF_DIR}/node-id" 2>/dev/null || true
        info "Node identity generated: ${node_id}"
    else
        info "Node identity preserved: $(cat "${IOE_CONF_DIR}/node-id")"
    fi

    if [[ ! -f "${IOE_CONF_DIR}/runtime.toml" ]]; then
        local node_id
        node_id=$(cat "${IOE_CONF_DIR}/node-id")
        cat > "${IOE_CONF_DIR}/runtime.toml" <<EOF
# IOE AI Env — Runtime Configuration v1alpha
[runtime]
enabled = false
version = "v1alpha"

[node]
id   = "${node_id}"
role = "standalone"

[network]
mesh_enabled       = false
federation_enabled = false
overlay_enabled    = false

[plugins]
auto_load  = true
hot_reload = false

[sandbox]
apps_root   = "${DATA_DIR}"
models_root = "${MODEL_DIR}"

[policy]
allow_remote_control   = false
allow_unsigned_plugins = false

[telemetry]
enabled = false
EOF
        chmod 644 "${IOE_CONF_DIR}/runtime.toml" 2>/dev/null || true
    fi

    if [[ ! -f "${IOE_RUNTIME_DIR}/runtime.json" ]]; then
        cat > "${IOE_RUNTIME_DIR}/runtime.json" <<'EOF'
{
  "runtime_version": "1",
  "plugin_api": "v1",
  "capabilities": [],
  "net_modules": [],
  "hooks": []
}
EOF
        chmod 644 "${IOE_RUNTIME_DIR}/runtime.json" 2>/dev/null || true
    fi

    [[ ! -f "${IOE_CONF_DIR}/policy.toml" ]]     && touch "${IOE_CONF_DIR}/policy.toml"
    [[ ! -f "${IOE_CONF_DIR}/federation.toml" ]] && touch "${IOE_CONF_DIR}/federation.toml"

    _write_install_env

    success "Extension slots: ${IOE_RUNTIME_DIR}"
    success "State:           ${IOE_STATE_DIR}"
    success "Config:          ${IOE_CONF_DIR}/runtime.toml"
    success "Manifest:        ${IOE_RUNTIME_DIR}/runtime.json"
}

_write_install_env() {
    mkdir -p "$(dirname "${IOE_INSTALL_ENV}")"
    cat > "${IOE_INSTALL_ENV}" <<EOF
INSTALLER_VERSION=$(_shell_quote "${INSTALLER_VERSION}")
INSTALLER_PROFILE=$(_shell_quote "${INSTALLER_PROFILE}")
PANEL_REPO=$(_shell_quote "${PANEL_REPO}")
PANEL_VERSION=$(_shell_quote "${PANEL_VERSION}")
PANEL_PORT=$(_shell_quote "${PANEL_PORT}")
PANEL_DIR=$(_shell_quote "${PANEL_DIR}")
DATA_DIR=$(_shell_quote "${DATA_DIR}")
MODEL_DIR=$(_shell_quote "${MODEL_DIR}")
IOE_DATA_ROOT=$(_shell_quote "${IOE_DATA_ROOT}")
IOE_DATA_HOST_PATH=$(_shell_quote "${IOE_DATA_ROOT}")
BACKUP_DIR=$(_shell_quote "${BACKUP_DIR}")
IOE_RUNTIME_DIR=$(_shell_quote "${IOE_RUNTIME_DIR}")
IOE_PLUGIN_DIR=$(_shell_quote "${IOE_PLUGIN_DIR}")
IOE_HOOK_DIR=$(_shell_quote "${IOE_HOOK_DIR}")
IOE_STATE_DIR=$(_shell_quote "${IOE_STATE_DIR}")
IOE_CONF_DIR=$(_shell_quote "${IOE_CONF_DIR}")
IOE_INSTALL_ENV=$(_shell_quote "${IOE_INSTALL_ENV}")
CRED_FILE=$(_shell_quote "${CRED_FILE}")
LOG_FILE=$(_shell_quote "${LOG_FILE}")
DB_TYPE=sqlite
GPU_ENABLED=$(_shell_quote "${IOE_GPU_PRESENT}")
GPU_VENDOR=$(_shell_quote "${IOE_GPU_VENDOR}")
GPU_MODEL=$(_shell_quote "${IOE_GPU_MODEL}")
GPU_RUNTIME_READY=$(_shell_quote "${IOE_GPU_RUNTIME_READY}")
EOF
    chmod 644 "${IOE_INSTALL_ENV}" 2>/dev/null || true
}

# =============================================================================
# Step 10 — Panel Source Code
# =============================================================================
install_panel_code() {
    step "Panel source code (${PANEL_VERSION})"

    [[ "${PANEL_VERSION}" == "main" ]] && warn "PANEL_VERSION is 'main'. For production, use a release tag."

    if [[ -d "${PANEL_DIR}/.git" ]]; then
        info "Existing installation detected — updating source tree..."
        cd "${PANEL_DIR}"
        _retry 3 git fetch --all --tags -q
        _git_checkout_panel_version
    else
        _run_spin "Cloning repository" git clone -q "${PANEL_REPO}" "${PANEL_DIR}"
        cd "${PANEL_DIR}"
        _retry 3 git fetch --all --tags -q
        _git_checkout_panel_version
    fi

    [[ ! -f "${PANEL_DIR}/docker-compose.yml" ]] && [[ ! -f "${PANEL_DIR}/compose.yml" ]] \
        && fatal "docker-compose.yml or compose.yml not found in repo."

    success "Panel code ready (${PANEL_VERSION})"
}

_git_checkout_panel_version() {
    if git rev-parse --verify --quiet "origin/${PANEL_VERSION}^{commit}" >/dev/null; then
        git checkout -B "${PANEL_VERSION}" "origin/${PANEL_VERSION}" >>"${LOG_FILE}" 2>&1
        git reset --hard "origin/${PANEL_VERSION}" >>"${LOG_FILE}" 2>&1
        return
    fi

    if git rev-parse --verify --quiet "${PANEL_VERSION}^{commit}" >/dev/null; then
        git checkout --detach "${PANEL_VERSION}" >>"${LOG_FILE}" 2>&1
        return
    fi

    fatal "Version not found in repository: ${PANEL_VERSION}. Use a valid branch, tag, or commit."
}

# =============================================================================
# Step 11 — Environment Configuration
# =============================================================================
generate_env() {
    step "Environment configuration"
    local env_file="${PANEL_DIR}/.env"

    if [[ -f "${env_file}" ]]; then
        cp -a "${env_file}" "${env_file}.bak.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true
        local added=0
        _env_add_if_missing "APP_ENV"               "production"                  "${env_file}" && added=$((added+1)) || true
        _env_add_if_missing "DB_TYPE"               "sqlite"                      "${env_file}" && added=$((added+1)) || true
        _env_add_if_missing "DATA_DIR"              "${DATA_DIR}"                 "${env_file}" && added=$((added+1)) || true
        _env_add_if_missing "IOE_DATA_DIR"          "${IOE_DATA_DIR}"             "${env_file}" && added=$((added+1)) || true
        _env_add_if_missing "IOE_DATA_ROOT"       "${IOE_DATA_ROOT}"            "${env_file}" && added=$((added+1)) || true
        _env_add_if_missing "IOE_DATA_HOST_PATH"  "${IOE_DATA_ROOT}"            "${env_file}" && added=$((added+1)) || true
        _env_add_if_missing "BACKUP_DIR"           "${BACKUP_DIR}"               "${env_file}" && added=$((added+1)) || true
        _env_add_if_missing "MODEL_DIR"             "${MODEL_DIR}"                "${env_file}" && added=$((added+1)) || true
        _env_add_if_missing "IOE_RUNTIME_DIR"       "${IOE_RUNTIME_DIR}"          "${env_file}" && added=$((added+1)) || true
        _env_add_if_missing "IOE_PLUGIN_DIR"        "${IOE_PLUGIN_DIR}"           "${env_file}" && added=$((added+1)) || true
        _env_add_if_missing "IOE_HOOK_DIR"          "${IOE_HOOK_DIR}"             "${env_file}" && added=$((added+1)) || true
        _env_add_if_missing "IOE_STATE_DIR"         "${IOE_STATE_DIR}"            "${env_file}" && added=$((added+1)) || true
        _env_add_if_missing "IOE_CONF_DIR"          "${IOE_CONF_DIR}"             "${env_file}" && added=$((added+1)) || true
        _env_add_if_missing "PANEL_PORT"            "${PANEL_PORT}"               "${env_file}" && added=$((added+1)) || true
        _env_add_if_missing "GPU_ENABLED"           "${IOE_GPU_PRESENT}"          "${env_file}" && added=$((added+1)) || true
        _env_add_if_missing "GPU_VENDOR"            "${IOE_GPU_VENDOR}"           "${env_file}" && added=$((added+1)) || true
        _env_add_if_missing "GPU_MODEL"             "${IOE_GPU_MODEL}"            "${env_file}" && added=$((added+1)) || true
        _env_add_if_missing "GPU_RUNTIME_READY"     "${IOE_GPU_RUNTIME_READY}"    "${env_file}" && added=$((added+1)) || true
        [[ "${added}" -gt 0 ]] && info "Migrated ${added} new infrastructure key(s) into .env"

        local current_env_port
        current_env_port=$(grep '^PANEL_PORT=' "${env_file}" | tail -n1 | cut -d= -f2 || echo "")
        if [[ -n "${current_env_port}" ]] && [[ "${current_env_port}" != "${PANEL_PORT}" ]]; then
            warn ".env has PANEL_PORT=${current_env_port}, but runtime selected ${PANEL_PORT}. Updating .env."
            sed -i "s/^PANEL_PORT=.*/PANEL_PORT=${PANEL_PORT}/" "${env_file}"
        fi
        chmod 600 "${env_file}" 2>/dev/null || true
        success ".env preserved and synced"
        return
    fi

    local secret_key
    secret_key=$(openssl rand -hex 64)

    cat > "${env_file}" <<EOF
# IOE AI Env Installer — Environment v${INSTALLER_VERSION}
# Generated: $(date)
APP_ENV=production
SECRET_KEY=${secret_key}

# Database
DB_TYPE=sqlite

# Data directories
DATA_DIR=${DATA_DIR}
IOE_DATA_DIR=${IOE_DATA_DIR}
IOE_DATA_ROOT=${IOE_DATA_ROOT}
IOE_DATA_HOST_PATH=${IOE_DATA_ROOT}
BACKUP_DIR=${BACKUP_DIR}
MODEL_DIR=${MODEL_DIR}

# Runtime infrastructure
IOE_RUNTIME_DIR=${IOE_RUNTIME_DIR}
IOE_PLUGIN_DIR=${IOE_PLUGIN_DIR}
IOE_HOOK_DIR=${IOE_HOOK_DIR}
IOE_STATE_DIR=${IOE_STATE_DIR}
IOE_CONF_DIR=${IOE_CONF_DIR}

# Hardware detection
GPU_ENABLED=${IOE_GPU_PRESENT}
GPU_VENDOR=${IOE_GPU_VENDOR}
GPU_MODEL=${IOE_GPU_MODEL}
GPU_RUNTIME_READY=${IOE_GPU_RUNTIME_READY}

# Panel
PANEL_PORT=${PANEL_PORT}
EOF
    chown root:root "${env_file}" 2>/dev/null || true
    chmod 600 "${env_file}"
    success ".env generated (chmod 600)"
}

_env_add_if_missing() {
    local key="$1" val="$2" file="$3"
    grep -q "^${key}=" "${file}" 2>/dev/null && return 1
    echo "${key}=${val}" >> "${file}"
    _log "INFO  env migration: added ${key}=${val}"
    return 0
}

# =============================================================================
# Step 12 — Launch, Image Presence Check & Health Check
# =============================================================================
launch_and_integrate() {
    step "Launch, image presence & health check"
    _start_panel
    _image_presence_check
    _healthcheck
    _integrate_systemd
}

_start_panel() {
    cd "${PANEL_DIR}"

    docker compose config -q >>"${LOG_FILE}" 2>&1 \
        || fatal "docker compose configuration validation failed."

    local pull_ok=0
    local attempt
    for attempt in 1 2 3; do
        _spinner_start "Pulling images (attempt ${attempt}/3)"
        if docker compose pull -q >>"${LOG_FILE}" 2>&1; then
            _spinner_stop 0 "Images ready"
            pull_ok=1
            break
        else
            _spinner_stop 1
            [[ "${attempt}" -lt 3 ]] && { warn "  Pull failed — waiting 10s..."; sleep 10; }
        fi
    done
    [[ "${pull_ok}" -eq 0 ]] && fatal "Image pull failed after 3 attempts.\n  → Re-run: bash install-ioe.sh --mirror"

    _run_spin "Starting panel containers" docker compose up -d --remove-orphans
    success "Panel containers started"
}

_image_presence_check() {
    info "Verifying image presence..."
    local image_count
    image_count=$(docker compose images -q 2>/dev/null | wc -l)
    if [[ "${image_count}" -lt 1 ]]; then
        fatal "Image presence check failed: no images found. Pull might have been corrupted."
    fi
    success "Image presence verified (${image_count} images)"
}

_healthcheck() {
    info "Waiting for panel to become ready (up to ${HEALTHCHECK_TIMEOUT}s)..."
    local elapsed=0 body="" ok=0

    while [[ "${elapsed}" -lt "${HEALTHCHECK_TIMEOUT}" ]]; do
        body=$(curl -sf --connect-timeout 3 \
            "http://127.0.0.1:${PANEL_PORT}/api/health" 2>/dev/null || true)
        [[ -n "${body}" ]] && { ok=1; break; }
        printf "."
        sleep 3
        elapsed=$((elapsed+3))
    done
    echo ""

    if [[ "${ok}" -eq 0 ]]; then
        warn "Panel did not respond within ${HEALTHCHECK_TIMEOUT}s — it may still be initialising."
        warn "  → Check: ioectl logs"
        warn "  → Status: ioectl ps"
        return
    fi

    if command -v jq &>/dev/null && [[ -n "${body}" ]]; then
        local status
        status=$(echo "${body}" | jq -r '.status // "unknown"' 2>/dev/null || echo "unknown")
        case "${status}" in
            ok)       success "Health check passed (${elapsed}s)" ;;
            degraded) warn "Panel running but degraded — check: ioectl logs" ;;
            *)        warn "Panel responded; status=${status} — check manually." ;;
        esac
    else
        success "Panel is responding (${elapsed}s)"
    fi
}

_integrate_systemd() {
    if [[ "${HAS_SYSTEMD}" -ne 1 ]]; then
        warn "systemd not available — service auto-start registration skipped."
        warn "  → Start panel manually after reboot: ioectl start"
        return
    fi

    _install_panel_service
    _install_runtime_service_slot
}

_install_panel_service() {
    local docker_bin
    docker_bin=$(command -v docker)
    cat > /etc/systemd/system/ioe.service <<EOF
[Unit]
Description=IOE AI Env Installer
After=docker.service network-online.target
Requires=docker.service
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=${PANEL_DIR}
EnvironmentFile=-${PANEL_DIR}/.env
ExecStart=${docker_bin} compose up -d --remove-orphans
ExecStop=${docker_bin} compose down

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload >/dev/null 2>&1 || true
    systemctl enable ioe >/dev/null 2>&1 || true
    success "ioe.service registered (auto-start on boot)"
}

_install_runtime_service_slot() {
    cat > /etc/systemd/system/ioe-runtime.service <<EOF
[Unit]
Description=IOE Matrix Local Runtime Slot
Documentation=${PANEL_REPO}
After=ioe.service
Wants=ioe.service

[Service]
Type=oneshot
WorkingDirectory=${IOE_RUNTIME_DIR}
EnvironmentFile=-${IOE_CONF_DIR}/runtime.env
ExecStart=/bin/echo "Local runtime is not configured. Enable via the panel."
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload >/dev/null 2>&1 || true
    info "ioe-runtime.service unit installed (not enabled — activated by panel later)"
}

# =============================================================================
# Step 13 — ioectl CLI
# =============================================================================
install_ioectl_cli() {
    step "ioectl CLI"
    _install_ioectl
}

_install_ioectl() {
    cat > /usr/local/bin/ioectl <<'EOF'
#!/usr/bin/env bash
# IOE AI Env Installer CLI — generated by install-ioe.sh
set -euo pipefail

INSTALL_ENV="${IOE_INSTALL_ENV:-/etc/ioe/install.env}"
if [[ -f "${INSTALL_ENV}" ]]; then
    # shellcheck disable=SC1090
    source "${INSTALL_ENV}"
else
    echo "[✗] Missing install env: ${INSTALL_ENV}"
    echo "    Re-run the installer or restore /etc/ioe/install.env."
    exit 1
fi

_cd() {
    cd "${PANEL_DIR}" 2>/dev/null || { echo "[✗] Panel not found: ${PANEL_DIR}"; exit 1; }
}

_has_systemd() {
    command -v systemctl &>/dev/null && [[ -d /run/systemd/system ]]
}

_checkout_panel_version() {
    if git rev-parse --verify --quiet "origin/${PANEL_VERSION}^{commit}" >/dev/null; then
        git checkout -B "${PANEL_VERSION}" "origin/${PANEL_VERSION}" >/dev/null 2>&1
        git reset --hard "origin/${PANEL_VERSION}" -q
    elif git rev-parse --verify --quiet "${PANEL_VERSION}^{commit}" >/dev/null; then
        git checkout --detach "${PANEL_VERSION}" >/dev/null 2>&1
    else
        echo "[✗] Version not found: ${PANEL_VERSION}"
        exit 1
    fi
}

case "${1:-help}" in
    start)
        _cd
        echo "Starting panel..."
        docker compose up -d --remove-orphans
        echo "[✓] Done" ;;

    stop)
        _cd
        echo "Stopping panel..."
        docker compose down
        echo "[✓] Done" ;;

    restart)
        _cd
        docker compose down
        docker compose up -d --remove-orphans
        echo "[✓] Restarted" ;;

    logs)
        _cd
        docker compose logs -f --tail=100 "${2:-}" ;;

    ps|status)
        _cd
        docker compose ps ;;

    update)
        _cd
        echo "Updating panel to ${PANEL_VERSION}..."
        git fetch --all --tags -q
        _checkout_panel_version
        docker compose pull -q
        docker compose up -d --remove-orphans
        echo "[✓] Update complete" ;;

    doctor)
        echo "── IOE AI Env Installer diagnostics $(date '+%Y-%m-%d %H:%M:%S') ──"
        echo "Installer : ${INSTALLER_VERSION:-unknown}"
        echo "Panel ref : ${PANEL_VERSION:-unknown}"
        echo "Docker    : $(docker version --format '{{.Server.Version}}' 2>/dev/null || echo 'not running')"
        echo "Driver    : $(docker info --format '{{.Driver}}' 2>/dev/null || echo 'unknown')"
        echo "Compose   : $(docker compose version --short 2>/dev/null || echo 'unavailable')"
        echo "Node ID   : $(cat ${IOE_CONF_DIR}/node-id 2>/dev/null || echo 'not generated')"
        echo "Disk      : $(df -h / | awk 'NR==2{print $3"/"$2" (free: "$4")"}')"
        echo "Inodes    : $(df -i / | awk 'NR==2{print $5" used"}')"
        echo "Memory    : $(free -h | awk '/^Mem:/{print $3"/"$2}')"
        echo "Swap      : $(free -h | awk '/^Swap:/{print $3"/"$2}')"
        echo "GPU       : vendor=${GPU_VENDOR:-unknown} model=${GPU_MODEL:-} enabled=${GPU_ENABLED:-unknown} runtime_ready=${GPU_RUNTIME_READY:-unknown}"
        echo "Time sync : $(timedatectl status 2>/dev/null | grep -E 'synchronized|NTP' | xargs || echo 'unknown')"
        echo "Data root : ${IOE_DATA_ROOT}"
        echo "App data  : ${DATA_DIR}  [$(du -sh ${DATA_DIR}  2>/dev/null | cut -f1 || echo 'empty')]"
        echo "Backups   : ${BACKUP_DIR} [$(du -sh ${BACKUP_DIR} 2>/dev/null | cut -f1 || echo 'empty')]"
        echo "Models    : ${MODEL_DIR} [$(du -sh ${MODEL_DIR} 2>/dev/null | cut -f1 || echo 'empty')]"
        echo "Local runtime : ${IOE_RUNTIME_DIR}"
        echo "Plugins   : $(ls ${IOE_PLUGIN_DIR} 2>/dev/null | wc -l) present"
        echo "Hooks     : $(ls ${IOE_HOOK_DIR} 2>/dev/null | wc -l) present"
        echo "Firewall  : $(ufw status 2>/dev/null | head -n1 || firewall-cmd --state 2>/dev/null || echo 'unknown')"
        echo "Mirror    : $(grep -q 'registry-mirrors' /etc/docker/daemon.json 2>/dev/null && echo 'enabled' || echo 'not configured')"
        echo "────────────────────────────────────────────"
        _cd
        docker compose ps ;;

    security)
        echo "── IOE AI Env Installer — security checklist ──"
        echo "This installer does not modify SSH by default to avoid user lockout."
        echo ""
        echo "SSH listening:"
        ss -tulpn 2>/dev/null | grep -E '(:22\s|:22,|:22$)' || echo "  SSH listener not detected on 22, or ss unavailable."
        echo ""
        echo "sshd_config snapshot:"
        grep -Ei '^(Port|PermitRootLogin|PasswordAuthentication|PubkeyAuthentication)' /etc/ssh/sshd_config 2>/dev/null || true
        echo ""
        echo "Firewall snapshot:"
        ufw status verbose 2>/dev/null || firewall-cmd --list-all 2>/dev/null || echo "  firewall status unavailable"
        echo ""
        echo "Recommended next steps after confirming you have working access:"
        echo "  1. Add SSH key login and verify it works."
        echo "  2. Disable SSH password login if you understand the risk."
        echo "  3. Keep 22 open or change SSH port only after opening the new port in firewall and cloud security group."
        echo "  4. Enable HTTPS for the panel."
        echo "  5. Configure remote backup before production use."
        echo "  6. Restrict panel access by IP only if you have a stable fixed IP."
        echo ""
        echo "Do not close SSH from this tool unless you have console/VNC rescue access." ;;

    runtime)
        echo "── Local Runtime ──"
        echo "Manifest  : $(cat ${IOE_RUNTIME_DIR}/runtime.json 2>/dev/null || echo 'not found')"
        echo "Config    : ${IOE_CONF_DIR}/runtime.toml"
        echo "Node ID   : $(cat ${IOE_CONF_DIR}/node-id 2>/dev/null || echo 'not generated')"
        echo "Plugins   : $(ls ${IOE_PLUGIN_DIR} 2>/dev/null || true)"
        echo "Hooks     : $(ls ${IOE_HOOK_DIR} 2>/dev/null || true)"
        _has_systemd && systemctl status ioe-runtime.service 2>/dev/null || echo "(systemd not available)" ;;

    clean)
        echo "── Docker Disk Usage ────────────────────────"
        docker system df
        echo ""
        echo "To free images older than 30 days:"
        echo "  docker system prune -f --filter 'until=720h'"
        echo ""
        echo "To remove ALL unused images (destructive):"
        echo "  docker system prune -af"
        echo ""
        echo "WARNING: Review 'docker system df' before pruning."
        echo "These commands may affect images used by other projects." ;;

    node-id)
        cat "${IOE_CONF_DIR}/node-id" 2>/dev/null || echo "Node ID not found." ;;

    reinstall)
        yes_mode=0
        [[ "${2:-}" == "--yes" || "${2:-}" == "-y" ]] && yes_mode=1
        echo "[!] Reinstall preserves: ${IOE_DATA_ROOT} (${DATA_DIR}, ${BACKUP_DIR}, ${MODEL_DIR}, ${IOE_RUNTIME_DIR}, ${IOE_STATE_DIR})"
        echo "[!] Current ref: ${PANEL_VERSION}"
        if [[ "${yes_mode}" -ne 1 ]]; then
            read -r -p "Confirm reinstall? [y/N]: " c
            [[ "${c,,}" == "y" ]] || { echo "Cancelled."; exit 0; }
        fi
        echo "[!] Starting reinstall..."
        curl -fsSL "https://raw.githubusercontent.com/yatenetworks/ioe/${PANEL_VERSION}/install-ioe.sh" | PANEL_VERSION="${PANEL_VERSION}" bash ;;

    report)
        echo "> Review this report before sharing. Remove domains, IPs, tokens, or private paths if needed."
        echo ""
        echo "### IOE AI Env Installer — diagnostic report"
        echo ""
        echo "| Field | Value |"
        echo "|-------|-------|"
        echo "| Installer | ${INSTALLER_VERSION:-unknown} |"
        echo "| Panel Ref | ${PANEL_VERSION:-unknown} |"
        echo "| Docker    | $(docker version --format '{{.Server.Version}}' 2>/dev/null || echo 'not running') |"
        echo "| Driver    | $(docker info --format '{{.Driver}}' 2>/dev/null || echo 'unknown') |"
        echo "| Compose   | $(docker compose version --short 2>/dev/null || echo 'unavailable') |"
        echo "| Node ID   | $(cat ${IOE_CONF_DIR}/node-id 2>/dev/null || echo 'not generated') |"
        echo "| Disk Used/Avail | $(df -h / | awk 'NR==2{print $3"/"$2" (free: "$4")"}') |"
        echo "| Inodes    | $(df -i / | awk 'NR==2{print $5" used"}') |"
        echo "| Memory    | $(free -h | awk '/^Mem:/{print $3"/"$2}') |"
        echo "| Swap      | $(free -h | awk '/^Swap:/{print $3"/"$2}') |"
        echo "| GPU       | vendor=${GPU_VENDOR:-unknown} model=${GPU_MODEL:-} enabled=${GPU_ENABLED:-unknown} runtime_ready=${GPU_RUNTIME_READY:-unknown} |"
        echo "| Time sync | $(timedatectl status 2>/dev/null | grep -E 'synchronized|NTP' | xargs || echo 'unknown') |"
        echo "| Firewall  | $(ufw status 2>/dev/null | head -n1 || firewall-cmd --state 2>/dev/null || echo 'unknown') |"
        echo "| Mirror    | $(grep -q 'registry-mirrors' /etc/docker/daemon.json 2>/dev/null && echo 'enabled' || echo 'not configured') |"
        echo "| Data root | ${IOE_DATA_ROOT} |"
        echo "| App data  | ${DATA_DIR} ($(du -sh ${DATA_DIR} 2>/dev/null | cut -f1 || echo 'empty')) |"
        echo "| Backups   | ${BACKUP_DIR} ($(du -sh ${BACKUP_DIR} 2>/dev/null | cut -f1 || echo 'empty')) |"
        echo "| Models    | ${MODEL_DIR} ($(du -sh ${MODEL_DIR} 2>/dev/null | cut -f1 || echo 'empty')) |"
        echo ""
        echo "#### Container Status"
        echo '```'
        _cd
        docker compose ps 2>/dev/null || echo "No containers running"
        echo '```'
        echo ""
        echo "Generated at $(date '+%Y-%m-%d %H:%M:%S %Z')" ;;

    help|*)
        echo ""
        echo "  IOE AI Env Installer — ioectl v${INSTALLER_VERSION:-unknown}"
        echo ""
        echo "  Panel:"
        echo "    ioectl start           — start panel containers"
        echo "    ioectl stop            — stop panel containers"
        echo "    ioectl restart         — restart panel containers"
        echo "    ioectl logs            — live log stream  (Ctrl+C to exit)"
        echo "    ioectl ps              — container status"
        echo "    ioectl update          — update panel to recorded branch/tag"
        echo ""
        echo "  Diagnostics:"
        echo "    ioectl doctor          — full system diagnostics"
        echo "    ioectl report          — Markdown diagnostic report for support"
        echo "    ioectl security        — SSH/firewall hardening checklist"
        echo "    ioectl runtime         — local runtime status"
        echo "    ioectl clean           — disk usage + prune instructions"
        echo "    ioectl node-id         — show this node's identity"
        echo ""
        echo "  Maintenance:"
        echo "    ioectl reinstall       — reinstall using recorded PANEL_VERSION, data preserved"
        echo "    ioectl reinstall --yes — silent reinstall for automation"
        echo "" ;;
esac
EOF
    chmod +x /usr/local/bin/ioectl
    success "ioectl CLI installed"
}

# =============================================================================
# Infrastructure Record & Final Output
# =============================================================================
save_credentials() {
    local node_id
    node_id=$(cat "${IOE_CONF_DIR}/node-id" 2>/dev/null || echo "see ${IOE_CONF_DIR}/node-id")
    cat > "${CRED_FILE}" <<EOF
═══════════════════════════════════════════════════════════
  IOE AI Env Installer — Infrastructure Record  v${INSTALLER_VERSION}
  $(date)
═══════════════════════════════════════════════════════════
Profile      : ${INSTALLER_PROFILE}
Panel ref    : ${PANEL_VERSION}
Node ID      : ${node_id}
Panel port   : ${PANEL_PORT}
Hint URL     : http://${PUBLIC_IP}:${PANEL_PORT}
               (URL may differ with reverse proxy / ingress / domain)

Database     : sqlite
GPU          : enabled=${IOE_GPU_PRESENT}, vendor=${IOE_GPU_VENDOR}, model=${IOE_GPU_MODEL}, docker_runtime=${IOE_GPU_RUNTIME_READY}
Data root    : ${IOE_DATA_ROOT}
App data     : ${DATA_DIR}
Backups      : ${BACKUP_DIR}
Models       : ${MODEL_DIR}
Local runtime : ${IOE_RUNTIME_DIR}
  Plugins    : ${IOE_PLUGIN_DIR}
  Hooks      : ${IOE_HOOK_DIR}
  Manifest   : ${IOE_RUNTIME_DIR}/runtime.json
Config       : ${IOE_CONF_DIR}/runtime.toml
Install env  : ${IOE_INSTALL_ENV}
State        : ${IOE_STATE_DIR}

CLI          : ioectl [start|stop|update|logs|doctor|report|security|runtime|clean|node-id]
Install log  : ${LOG_FILE}
═══════════════════════════════════════════════════════════
Admin setup: Complete at first panel visit.
Security   : SSH was intentionally not modified. Run: ioectl security
═══════════════════════════════════════════════════════════
EOF
    chown root:root "${CRED_FILE}" 2>/dev/null || true
    chmod 600 "${CRED_FILE}" 2>/dev/null || true
}

show_result() {
    local node_id
    node_id=$(cat "${IOE_CONF_DIR}/node-id" 2>/dev/null | head -c 36 || echo "unavailable")

    echo ""
    echo -e "${GREEN}${BOLD}"
    echo "  ╔═══════════════════════════════════════════════════════════╗"
    echo "  ║      ✅  IOE AI ENV READY                                  ║"
    echo "  ╠═══════════════════════════════════════════════════════════╣"
    printf "  ║  %-57s  ║\n" ""
    printf "  ║  Profile : %-45s  ║\n" "${INSTALLER_PROFILE}"
    printf "  ║  Version : %-45s  ║\n" "${PANEL_VERSION}"
    printf "  ║  Node ID : %-45s  ║\n" "${node_id}"
    printf "  ║  DB      : %-45s  ║\n" "sqlite"
    printf "  ║  GPU     : %-45s  ║\n" "${IOE_GPU_VENDOR}/${IOE_GPU_PRESENT}"
    printf "  ║  Runtime : %-45s  ║\n" "${IOE_RUNTIME_DIR}"
    printf "  ║  Config  : %-45s  ║\n" "${IOE_CONF_DIR}/runtime.toml"
    printf "  ║  %-57s  ║\n" ""
    echo "  ╠═══════════════════════════════════════════════════════════╣"
    printf "  ║  %-57s  ║\n" "Panel access — complete admin setup at first visit:"
    printf "  ║    Local  → http://%-38s  ║\n" "${LOCAL_IP}:${PANEL_PORT}"
    printf "  ║    Public → http://%-38s  ║\n" "${PUBLIC_IP}:${PANEL_PORT}"
    printf "  ║  %-57s  ║\n" ""
    echo "  ╠═══════════════════════════════════════════════════════════╣"
    printf "  ║  %-57s  ║\n" "Commands:"
    printf "  ║    %-55s  ║\n" "ioectl logs       — live log stream"
    printf "  ║    %-55s  ║\n" "ioectl doctor     — system diagnostics"
    printf "  ║    %-55s  ║\n" "ioectl report     — markdown support report"
    printf "  ║    %-55s  ║\n" "ioectl security   — security checklist"
    printf "  ║    %-55s  ║\n" "ioectl runtime    — local runtime status"
    printf "  ║    %-55s  ║\n" "ioectl update     — update panel"
    printf "  ║  %-57s  ║\n" ""
    printf "  ║  Record: %-48s  ║\n" "${CRED_FILE}"
    echo "  ╚═══════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"

    echo -e "${YELLOW}  ⚠ This installer intentionally keeps SSH reachable by default to reduce lockout risk.${RESET}"
    echo -e "${YELLOW}  ⚠ This installer does not require special networking (VPN, fixed IP, or third-party services).${RESET}"
    echo -e "${YELLOW}  ⚠ Before production use: enable HTTPS, configure remote backup, and review ioectl security.${RESET}"
    echo ""
}

# =============================================================================
# Main
# =============================================================================
main() {
    banner

    # Self-update check only when tracking 'main' to avoid disrupting pinned versions
    if [[ "${PANEL_VERSION}" == "main" ]]; then
        _check_self_update
    fi

    preflight_lock_and_root            # Step  1
    detect_system                      # Step  2
    preflight_network                  # Step  3
    preflight_hardware                 # Step  4
    _force_swap_fix                    # Step  4b — Adaptive swap (container workloads)
    install_base_packages              # Step  5
    configure_security                 # Step  6
    install_docker                     # Step  7
    _auto_gpu_probe                    # GPU detection
    configure_docker_and_timesync      # Step  8
    prepare_runtime_infrastructure     # Step  9
    install_panel_code                 # Step 10
    generate_env                       # Step 11
    launch_and_integrate               # Step 12 (includes image presence & health)
    install_ioectl_cli                 # Step 13

    INSTALL_SUCCESS=1
    _progress_bar 100
    _write_install_env
    save_credentials
    show_result
}

main "$@"