#!/usr/bin/env bash
# =============================================================================
# IOE AI Env Installer
# Canonical public installer entrypoint
#
# Current public status:
#   documentation + template standard preview
#
# This script is intentionally inactive until the public preview installer has
# passed clean VPS testing. It does not install packages, download code, start
# containers, change firewall rules, create users, or modify the host system.
#
# The long-term purpose of this file is to become the tested installer for the
# IOE local preview package. For now, it protects users from assuming that the
# installer is ready before it has been verified.
# =============================================================================
set -Eeuo pipefail

show_help() {
  cat <<'NOTICE'
IOE AI Env Installer

Current status:
  The public installer is not active yet.

What IOE is standardizing:
  AI application environment template lifecycle:

    ioectl validate module <module.yaml>
    ioectl module install <module.yaml>
    ioectl module start <module_id>
    ioectl module status <module_id>
    ioectl module logs <module_id>
    ioectl module stop <module_id>
    ioectl module remove <module_id>

Automation-friendly direction:
    ioectl validate module <module.yaml> --json
    ioectl module status <module_id> --json
    ioectl module logs <module_id> --tail 100

Why this installer does not run yet:
  IOE is currently publishing the public documentation, template standard,
  and lifecycle direction first. The active preview installer should only be
  enabled after the local preview package passes clean VPS testing.

What this script does today:
  - prints this notice
  - makes no system changes
  - exits without installing anything

What this script does NOT do today:
  - does not install packages
  - does not download code
  - does not start containers
  - does not change firewall rules
  - does not create users
  - does not modify the host system

Read first:
  - README.md
  - docs/WHY_IOE.md
  - docs/MODULE_TEMPLATE_STANDARD.md
  - docs/STABILITY_AND_EXTENSION_POLICY.md
  - docs/AUTOMATION_FRIENDLY_CLI_STANDARD.md
  - docs/ADAPTER_INTERFACE_DRAFT.md
  - docs/TEMPLATE_VALIDATION.md
  - docs/APP_TEMPLATE_POLICY.md

Future direction:
  After clean VPS testing passes, this file may become the preview installer
  for the IOE local runnable preview package.
NOTICE
}

show_status_json() {
  cat <<'JSON'
{
  "installer": "install-ioe.sh",
  "active": false,
  "status": "inactive",
  "reason": "public preview installer has not been enabled yet",
  "makes_system_changes": false,
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

case "${1:-}" in
  -h|--help|help)
    show_help
    exit 0
    ;;
  --status|status)
    if [[ "${2:-}" == "--json" ]]; then
      show_status_json
    else
      echo "inactive: public preview installer has not been enabled yet"
    fi
    exit 2
    ;;
  --json)
    show_status_json
    exit 2
    ;;
  "")
    show_help
    exit 2
    ;;
  *)
    echo "Unknown option: $1" >&2
    echo "Run: bash install-ioe.sh --help" >&2
    exit 2
    ;;
esac
