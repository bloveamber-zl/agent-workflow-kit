import json
import tempfile
import unittest
from pathlib import Path

from runtime.trace import write_trace


class TraceTests(unittest.TestCase):
    def test_rapid_writes_preserve_each_trace(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            first_path = write_trace(temp_dir, "test_case_workflow", "first", [], "passed")
            second_path = write_trace(temp_dir, "test_case_workflow", "second", [], "passed")

            self.assertNotEqual(first_path, second_path)
            self.assertEqual(json.loads(Path(first_path).read_text(encoding="utf-8"))["user_request"], "first")
            self.assertEqual(json.loads(Path(second_path).read_text(encoding="utf-8"))["user_request"], "second")


if __name__ == "__main__":
    unittest.main()
