import unittest
import tempfile
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
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp)
            context = build_context(target)
            task = rewrite_query("生成 agent workflow", target_path=str(target))
            requirement = parse_requirement(task)

            plan = plan_workflow(task, requirement, context)
            skill = select_skill(task, context)

            self.assertEqual([step.action for step in plan.steps], ["inspect_target", "detect_stack", "run_generate_script", "run_validate_script"])
            self.assertEqual(skill.skill, "agent-workflow")
            self.assertIn("scripts/generate_workflow.sh", skill.entrypoints)

    def test_planner_for_project_reconnaissance(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp)
            (target / "package.json").write_text('{"name":"demo"}\n', encoding="utf-8")

            context = build_context(target)
            task = rewrite_query("进行项目深度扫描并回填", target_path=str(target))
            requirement = parse_requirement(task)

            plan = plan_workflow(task, requirement, context)
            skill = select_skill(task, context)

            self.assertEqual(task.intent, "recon_project")
            self.assertIn("preserve_existing_descriptions", task.constraints)
            self.assertEqual(
                [step.action for step in plan.steps],
                ["inspect_target", "detect_stack", "run_recon_script", "run_validate_script"],
            )
            self.assertIn("scripts/recon_project.sh", skill.entrypoints)

    def test_planner_for_pre_implementation_test_case_workflow(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp)
            context = build_context(target)
            task = rewrite_query("这个需求需要测试用例", target_path=str(target))
            requirement = parse_requirement(task)

            plan = plan_workflow(task, requirement, context)
            skill = select_skill(task, context)

            self.assertEqual(task.intent, "test_case_workflow")
            self.assertEqual(task.execution_mode, "pre_implementation")
            self.assertIn("test_case_mode_enabled", task.constraints)
            self.assertIn("每个验收标准映射到测试用例 ID", requirement.acceptance)
            self.assertEqual(
                [step.action for step in plan.steps],
                [
                    "inspect_target",
                    "parse_requirement",
                    "generate_test_case_doc",
                    "request_test_case_approval",
                    "generate_automated_tests",
                    "verify_expected_failure",
                    "implement_feature",
                    "run_requirement_tests",
                    "record_test_evidence",
                ],
            )
            self.assertEqual(skill.skill, "agent-workflow")
            self.assertIn("docs/test-cases/README.md", skill.entrypoints)

    def test_planner_for_post_implementation_test_case_workflow(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp)
            context = build_context(target)
            task = rewrite_query(
                "这个功能已经开发完成，请根据需求生成测试用例并执行测试",
                target_path=str(target),
            )
            requirement = parse_requirement(task)

            plan = plan_workflow(task, requirement, context)

            actions = [step.action for step in plan.steps]
            self.assertEqual(task.execution_mode, "post_implementation")
            self.assertIn("inspect_existing_implementation", actions)
            self.assertNotIn("verify_expected_failure", actions)
            self.assertNotIn("implement_feature", actions)


if __name__ == "__main__":
    unittest.main()
