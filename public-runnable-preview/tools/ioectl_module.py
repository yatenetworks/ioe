#!/usr/bin/env python3
"""IOE Runtime v2 local module lifecycle MVP."""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from ioectl_validate import load_yaml, validate_file

MODULE_ID_PATTERN = re.compile(r"^[a-z0-9][a-z0-9._-]{2,127}$")
INSTALL_FILES = (
    "module.yaml",
    "docker-compose.yaml",
    "healthcheck.sh",
    "backup.sh",
    "restore.sh",
)
TRACEBACK_MARKERS = ("Traceback (most recent call last):", "  File ", "    ")


def data_root() -> Path:
    env_dir = os.environ.get("IOE_DATA_DIR", "").strip()
    if env_dir:
        return Path(env_dir)
    return Path.home() / "ioe-data"


def app_dir(module_id: str) -> Path:
    return data_root() / "apps" / module_id


def instance_path(module_id: str) -> Path:
    return app_dir(module_id) / "instance.json"


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def resolve_path(path: str) -> Path:
    target = Path(path)
    if not target.is_absolute():
        target = (Path.cwd() / target).resolve()
    return target


def load_instance(module_id: str) -> dict[str, Any]:
    path = instance_path(module_id)
    if not path.is_file():
        raise FileNotFoundError(f"module not installed: {module_id}")
    with path.open("r", encoding="utf-8") as handle:
        data = json.load(handle)
    if not isinstance(data, dict):
        raise ValueError(f"invalid instance.json for {module_id}")
    return data


def save_instance(module_id: str, instance: dict[str, Any]) -> None:
    path = instance_path(module_id)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as handle:
        json.dump(instance, handle, indent=2)
        handle.write("\n")


def check_security_policy(manifest: dict[str, Any]) -> str | None:
    policy = manifest.get("security_policy")
    if not isinstance(policy, dict):
        return "missing security_policy"
    if policy.get("needs_root") is True:
        return "module requests root access (needs_root=true)"
    if policy.get("needs_docker_socket") is True:
        return "module requests docker socket access (needs_docker_socket=true)"
    return None


def validate_module_id(module_id: str) -> str | None:
    if not MODULE_ID_PATTERN.match(module_id):
        return (
            "module_id must match ^[a-z0-9][a-z0-9._-]{2,127}$ "
            f"(got: {module_id!r})"
        )
    return None


def find_compose_cmd() -> list[str] | None:
    for cmd in (["docker", "compose"], ["docker-compose"]):
        try:
            result = subprocess.run(
                [*cmd, "version"],
                capture_output=True,
                text=True,
                check=False,
            )
        except OSError:
            continue
        if result.returncode == 0:
            return cmd
    return None


def compose_command(module_id: str, *args: str) -> tuple[list[str] | None, Path | None, str | None]:
    compose_cmd = find_compose_cmd()
    if compose_cmd is None:
        return (
            None,
            None,
            "ERROR: docker compose is not available (tried 'docker compose' and 'docker-compose')",
        )

    module_path = app_dir(module_id)
    if not module_path.is_dir():
        return None, None, f"ERROR: module not installed: {module_id}"

    compose_file = module_path / "docker-compose.yaml"
    if not compose_file.is_file():
        return None, None, f"ERROR: docker-compose.yaml not found for {module_id}"

    return [*compose_cmd, "-f", str(compose_file), *args], module_path, None


def run_compose(module_id: str, *args: str) -> tuple[int, str]:
    cmd, module_path, err = compose_command(module_id, *args)
    if err is not None:
        return 1, err
    assert cmd is not None and module_path is not None

    try:
        result = subprocess.run(
            cmd,
            cwd=module_path,
            capture_output=True,
            text=True,
            check=False,
        )
    except OSError as exc:
        return 1, f"ERROR: failed to run {' '.join(cmd)}: {exc}"

    if result.returncode != 0:
        detail = (result.stderr or result.stdout or "").strip()
        message = f"ERROR: {' '.join(cmd)} failed (exit {result.returncode})"
        if detail:
            message = f"{message}\n{detail}"
        return result.returncode, message

    return 0, result.stdout or ""


def run_compose_attached(module_id: str, *args: str) -> tuple[int, str]:
    cmd, module_path, err = compose_command(module_id, *args)
    if err is not None:
        return 1, err
    assert cmd is not None and module_path is not None

    try:
        result = subprocess.run(
            cmd,
            cwd=module_path,
            check=False,
        )
    except OSError as exc:
        return 1, f"ERROR: failed to run {' '.join(cmd)}: {exc}"

    if result.returncode != 0:
        return result.returncode, f"ERROR: {' '.join(cmd)} failed (exit {result.returncode})"

    return 0, ""


