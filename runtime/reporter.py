from __future__ import annotations

from pathlib import Path

from runtime.models import ProjectContext


def render_report(intent: str, context: ProjectContext, result: str, trace_path: Path) -> str:
    return "\n".join(
        [
            f"Intent: {intent}",
            f"Target: {context.target_path}",
            f"Stack: {context.detected_stack}",
            f"Result: {result}",
            f"Trace: {trace_path}",
        ]
    )
