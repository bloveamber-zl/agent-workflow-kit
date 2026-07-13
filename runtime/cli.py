from __future__ import annotations

import argparse
from pathlib import Path

from runtime.context_builder import build_context
from runtime.executor import execute_workflow_action
from runtime.models import TraceNode
from runtime.planner import plan_workflow
from runtime.query_rewriter import rewrite_query
from runtime.reporter import render_report
from runtime.requirement_parser import parse_requirement
from runtime.router import route_intent
from runtime.trace import write_trace
from runtime.validator import validate_target


def run(user_request: str, target: str, apply_upgrade: bool = False) -> tuple[int, str]:
    route = route_intent(user_request)
    context = build_context(Path(target))
    intent = route.intent
    if intent == "unknown":
        nodes = [
            TraceNode("router", "failed", {"intent": intent, "confidence": route.confidence}, "Unable to route request")
        ]
        trace_path = write_trace(context.target_path, intent, user_request, nodes, "blocked")
        return 2, render_report(intent, context, "blocked", trace_path)

    if intent == "test_case_workflow":
        task = rewrite_query(user_request, target_path=str(context.target_path))
        requirement = parse_requirement(task)
        plan = plan_workflow(task, requirement, context)
        actions = [step.action for step in plan.steps]
        nodes = [
            TraceNode(
                "router",
                "passed",
                {
                    "intent": intent,
                    "confidence": route.confidence,
                    "execution_mode": task.execution_mode,
                },
            ),
            TraceNode(
                "context_builder",
                "passed",
                {
                    "detected_stack": context.detected_stack,
                    "has_workflow": context.has_workflow,
                    "workflow_version": context.workflow_version,
                },
            ),
            TraceNode(
                "planner",
                "passed",
                {
                    "goal": requirement.goal,
                    "actions": actions,
                },
            ),
        ]
        trace_path = write_trace(context.target_path, intent, user_request, nodes, "passed")
        return 0, render_report(
            intent,
            context,
            "agent_action_required",
            trace_path,
            execution_mode=task.execution_mode,
            plan_steps=actions,
        )

    execution = execute_workflow_action(intent, context, apply_upgrade=apply_upgrade)
    validation = validate_target(context.target_path) if execution.exit_code == 0 else None
    final_status = "passed" if execution.exit_code == 0 and validation and validation.exit_code == 0 else "failed"
    nodes = [
        TraceNode("router", "passed", {"intent": intent, "confidence": route.confidence}),
        TraceNode(
            "context_builder",
            "passed",
            {
                "detected_stack": context.detected_stack,
                "has_workflow": context.has_workflow,
                "workflow_version": context.workflow_version,
                "recommended_action": context.recommended_action,
            },
        ),
        TraceNode(
            "executor",
            execution.status,
            {"command": execution.command, "exit_code": execution.exit_code},
            execution.stderr.strip(),
        ),
    ]
    if validation is not None:
        nodes.append(
            TraceNode(
                "validator",
                validation.status,
                {"command": validation.command, "exit_code": validation.exit_code},
                validation.stderr.strip(),
            )
        )
    trace_path = write_trace(context.target_path, intent, user_request, nodes, final_status)
    return (0 if final_status == "passed" else 1), render_report(intent, context, final_status, trace_path)


def main() -> int:
    parser = argparse.ArgumentParser(prog="agent-workflow-runtime")
    subparsers = parser.add_subparsers(dest="command", required=True)
    run_parser = subparsers.add_parser("run")
    run_parser.add_argument("user_request")
    run_parser.add_argument("--target", default=".")
    run_parser.add_argument("--apply", action="store_true", help="Apply upgrade actions instead of dry-run.")
    args = parser.parse_args()

    if args.command == "run":
        exit_code, report = run(args.user_request, args.target, apply_upgrade=args.apply)
        print(report)
        return exit_code
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
