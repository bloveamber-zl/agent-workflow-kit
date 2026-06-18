from __future__ import annotations

import subprocess
from pathlib import Path

from runtime.models import CommandResult


ROOT = Path(__file__).resolve().parents[1]


def validate_target(target_path: str | Path) -> CommandResult:
    command = [str(ROOT / "scripts/validate_target.sh"), str(Path(target_path).resolve())]
    result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, check=False)
    return CommandResult(command=command, exit_code=result.returncode, stdout=result.stdout, stderr=result.stderr)
