#!/usr/bin/env bash

set -euo pipefail

TARGET_PATH="${1:-}"

if [ -z "$TARGET_PATH" ]; then
  echo "Usage: scripts/validate_target.sh <target-project-path>" >&2
  exit 1
fi

if [ ! -d "$TARGET_PATH" ]; then
  echo "Target project does not exist: $TARGET_PATH" >&2
  exit 1
fi

TARGET_ROOT="$(cd "$TARGET_PATH" && pwd)"

required_files=(
  ".agent/state/current-task.json"
  ".agent/traces/README.md"
  "AGENTS.md"
  "init.sh"
  "docs/index.md"
  "docs/verification.md"
  "docs/process/verification.md"
  "docs/process/failure-taxonomy.md"
  "docs/acceptance_simulator.md"
  "docs/coding-progress.md"
  "docs/feature_list.json"
  "docs/session-handoff.md"
  "docs/project/structure/overview.md"
  "docs/project/structure/architecture.md"
  "docs/project/constraints.md"
  "docs/project/frontend.md"
  "docs/project/features/overview.md"
  "docs/requirements/parsed-requirements.md"
  "docs/requirements/open-questions.md"
  "docs/requirements/traceability.md"
  "docs/design/index.md"
  "docs/design/workflow-bootstrap.md"
  "docs/exec-plans/active/index.md"
  "docs/exec-plans/active/workflow-bootstrap.md"
  "docs/exec-plans/completed/index.md"
  "docs/exec-plans/tech-debt-tracker.md"
  "docs/reports/test-report.md"
  "scripts/acceptance_simulator.sh"
)

for file in "${required_files[@]}"; do
  if [ ! -f "$TARGET_ROOT/$file" ]; then
    echo "Missing required file: $file" >&2
    exit 1
  fi
done

if grep -R '{{[A-Z_][A-Z_]*}}' "$TARGET_ROOT/AGENTS.md" "$TARGET_ROOT/init.sh" "$TARGET_ROOT/docs" >/dev/null; then
  echo "Unresolved template placeholders found." >&2
  exit 1
fi

bash -n "$TARGET_ROOT/init.sh"
bash -n "$TARGET_ROOT/scripts/acceptance_simulator.sh"

python3 -m json.tool "$TARGET_ROOT/docs/feature_list.json" >/dev/null
python3 -m json.tool "$TARGET_ROOT/.agent/state/current-task.json" >/dev/null

python3 - "$TARGET_ROOT/.agent/state/current-task.json" <<'PY'
import json
import sys

allowed_statuses = {
    "intake",
    "understanding",
    "designing",
    "planning",
    "approved",
    "implementing",
    "verifying",
    "done",
    "blocked",
}

path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    data = json.load(f)

status = data.get("status")
if status not in allowed_statuses:
    print(f"Invalid current task status: {status!r}", file=sys.stderr)
    print("Allowed statuses: " + ", ".join(sorted(allowed_statuses)), file=sys.stderr)
    sys.exit(1)
PY

echo "Workflow files look valid: $TARGET_ROOT"
