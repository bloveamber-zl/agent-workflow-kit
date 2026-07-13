from __future__ import annotations

from runtime.models import PlanStep, ProjectContext, Requirement, StructuredTask, WorkflowPlan


def plan_workflow(task: StructuredTask, requirement: Requirement, context: ProjectContext) -> WorkflowPlan:
    if task.intent == "test_case_workflow":
        actions = [
            "inspect_target",
            "parse_requirement",
        ]
        if task.execution_mode == "post_implementation":
            actions.append("inspect_existing_implementation")
        actions.extend(
            [
                "generate_test_case_doc",
                "request_test_case_approval",
                "generate_automated_tests",
            ]
        )
        if task.execution_mode == "pre_implementation":
            actions.extend(["verify_expected_failure", "implement_feature"])
        actions.extend(["run_requirement_tests", "record_test_evidence"])
    elif task.intent == "validate_workflow":
        actions = ["inspect_target", "run_validate_script"]
    elif task.intent == "recon_project":
        actions = ["inspect_target", "detect_stack", "run_recon_script", "run_validate_script"]
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
