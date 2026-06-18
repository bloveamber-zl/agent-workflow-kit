from __future__ import annotations

import json
import subprocess
from pathlib import Path

from runtime.models import ProjectContext


def detect_stack(target_path: Path) -> str:
    if (target_path / "pubspec.yaml").is_file():
        return "flutter"
    if (target_path / "package.json").is_file():
        return "node"
    if any((target_path / name).is_file() for name in ("pyproject.toml", "requirements.txt", "setup.py")):
        return "python"
    return "generic"


def has_installed_workflow(target_path: Path) -> bool:
    return all((target_path / path).is_file() for path in ("AGENTS.md", "init.sh", "docs/index.md"))


def read_workflow_version(target_path: Path) -> str:
    config_path = target_path / ".agent/config.json"
    if not config_path.is_file():
        return ""
    try:
        with config_path.open(encoding="utf-8") as f:
            data = json.load(f)
    except (OSError, json.JSONDecodeError):
        return ""
    return str(data.get("workflow_version", ""))


def is_dirty_git(target_path: Path) -> bool:
    if not (target_path / ".git").exists():
        return False
    result = subprocess.run(
        ["git", "status", "--short"],
        cwd=target_path,
        text=True,
        capture_output=True,
        check=False,
    )
    return bool(result.stdout.strip())


def build_context(target_path: str | Path) -> ProjectContext:
    root = Path(target_path).resolve()
    stack = detect_stack(root)
    installed = has_installed_workflow(root)
    version = read_workflow_version(root)
    recommended_action = "upgrade_workflow" if installed else "generate_workflow"
    return ProjectContext(
        target_path=root,
        detected_stack=stack,
        has_workflow=installed,
        workflow_version=version,
        dirty_git=is_dirty_git(root),
        recommended_action=recommended_action,
    )
