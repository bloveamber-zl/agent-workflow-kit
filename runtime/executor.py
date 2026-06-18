from __future__ import annotations

import subprocess
from pathlib import Path

from runtime.models import CommandResult, ProjectContext


ROOT = Path(__file__).resolve().parents[1]


def execute_workflow_action(intent: str, context: ProjectContext, apply_upgrade: bool = False) -> CommandResult:
    if intent == "validate_workflow":
        command = [str(ROOT / "scripts/validate_target.sh"), str(context.target_path)]
    elif intent in {"upgrade_workflow", "repair_workflow"} or (intent == "generate_workflow" and context.has_workflow):
        command = [str(ROOT / "scripts/upgrade_workflow.sh"), str(context.target_path), "--stack", context.detected_stack]
        if apply_upgrade or intent == "repair_workflow":
            command.append("--apply")
    else:
        command = [
            str(ROOT / "scripts/generate_workflow.sh"),
            str(context.target_path),
            "--stack",
            context.detected_stack,
        ]

    result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, check=False)
    return CommandResult(command=command, exit_code=result.returncode, stdout=result.stdout, stderr=result.stderr)
