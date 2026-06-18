from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from runtime.context_builder import build_context
from runtime.query_rewriter import rewrite_query


def _load_case(path: Path) -> dict[str, Any]:
    with path.open(encoding="utf-8") as f:
        return json.load(f)


def run_eval_cases(cases_dir: str | Path, fixtures_dir: str | Path) -> dict[str, Any]:
    cases_root = Path(cases_dir)
    fixtures_root = Path(fixtures_dir)
    case_paths = sorted(cases_root.glob("*.json"))
    totals = {
        "cases": len(case_paths),
        "passed": 0,
        "intent_correct": 0,
        "stack_correct": 0,
        "slot_correct": 0,
        "failures": [],
    }

    for path in case_paths:
        case = _load_case(path)
        expected = case["expected"]
        fixture = case.get("fixture", "")
        target_path = str((fixtures_root / fixture).resolve()) if fixture else None
        task = rewrite_query(case["input"], target_path=target_path)
        context = build_context(target_path) if target_path else None
        actual_stack = context.detected_stack if context else "generic"

        intent_ok = task.intent == expected["intent"]
        stack_ok = actual_stack == expected["stack"]
        slot_ok = task.requires_user_input == expected["requires_user_input"]

        totals["intent_correct"] += int(intent_ok)
        totals["stack_correct"] += int(stack_ok)
        totals["slot_correct"] += int(slot_ok)
        if intent_ok and stack_ok and slot_ok:
            totals["passed"] += 1
        else:
            totals["failures"].append(
                {
                    "id": case["id"],
                    "intent_ok": intent_ok,
                    "stack_ok": stack_ok,
                    "slot_ok": slot_ok,
                }
            )

    count = totals["cases"] or 1
    return {
        "cases": totals["cases"],
        "passed": totals["passed"],
        "failed": totals["cases"] - totals["passed"],
        "intent_accuracy": totals["intent_correct"] / count,
        "stack_detection_accuracy": totals["stack_correct"] / count,
        "slot_filling_accuracy": totals["slot_correct"] / count,
        "failures": totals["failures"],
    }
