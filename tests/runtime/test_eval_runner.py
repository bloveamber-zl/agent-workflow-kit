import subprocess
import unittest
from pathlib import Path

from runtime.eval_runner import run_eval_cases


ROOT = Path(__file__).resolve().parents[2]


class EvalRunnerTests(unittest.TestCase):
    def test_eval_runner_reports_core_metrics(self):
        report = run_eval_cases(ROOT / "eval/cases", ROOT / "eval/fixtures")

        self.assertEqual(report["cases"], 5)
        self.assertEqual(report["passed"], 5)
        self.assertEqual(report["intent_accuracy"], 1.0)
        self.assertEqual(report["stack_detection_accuracy"], 1.0)
        self.assertEqual(report["slot_filling_accuracy"], 1.0)
        self.assertEqual(report["execution_mode_accuracy"], 1.0)

    def test_eval_script_prints_execution_mode_accuracy(self):
        result = subprocess.run(
            [str(ROOT / "scripts/run_eval.sh")],
            cwd=ROOT,
            text=True,
            capture_output=True,
        )

        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        self.assertIn("execution mode accuracy: 100.00%", result.stdout)


if __name__ == "__main__":
    unittest.main()
