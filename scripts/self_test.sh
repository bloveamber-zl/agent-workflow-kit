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
  "$KIT_ROOT/scripts/validate_target.sh" "$target"

  echo "==> Verify overwrite protection: $stack"
  if "$KIT_ROOT/scripts/generate_workflow.sh" "$target" --stack "$stack" >/tmp/agent-workflow-kit-overwrite.log 2>&1; then
    echo "Expected overwrite protection to fail for stack: $stack" >&2
    exit 1
  fi

  "$KIT_ROOT/scripts/generate_workflow.sh" "$target" --stack "$stack" --force >/dev/null
  "$KIT_ROOT/scripts/validate_target.sh" "$target" >/dev/null
done

echo "All self tests passed."
