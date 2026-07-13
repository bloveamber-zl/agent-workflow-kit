from __future__ import annotations

from pathlib import Path

from runtime.models import ProjectContext


def render_report(
    intent: str,
    context: ProjectContext,
    result: str,
    trace_path: Path,
    execution_mode: str = "",
    plan_steps: list[str] | None = None,
) -> str:
    lines = [
        f"Intent: {intent}",
        f"Target: {context.target_path}",
        f"Stack: {context.detected_stack}",
        f"Result: {result}",
    ]
    if execution_mode:
        lines.append(f"Mode: {execution_mode}")
    lines.extend(f"Plan: {step}" for step in plan_steps or [])
    lines.append(f"Trace: {trace_path}")
    return "\n".join(lines)
