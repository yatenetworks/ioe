#!/usr/bin/env python3
"""IOE Runtime v2 ioectl unified entry."""

from __future__ import annotations

import sys

from ioectl_module import main as module_main
from ioectl_validate import main as validate_main

HELP_FLAGS = frozenset({"--help", "-h", "help"})


def print_help() -> None:
    print(
        "Usage:\n"
        "  ./ioectl validate <kind> <file>\n"
        "  ./ioectl module install <module.yaml>\n"
        "  ./ioectl module start <module_id>\n"
        "  ./ioectl module status <module_id>\n"
        "  ./ioectl module logs <module_id> [--tail N]\n"
        "  ./ioectl module stop <module_id>\n"
        "  ./ioectl module remove <module_id>"
    )


def wants_help(argv: list[str]) -> bool:
    return bool(argv) and argv[0] in HELP_FLAGS


def main(argv: list[str]) -> int:
    if wants_help(argv):
        print_help()
        return 0

    if not argv:
        print_help()
        return 2

    command = argv[0]
    rest = argv[1:]

    if command == "validate":
        return validate_main(rest)

    if command == "module":
        return module_main(rest)

    print(f"ERROR: unknown command: {command}", file=sys.stderr)
    print_help()
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