def compose_has_running_services(module_id: str) -> tuple[bool, str | None]:
    rc, output = run_compose(module_id, "ps", "-q", "--status", "running")
    if rc != 0:
        return False, output
    return bool(output.strip()), None


def sanitize_healthcheck_detail(text: str) -> str:
    lines: list[str] = []
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped:
            continue
        if stripped.startswith(TRACEBACK_MARKERS) or stripped.startswith("Traceback"):
            continue
        if stripped.startswith("File ") or stripped.startswith('File "'):
            continue
        if stripped.startswith("urllib.error.") or stripped.startswith("http.client."):
            lines.append(stripped)
            continue
        if "Error" in stripped or "error" in stripped.lower():
            lines.append(stripped)
    if lines:
        return lines[-1]
    return ""


def cmd_install(manifest_path: Path) -> int:
    if not manifest_path.is_file():
        print(f"ERROR: file not found: {manifest_path}", file=sys.stderr)
        return 1

    rc = validate_file("module", manifest_path)
    if rc != 0:
        return rc

    try:
        manifest = load_yaml(manifest_path)
    except ValueError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    module_id = manifest.get("module_id")
    if not isinstance(module_id, str):
        print("ERROR: module_id missing or invalid", file=sys.stderr)
        return 1

    id_error = validate_module_id(module_id)
    if id_error:
        print(f"ERROR: {id_error}", file=sys.stderr)
        return 1

    security_error = check_security_policy(manifest)
    if security_error:
        print(f"ERROR: {security_error}", file=sys.stderr)
        return 1

    target_dir = app_dir(module_id)
    inst_path = instance_path(module_id)
    if inst_path.is_file():
        try:
            existing = load_instance(module_id)
        except ValueError:
            existing = {}
        if existing.get("state") != "removed":
            print(f"ERROR: module already installed: {module_id}", file=sys.stderr)
            return 1

    source_dir = manifest_path.parent
    target_dir.mkdir(parents=True, exist_ok=True)

    for name in INSTALL_FILES:
        src = manifest_path if name == "module.yaml" else source_dir / name
        if not src.is_file():
            print(f"ERROR: required file missing: {src}", file=sys.stderr)
            return 1
        shutil.copy2(src, target_dir / name)

    instance = {
        "module_id": module_id,
        "state": "installed",
        "installed_at": utc_now_iso(),
        "module_dir": str(target_dir),
        "compose_file": str(target_dir / "docker-compose.yaml"),
        "source_manifest": str(manifest_path.resolve()),
    }
    save_instance(module_id, instance)

    print(f"OK: module installed: {module_id}")
    return 0


