from __future__ import annotations

from runtime.models import StructuredTask
from runtime.router import route_intent


def rewrite_query(user_request: str, target_path: str | None = ".") -> StructuredTask:
    route = route_intent(user_request)
    missing_slots: list[str] = []
    questions: list[str] = []
    constraints = ["do_not_overwrite_existing_files"]
    if not target_path:
        missing_slots.append("target_path")
        questions.append("请确认 target_path，即目标项目路径。")
    if route.intent == "recon_project":
        constraints.extend(["preserve_existing_descriptions", "ask_before_changing_existing_text"])
    if route.intent == "test_case_workflow":
        constraints.extend(["test_case_mode_enabled", "preserve_original_acceptance_criteria"])

    return StructuredTask(
        intent=route.intent,
        target_path=target_path or "",
        stack="auto",
        constraints=constraints,
        missing_slots=missing_slots,
        questions=questions,
        execution_mode=route.execution_mode,
    )
