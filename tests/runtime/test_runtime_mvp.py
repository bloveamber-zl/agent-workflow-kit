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


if __name__ == "__main__":
    unittest.main()
