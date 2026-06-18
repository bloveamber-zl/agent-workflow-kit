#!/usr/bin/env bash

set -euo pipefail

KIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT_DIR="$KIT_ROOT/eval/reports"
REPORT_PATH="$REPORT_DIR/latest.json"

mkdir -p "$REPORT_DIR"

python3 - "$KIT_ROOT" "$REPORT_PATH" <<'PY'
import json
import sys
from pathlib import Path

kit_root = Path(sys.argv[1])
report_path = Path(sys.argv[2])
sys.path.insert(0, str(kit_root))

from runtime.eval_runner import run_eval_cases

report = run_eval_cases(kit_root / "eval/cases", kit_root / "eval/fixtures")
with report_path.open("w", encoding="utf-8") as f:
    json.dump(report, f, ensure_ascii=False, indent=2)
    f.write("\n")

print("Eval Summary")
print(f"- cases: {report['cases']}")
print(f"- passed: {report['passed']}")
print(f"- failed: {report['failed']}")
print(f"- intent accuracy: {report['intent_accuracy']:.2%}")
print(f"- stack detection accuracy: {report['stack_detection_accuracy']:.2%}")
print(f"- slot filling accuracy: {report['slot_filling_accuracy']:.2%}")
print(f"- report: {report_path}")

if report["failed"]:
    sys.exit(1)
PY
