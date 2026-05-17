#!/usr/bin/env python3
"""IOE local runnable preview — module manifest validation only."""

from __future__ import annotations

import sys
from pathlib import Path
from typing import Any

import yaml
from jsonschema import Draft202012Validator
from jsonschema.exceptions import SchemaError, ValidationError

MODULE_SCHEMA = "schemas/module.manifest.schema.yaml"


def repo_root() -> Path:
    return Path(__file__).resolve().parent.parent


def load_yaml(path: Path) -> Any:
    try:
        with path.open("r", encoding="utf-8") as handle:
            data = yaml.safe_load(handle)
    except yaml.YAMLError as exc:
        raise ValueError(f"YAML parse error: {exc}") from exc
    if data is None:
        raise ValueError("empty YAML document")
    if not isinstance(data, dict):
        raise ValueError("YAML root must be a mapping")
    return data


def format_error_path(error: ValidationError) -> str:
    if not error.path:
        return "(root)"
    return ".".join(str(part) for part in error.path)


def print_help() -> None:
    print(
        "Usage: ioectl validate module <file>\n\n"
        "This public preview only supports module validation.\n\n"
        "Example:\n"
        "  ./ioectl validate module templates/modules/hello.basic/module.yaml"
    )


def validate_file(kind: str, target: Path) -> int:
    if kind != "module":
        print(
            "ERROR: this public preview only supports module validation",
            file=sys.stderr,
        )
        print_help()
        return 2

    root = repo_root()
    schema_path = root / MODULE_SCHEMA
    if not schema_path.is_file():
        print(f"ERROR: schema not found: {schema_path}", file=sys.stderr)
        return 1

    if not target.is_file():
        print(f"ERROR: file not found: {target}", file=sys.stderr)
        return 1

    try:
        schema = load_yaml(schema_path)
        instance = load_yaml(target)
    except ValueError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    try:
        Draft202012Validator.check_schema(schema)
        validator = Draft202012Validator(schema)
    except SchemaError as exc:
        print(f"ERROR: invalid schema {schema_path}: {exc.message}", file=sys.stderr)
        return 1

    errors = sorted(validator.iter_errors(instance), key=lambda e: list(e.path))
    if errors:
        print(f"ERROR: validation failed for module: {target}", file=sys.stderr)
        for error in errors:
            print(f"- path: {format_error_path(error)}", file=sys.stderr)
            print(f"  message: {error.message}", file=sys.stderr)
        return 1

    print(f"OK: module valid: {target}")
    return 0


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print_help()
        return 2

    kind = argv[0]
    target = Path(argv[1])
    if not target.is_absolute():
        target = (Path.cwd() / target).resolve()

    return validate_file(kind, target)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