def cmd_start(module_id: str) -> int:
    id_error = validate_module_id(module_id)
    if id_error:
        print(f"ERROR: {id_error}", file=sys.stderr)
        return 1

    try:
        instance = load_instance(module_id)
    except (FileNotFoundError, ValueError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    rc, message = run_compose(module_id, "up", "-d")
    if rc != 0:
        print(message, file=sys.stderr)
        return 1

    instance["state"] = "running"
    instance["started_at"] = utc_now_iso()
    save_instance(module_id, instance)

    print(f"OK: module started: {module_id}")
    return 0


def cmd_status(module_id: str) -> int:
    id_error = validate_module_id(module_id)
    if id_error:
        print(f"ERROR: {id_error}", file=sys.stderr)
        return 1

    try:
        instance = load_instance(module_id)
    except (FileNotFoundError, ValueError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    state = instance.get("state", "unknown")
    if state == "removed":
        print(f"OK: module removed: {module_id}")
        return 0
    if state == "stopped":
        print(f"OK: module stopped: {module_id}")
        return 0
    if state == "installed":
        print(f"OK: module not_running: {module_id}")
        return 0

    running, compose_err = compose_has_running_services(module_id)
    if compose_err:
        print(compose_err, file=sys.stderr)
        return 1
    if not running:
        if state == "running":
            instance["state"] = "stopped"
            instance["stopped_at"] = utc_now_iso()
            save_instance(module_id, instance)
        print(f"OK: module not_running: {module_id}")
        return 0

    module_path = app_dir(module_id)
    healthcheck = module_path / "healthcheck.sh"
    if not healthcheck.is_file():
        print(f"ERROR: healthcheck.sh not found for {module_id}", file=sys.stderr)
        return 1

    try:
        result = subprocess.run(
            [str(healthcheck)],
            cwd=module_path,
            capture_output=True,
            text=True,
            check=False,
        )
    except OSError as exc:
        print(f"ERROR: failed to run healthcheck: {exc}", file=sys.stderr)
        return 1

    if result.returncode != 0:
        detail = sanitize_healthcheck_detail(
            (result.stderr or "") + "\n" + (result.stdout or "")
        )
        print(f"ERROR: module unhealthy: {module_id}", file=sys.stderr)
        if detail:
            print(detail, file=sys.stderr)
        return 1

    print(f"OK: module healthy: {module_id}")
    return 0


def cmd_logs(module_id: str, tail: int | None) -> int:
    id_error = validate_module_id(module_id)
    if id_error:
        print(f"ERROR: {id_error}", file=sys.stderr)
        return 1

    try:
        load_instance(module_id)
    except (FileNotFoundError, ValueError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    args: list[str] = ["logs"]
    if tail is not None:
        args.extend(["--tail", str(tail)])

    rc, message = run_compose_attached(module_id, *args)
    if rc != 0:
        print(message, file=sys.stderr)
        return 1
    return 0


def cmd_stop(module_id: str) -> int:
    id_error = validate_module_id(module_id)
    if id_error:
        print(f"ERROR: {id_error}", file=sys.stderr)
        return 1

    try:
        instance = load_instance(module_id)
    except (FileNotFoundError, ValueError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    rc, message = run_compose(module_id, "down")
    if rc != 0:
        print(message, file=sys.stderr)
        return 1

    instance["state"] = "stopped"
    instance["stopped_at"] = utc_now_iso()
    save_instance(module_id, instance)

    print(f"OK: module stopped: {module_id}")
    return 0


def cmd_remove(module_id: str) -> int:
    id_error = validate_module_id(module_id)
    if id_error:
        print(f"ERROR: {id_error}", file=sys.stderr)
        return 1

    try:
        instance = load_instance(module_id)
    except (FileNotFoundError, ValueError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    if instance.get("state") == "running":
        stop_rc = cmd_stop(module_id)
        if stop_rc != 0:
            return stop_rc
        instance = load_instance(module_id)

    instance["state"] = "removed"
    instance["removed_at"] = utc_now_iso()
    save_instance(module_id, instance)

    print(f"OK: module removed from active runtime: {module_id}")
    return 0


def print_help() -> None:
    print(
        "Usage:\n"
        "  ./ioectl module install <module.yaml>\n"
        "  ./ioectl module start <module_id>\n"
        "  ./ioectl module status <module_id>\n"
        "  ./ioectl module logs <module_id> [--tail N]\n"
        "  ./ioectl module stop <module_id>\n"
        "  ./ioectl module remove <module_id>"
    )


def parse_logs_tail(extra: list[str]) -> tuple[int | None, str | None]:
    tail: int | None = None
    index = 0
    while index < len(extra):
        token = extra[index]
        if token == "--tail":
            if index + 1 >= len(extra):
                return None, "ERROR: --tail requires a value"
            try:
                tail = int(extra[index + 1])
            except ValueError:
                return None, f"ERROR: invalid --tail value: {extra[index + 1]!r}"
            if tail < 0:
                return None, "ERROR: --tail must be a non-negative integer"
            index += 2
            continue
        return None, f"ERROR: unknown option: {token}"
    return tail, None


def main(argv: list[str]) -> int:
    if not argv or argv[0] in {"--help", "-h", "help"}:
        print_help()
        return 0 if argv and argv[0] in {"--help", "-h", "help"} else 2

    action = argv[0]

    if action == "install":
        if len(argv) != 2:
            print_help()
            return 2
        return cmd_install(resolve_path(argv[1]))

    if action == "logs":
        if len(argv) < 2:
            print_help()
            return 2
        tail, err = parse_logs_tail(argv[2:])
        if err:
            print(err, file=sys.stderr)
            return 2
        return cmd_logs(argv[1], tail)

    if len(argv) != 2:
        print_help()
        return 2

    module_id = argv[1]
    if action == "start":
        return cmd_start(module_id)
    if action == "status":
        return cmd_status(module_id)
    if action == "stop":
        return cmd_stop(module_id)
    if action == "remove":
        return cmd_remove(module_id)

    print(f"ERROR: unknown module action: {action}", file=sys.stderr)
    print_help()
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
