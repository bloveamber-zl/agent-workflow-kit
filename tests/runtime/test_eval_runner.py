import unittest
from pathlib import Path

from runtime.eval_runner import run_eval_cases


ROOT = Path(__file__).resolve().parents[2]


class EvalRunnerTests(unittest.TestCase):
    def test_eval_runner_reports_core_metrics(self):
        report = run_eval_cases(ROOT / "eval/cases", ROOT / "eval/fixtures")

        self.assertEqual(report["cases"], 3)
        self.assertEqual(report["passed"], 3)
        self.assertEqual(report["intent_accuracy"], 1.0)
        self.assertEqual(report["stack_detection_accuracy"], 1.0)
        self.assertEqual(report["slot_filling_accuracy"], 1.0)


if __name__ == "__main__":
    unittest.main()
