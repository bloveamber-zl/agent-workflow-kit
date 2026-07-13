import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from runtime.context_builder import build_context
from runtime.router import route_intent


ROOT = Path(__file__).resolve().parents[2]


class RuntimeMvpTests(unittest.TestCase):
    def test_router_detects_generate_upgrade_and_validate_intents(self):
        self.assertEqual(route_intent("给这个 Flutter 项目生成 agent workflow").intent, "generate_workflow")
        self.assertEqual(route_intent("把这个项目同步到最新版 workflow").intent, "upgrade_workflow")
        self.assertEqual(route_intent("校验当前项目的 workflow").intent, "validate_workflow")
        self.assertEqual(route_intent("进行项目深度扫描并回填").intent, "recon_project")

    def test_router_detects_test_case_workflow_modes(self):
        pre = route_intent("这个需求需要测试用例")
        post = route_intent("这个功能已经开发完成，请根据需求生成测试用例并执行测试")

        self.assertEqual(pre.intent, "test_case_workflow")
        self.assertEqual(pre.execution_mode, "pre_implementation")
        self.assertEqual(post.intent, "test_case_workflow")
        self.assertEqual(post.execution_mode, "post_implementation")

    def test_context_builder_detects_stack_and_workflow_state(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp)
            (target / "pubspec.yaml").write_text("name: demo\n", encoding="utf-8")

            context = build_context(target)

            self.assertEqual(context.detected_stack, "flutter")
            self.assertFalse(context.has_workflow)
            self.assertEqual(context.workflow_version, "")
            self.assertEqual(context.recommended_action, "generate_workflow")

    def test_cli_generates_workflow_validates_and_writes_trace(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp) / "target"
            target.mkdir()
            (target / "package.json").write_text('{"scripts": {}}\n', encoding="utf-8")

            result = subprocess.run(
                [
                    sys.executable,
                    "-m",
                    "runtime.cli",
                    "run",
                    "给这个项目生成 agent workflow",
                    "--target",
                    str(target),
                ],
                cwd=ROOT,
                text=True,
                capture_output=True,
            )

            self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
            self.assertIn("Intent: generate_workflow", result.stdout)
            self.assertIn("Result: passed", result.stdout)
            self.assertTrue((target / "AGENTS.md").is_file())
            self.assertTrue((target / ".agent/config.json").is_file())

            traces = sorted((target / ".agent/traces").glob("*.json"))
            trace_files = [path for path in traces if path.name != "schema.json"]
            self.assertEqual(len(trace_files), 1)
            with trace_files[0].open(encoding="utf-8") as f:
                trace = json.load(f)
            self.assertEqual(trace["final_status"], "passed")
            self.assertEqual([node["name"] for node in trace["nodes"]], ["router", "context_builder", "executor", "validator"])

    def test_cli_recon_backfills_project_docs(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp) / "target"
            target.mkdir()
            (target / "package.json").write_text('{"name":"demo","dependencies":{"react":"1.0.0"}}\n', encoding="utf-8")
            (target / "README.md").write_text("# Demo\n\n一个用于验证项目侦察的示例。\n", encoding="utf-8")
            (target / "src").mkdir()
            (target / "src" / "index.js").write_text("console.log('demo')\n", encoding="utf-8")

            subprocess.run(
                [
                    sys.executable,
                    "-m",
                    "runtime.cli",
                    "run",
                    "给这个项目生成 agent workflow",
                    "--target",
                    str(target),
                ],
                cwd=ROOT,
                text=True,
                capture_output=True,
                check=True,
            )

            result = subprocess.run(
                [
                    sys.executable,
                    "-m",
                    "runtime.cli",
                    "run",
                    "进行项目深度扫描并回填",
                    "--target",
                    str(target),
                ],
                cwd=ROOT,
                text=True,
                capture_output=True,
            )

            self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
            self.assertIn("Intent: recon_project", result.stdout)
            self.assertIn("Result: passed", result.stdout)
            overview = (target / "docs/project/structure/overview.md").read_text(encoding="utf-8")
            self.assertIn("自动侦察补充", overview)
            self.assertIn("src/", overview)
            capabilities = (target / "docs/workflow-capabilities.md").read_text(encoding="utf-8")
            self.assertIn("进行项目深度扫描并回填", capabilities)

    def test_cli_returns_agent_handoff_for_post_implementation_test_cases(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp) / "target"
            target.mkdir()
            (target / "package.json").write_text('{"name":"demo"}\n', encoding="utf-8")

            result = subprocess.run(
                [
                    sys.executable,
                    "-m",
                    "runtime.cli",
                    "run",
                    "这个功能已经开发完成，请根据需求生成测试用例并执行测试",
                    "--target",
                    str(target),
                ],
                cwd=ROOT,
                text=True,
                capture_output=True,
            )

            self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
            self.assertIn("Intent: test_case_workflow", result.stdout)
            self.assertIn("Result: agent_action_required", result.stdout)
            self.assertIn("Mode: post_implementation", result.stdout)
            self.assertIn("Plan: inspect_existing_implementation", result.stdout)

            traces = sorted((target / ".agent/traces").glob("*.json"))
            self.assertEqual(len(traces), 1)
            with traces[0].open(encoding="utf-8") as f:
                trace = json.load(f)
            self.assertEqual(trace["final_status"], "passed")
            self.assertEqual([node["name"] for node in trace["nodes"]], ["router", "context_builder", "planner"])


if __name__ == "__main__":
    unittest.main()
