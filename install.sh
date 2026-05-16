#!/usr/bin/env bash
# Compatibility entry — delegates to install-ioe.sh (IOE AI Env Installer).
set -Eeuo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "${DIR}/install-ioe.sh" "$@"
