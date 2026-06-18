import unittest
from pathlib import Path

from runtime.context_builder import build_context
from runtime.planner import plan_workflow
from runtime.query_rewriter import rewrite_query
from runtime.requirement_parser import parse_requirement
from runtime.skill_selector import select_skill


class PlanningComponentTests(unittest.TestCase):
    def test_query_rewriter_returns_missing_target_slot(self):
        task = rewrite_query("帮我安装 agent workflow", target_path=None)

        self.assertTrue(task.requires_user_input)
        self.assertEqual(task.missing_slots, ["target_path"])
        self.assertIn("target_path", task.questions[0])

    def test_requirement_parser_builds_acceptance_and_risks(self):
        task = rewrite_query("给当前项目生成 agent workflow", target_path="/tmp/demo")

        requirement = parse_requirement(task)

        self.assertEqual(requirement.goal, "为目标项目安装 agent workflow")
        self.assertIn("不得覆盖已有文件", requirement.constraints)
        self.assertIn("validate_target.sh 通过", requirement.acceptance)

    def test_planner_and_skill_selector_for_generation(self):
        context = build_context(Path.cwd())
        task = rewrite_query("生成 agent workflow", target_path=str(Path.cwd()))
        requirement = parse_requirement(task)

        plan = plan_workflow(task, requirement, context)
        skill = select_skill(task, context)

        self.assertEqual([step.action for step in plan.steps], ["inspect_target", "detect_stack", "run_generate_script", "run_validate_script"])
        self.assertEqual(skill.skill, "agent-workflow")
        self.assertIn("scripts/generate_workflow.sh", skill.entrypoints)


if __name__ == "__main__":
    unittest.main()
