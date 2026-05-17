#!/usr/bin/env bash
# Compatibility wrapper.
# install-ioe.sh is the canonical installer entrypoint.
set -Eeuo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "${DIR}/install-ioe.sh" "$@"
