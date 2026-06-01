#!/usr/bin/env bash

set -euo pipefail

KIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/agent-workflow-kit.XXXXXX")"

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

SKILL_DIR="$KIT_ROOT/skills/agent-workflow"

echo "==> Validate Codex skill source"
if [ ! -f "$SKILL_DIR/SKILL.md" ]; then
  echo "Missing skill file: $SKILL_DIR/SKILL.md" >&2
  exit 1
fi

grep -q '^name: agent-workflow$' "$SKILL_DIR/SKILL.md"
grep -q '^description: ' "$SKILL_DIR/SKILL.md"

echo "==> Verify Codex skill install"
CODEX_HOME="$TMP_ROOT/codex-home" "$KIT_ROOT/scripts/install_codex_skill.sh" >/dev/null

INSTALLED_SKILL="$TMP_ROOT/codex-home/skills/agent-workflow/SKILL.md"
if [ ! -f "$INSTALLED_SKILL" ]; then
  echo "Installed skill missing: $INSTALLED_SKILL" >&2
  exit 1
fi

if grep -Fq '{{AGENT_WORKFLOW_KIT_ROOT}}' "$INSTALLED_SKILL"; then
  echo "Installed skill still contains unresolved kit root placeholder." >&2
  exit 1
fi

grep -Fq "$KIT_ROOT" "$INSTALLED_SKILL"

for stack_file in "$KIT_ROOT"/templates/stacks/*.yaml; do
  stack="$(basename "$stack_file" .yaml)"
  target="$TMP_ROOT/$stack-project"
  mkdir -p "$target"

  echo "==> Generate stack: $stack"
  "$KIT_ROOT/scripts/generate_workflow.sh" "$target" --stack "$stack" --project-name "$stack-project"
  test -f "$target/.agent/state/current-task.json"
  test -f "$target/.agent/traces/README.md"
  test -f "$target/docs/process/failure-taxonomy.md"
  "$KIT_ROOT/scripts/validate_target.sh" "$target"

  echo "==> Verify task state validation: $stack"
  cp "$target/.agent/state/current-task.json" "$TMP_ROOT/current-task.$stack.json"
  python3 - "$target/.agent/state/current-task.json" <<'PY'
import json
import sys
path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    data = json.load(f)
data["status"] = "invalid-status"
with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f)
PY
  if "$KIT_ROOT/scripts/validate_target.sh" "$target" >/tmp/agent-workflow-kit-invalid-state.log 2>&1; then
    echo "Expected invalid task status validation to fail for stack: $stack" >&2
    exit 1
  fi
  cp "$TMP_ROOT/current-task.$stack.json" "$target/.agent/state/current-task.json"
  "$KIT_ROOT/scripts/validate_target.sh" "$target" >/dev/null

  echo "==> Verify overwrite protection: $stack"
  if "$KIT_ROOT/scripts/generate_workflow.sh" "$target" --stack "$stack" >/tmp/agent-workflow-kit-overwrite.log 2>&1; then
    echo "Expected overwrite protection to fail for stack: $stack" >&2
    exit 1
  fi

  "$KIT_ROOT/scripts/generate_workflow.sh" "$target" --stack "$stack" --force >/dev/null
  "$KIT_ROOT/scripts/validate_target.sh" "$target" >/dev/null
done

echo "==> Verify workflow upgrade dry-run and apply"
upgrade_target="$TMP_ROOT/upgrade-project"
mkdir -p "$upgrade_target"
"$KIT_ROOT/scripts/generate_workflow.sh" "$upgrade_target" --stack flutter --project-name upgrade-project >/dev/null

printf '%s\n' 'custom progress must stay' > "$upgrade_target/docs/coding-progress.md"
printf '%s\n' 'old common index' > "$upgrade_target/docs/index.md"
printf '%s\n' 'old acceptance script' > "$upgrade_target/scripts/acceptance_simulator.sh"

"$KIT_ROOT/scripts/upgrade_workflow.sh" "$upgrade_target" --stack flutter > "$TMP_ROOT/upgrade-dry-run.log"
grep -q 'DRY-RUN' "$TMP_ROOT/upgrade-dry-run.log"
grep -q 'update docs/index.md' "$TMP_ROOT/upgrade-dry-run.log"
grep -q 'update scripts/acceptance_simulator.sh' "$TMP_ROOT/upgrade-dry-run.log"
grep -q 'old common index' "$upgrade_target/docs/index.md"

"$KIT_ROOT/scripts/upgrade_workflow.sh" "$upgrade_target" --stack flutter --apply > "$TMP_ROOT/upgrade-apply.log"
grep -q 'APPLY' "$TMP_ROOT/upgrade-apply.log"
grep -q 'dokichat\|upgrade-project' "$upgrade_target/docs/index.md"
grep -q 'custom progress must stay' "$upgrade_target/docs/coding-progress.md"
"$KIT_ROOT/scripts/validate_target.sh" "$upgrade_target" >/dev/null

echo "==> Verify workflow upgrade adds missing generated files"
rm "$upgrade_target/docs/acceptance_simulator.md"
rm -rf "$upgrade_target/.agent"
rm "$upgrade_target/docs/process/failure-taxonomy.md"
"$KIT_ROOT/scripts/upgrade_workflow.sh" "$upgrade_target" --stack flutter --apply >/dev/null
test -f "$upgrade_target/docs/acceptance_simulator.md"
test -f "$upgrade_target/.agent/state/current-task.json"
test -f "$upgrade_target/.agent/traces/README.md"
test -f "$upgrade_target/docs/process/failure-taxonomy.md"
"$KIT_ROOT/scripts/validate_target.sh" "$upgrade_target" >/dev/null

echo "==> Verify batch workflow upgrade scan"
batch_root="$TMP_ROOT/project-root"
mkdir -p "$batch_root/upgrade-project-copy" "$batch_root/not-a-workflow"
"$KIT_ROOT/scripts/generate_workflow.sh" "$batch_root/upgrade-project-copy" --stack node --project-name upgrade-project-copy >/dev/null
"$KIT_ROOT/scripts/upgrade_all_workflows.sh" "$batch_root" --stack node > "$TMP_ROOT/upgrade-all.log"
grep -q 'upgrade-project-copy' "$TMP_ROOT/upgrade-all.log"
if grep -q 'not-a-workflow' "$TMP_ROOT/upgrade-all.log"; then
  echo "Batch upgrade should ignore directories without workflow files." >&2
  exit 1
fi

echo "All self tests passed."
