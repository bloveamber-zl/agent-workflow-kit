from __future__ import annotations

from runtime.models import PlanStep, ProjectContext, Requirement, StructuredTask, WorkflowPlan


def plan_workflow(task: StructuredTask, requirement: Requirement, context: ProjectContext) -> WorkflowPlan:
    if task.intent == "validate_workflow":
        actions = ["inspect_target", "run_validate_script"]
    elif task.intent in {"upgrade_workflow", "repair_workflow"} or context.has_workflow:
        actions = ["inspect_target", "detect_stack", "run_upgrade_script", "run_validate_script"]
    else:
        actions = ["inspect_target", "detect_stack", "run_generate_script", "run_validate_script"]

    return WorkflowPlan(
        steps=[
            PlanStep(id=action.replace("run_", "").replace("_script", ""), action=action)
            for action in actions
        ]
    )
