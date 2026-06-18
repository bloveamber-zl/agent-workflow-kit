from __future__ import annotations

from runtime.models import StructuredTask
from runtime.router import route_intent


def rewrite_query(user_request: str, target_path: str | None = ".") -> StructuredTask:
    route = route_intent(user_request)
    missing_slots: list[str] = []
    questions: list[str] = []
    if not target_path:
        missing_slots.append("target_path")
        questions.append("请确认 target_path，即目标项目路径。")

    return StructuredTask(
        intent=route.intent,
        target_path=target_path or "",
        stack="auto",
        constraints=["do_not_overwrite_existing_files"],
        missing_slots=missing_slots,
        questions=questions,
    )
