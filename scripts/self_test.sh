#!/usr/bin/env bash

set -euo pipefail

KIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/agent-workflow-kit.XXXXXX")"

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

SKILL_DIR="$KIT_ROOT/skills/agent-workflow"
KIT_VERSION="$(tr -d '[:space:]' < "$KIT_ROOT/VERSION")"
TEMPLATE_REVISION="$(tr -d '[:space:]' < "$KIT_ROOT/templates/VERSION")"

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
grep -Fq 'python3 -m runtime.cli run' "$INSTALLED_SKILL"
grep -Fq '.agent/config.json' "$INSTALLED_SKILL"
grep -Fq 'scripts/run_eval.sh' "$INSTALLED_SKILL"
grep -Fq 'scripts/recon_project.sh' "$INSTALLED_SKILL"
grep -Fq 'L0-L4' "$INSTALLED_SKILL"
grep -Fq 'test-case self-validation' "$INSTALLED_SKILL"
grep -Fq 'AGENT_WORKFLOW_PATROL' "$INSTALLED_SKILL"
grep -Fq 'AGENT_WORKFLOW_CODEGRAPH' "$INSTALLED_SKILL"
grep -Fq 'AGENT_WORKFLOW_OPENDESIGN' "$INSTALLED_SKILL"
grep -Fq 'test_case_mode' "$INSTALLED_SKILL"
grep -Fq 'pre_implementation' "$INSTALLED_SKILL"
grep -Fq 'post_implementation' "$INSTALLED_SKILL"
grep -Fq 'docs/test-cases/<requirement-id>.md' "$INSTALLED_SKILL"
grep -Fq '不主动提醒' "$INSTALLED_SKILL"
grep -Fq 'After changing agent-workflow-kit, decide whether the installed skill must be refreshed' "$INSTALLED_SKILL"

echo "==> Run runtime unit tests"
cd "$KIT_ROOT"
python3 -m unittest tests.runtime.test_runtime_mvp
python3 -m unittest tests.runtime.test_planning_components
python3 -m unittest tests.runtime.test_eval_runner
python3 -m unittest tests.runtime.test_trace
scripts/run_eval.sh

for stack_file in "$KIT_ROOT"/templates/stacks/*.yaml; do
  stack="$(basename "$stack_file" .yaml)"
  target="$TMP_ROOT/$stack-project"
  mkdir -p "$target"
  case "$stack" in
    flutter)
      mkdir -p "$target/android" "$target/ios" "$target/lib" "$target/test" "$target/.vscode" "$target/define_config"
      printf '%s\n' 'name: flutter_project' > "$target/pubspec.yaml"
      cat > "$target/.vscode/launch.json" <<'JSON'
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "flutter-project-ios",
      "request": "launch",
      "type": "dart",
      "args": ["--dart-define-from-file", "define_config/.custom.json"]
    },
    {
      "name": "flutter-project-android",
      "request": "launch",
      "type": "dart",
      "args": [
        "--dart-define-from-file",
        "define_config/.custom.json",
        "--flavor",
        "official"
      ]
    }
  ]
}
JSON
      printf '%s\n' '{"APP_ENV":"test"}' > "$target/define_config/.custom.json"
      ;;
    node)
      mkdir -p "$target/src" "$target/public"
      printf '%s\n' '{"name":"node-project"}' > "$target/package.json"
      ;;
    python)
      mkdir -p "$target/src" "$target/test"
      printf '%s\n' '[project]' 'name = "python-project"' > "$target/pyproject.toml"
      ;;
  esac
  printf '%s\n' "# $stack-project" > "$target/README.md"

  echo "==> Generate stack: $stack"
  "$KIT_ROOT/scripts/generate_workflow.sh" "$target" --stack "$stack" --project-name "$stack-project"
  test -f "$target/.agent/state/current-task.json"
  test -f "$target/.agent/config.json"
  test -f "$target/.agent/traces/README.md"
  test -f "$target/.agent/traces/schema.json"
  test -f "$target/.agent/evals/README.md"
  test -f "$target/docs/process/badcase-analysis.md"
  test -f "$target/docs/process/failure-taxonomy.md"
  test -f "$target/docs/reports/eval-report.md"
  test -f "$target/docs/workflow-capabilities.md"
  test -f "$target/docs/test-cases/README.md"
  grep -q 'test_case_mode' "$target/.agent/state/current-task.json"
  grep -q '默认关闭' "$target/docs/test-cases/README.md"
  grep -q 'post_implementation' "$target/docs/test-cases/README.md"
  grep -q '测试用例驱动模式' "$target/docs/process/verification.md"
  grep -q '测试用例 ID' "$target/docs/requirements/traceability.md"
  grep -q '执行模式' "$target/docs/reports/test-report.md"
  grep -q '初始化自动侦察' "$target/docs/project/structure/overview.md"
  grep -q '初始化自动侦察' "$target/docs/project/structure/architecture.md"
  grep -q '初始化自动侦察' "$target/docs/project/features/overview.md"
  grep -q '初始化自动侦察' "$target/docs/project/frontend.md"
  grep -q '初始化自动侦察' "$target/docs/project/constraints.md"
  grep -q 'README.md' "$target/docs/project/structure/overview.md"
  if [ "$stack" = "flutter" ]; then
    grep -q 'Android、iOS' "$target/docs/project/structure/overview.md"
  fi
  grep -q 'BEGIN agent-workflow-kit' "$target/.gitignore"
  grep -q '/.agent/' "$target/.gitignore"
  grep -q '/docs/requirements/' "$target/.gitignore"
  grep -q '/docs/design/' "$target/.gitignore"
  grep -q '/docs/exec-plans/' "$target/.gitignore"
  grep -q '/docs/workflow-capabilities.md' "$target/.gitignore"
  if grep -q '/docs/design/workflow-bootstrap.md' "$target/.gitignore"; then
    echo "Generated .gitignore should ignore workflow document directories, not individual dynamic docs." >&2
    exit 1
  fi
  python3 - "$target/.agent/config.json" "$KIT_VERSION" "$TEMPLATE_REVISION" <<'PY'
import json
import sys

path, expected_kit_version, expected_template_revision = sys.argv[1:4]
with open(path, encoding="utf-8") as f:
    data = json.load(f)

if data.get("kit_version") != expected_kit_version:
    print("Generated config has stale kit_version", file=sys.stderr)
    sys.exit(1)
if data.get("template_revision") != expected_template_revision:
    print("Generated config has stale template_revision", file=sys.stderr)
    sys.exit(1)
enhancements = data.get("enhancements", {})
if enhancements.get("patrol") is not False:
    print("Default generation should leave patrol disabled", file=sys.stderr)
    sys.exit(1)
if enhancements.get("codegraph") is not False:
    print("Default generation should leave codegraph disabled", file=sys.stderr)
    sys.exit(1)
if enhancements.get("opendesign") is not False:
    print("Default generation should leave opendesign disabled", file=sys.stderr)
    sys.exit(1)
PY
  grep -q 'L0' "$target/docs/process/verification.md"
  grep -q 'L4' "$target/docs/process/verification.md"
  grep -q '场景触发增强' "$target/docs/process/verification.md"
  grep -q '测试用例自验证' "$target/docs/process/verification.md"
  grep -q '可选 Patrol 自动化验收' "$target/docs/process/verification.md"
  grep -q '验收等级' "$target/docs/reports/test-report.md"
  grep -q '增强触发' "$target/docs/reports/test-report.md"
  grep -q '证据类型' "$target/docs/reports/test-report.md"
  grep -q 'Patrol 自动化验收' "$target/docs/reports/test-report.md"
  grep -q '验收等级' "$target/docs/requirements/traceability.md"
  grep -q '增强触发' "$target/docs/requirements/traceability.md"
  grep -q 'Patrol 用例' "$target/docs/requirements/traceability.md"
  grep -q '进行项目深度扫描并回填' "$target/docs/workflow-capabilities.md"
  grep -q '测试用例驱动验证 | enabled' "$target/docs/workflow-capabilities.md"
  grep -q '开发前模式' "$target/docs/workflow-capabilities.md"
  grep -q '开发后模式' "$target/docs/workflow-capabilities.md"
  grep -q '默认关闭' "$target/docs/workflow-capabilities.md"
  printf '%s\n' 'Documenting template syntax like {{PROJECT_NAME}} is allowed in non-workflow docs.' > "$target/docs/template-variables.md"
  "$KIT_ROOT/scripts/validate_target.sh" "$target"

  echo "==> Verify project recon backfill: $stack"
  "$KIT_ROOT/scripts/recon_project.sh" "$target" >/dev/null
  grep -q '自动侦察补充' "$target/docs/project/structure/overview.md"
  grep -q 'BEGIN AUTO-RECON:overview' "$target/docs/project/structure/overview.md"
  grep -q 'BEGIN AUTO-RECON:capabilities' "$target/docs/workflow-capabilities.md"
  grep -q '测试用例驱动验证 | enabled' "$target/docs/workflow-capabilities.md"
  grep -q '开发后模式' "$target/docs/workflow-capabilities.md"

  echo "==> Verify acceptance evidence dry-run: $stack"
  ACCEPTANCE_DRY_RUN=1 ACCEPTANCE_SCENARIO="startup-smoke" ACCEPTANCE_EXPECTED_PATH="打开应用首页" "$target/scripts/acceptance_simulator.sh" >/dev/null
  evidence_file="$(find "$target/.dart_tool/acceptance" -name evidence.json | sort | tail -n 1)"
  test -f "$evidence_file"
  grep -q '"status": "dry-run"' "$evidence_file"
  grep -q '"scenario": "startup-smoke"' "$evidence_file"
  if [ "$stack" = "flutter" ]; then
    grep -q -- '--dart-define-from-file define_config/.custom.json' "$evidence_file"
    ACCEPTANCE_DRY_RUN=1 ACCEPTANCE_PLATFORM=android "$target/scripts/acceptance_simulator.sh" >/dev/null
    android_evidence_file="$(find "$target/.dart_tool/acceptance" -name evidence.json | sort | tail -n 1)"
    grep -q -- '--flavor official' "$android_evidence_file"
  fi

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

  python3 - "$target/.agent/state/current-task.json" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    data = json.load(f)
for key in ("test_case_mode", "test_case_execution_mode", "test_case_doc"):
    data.pop(key, None)
with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
    f.write("\n")
PY
  "$KIT_ROOT/scripts/validate_target.sh" "$target" >/dev/null

  python3 - "$target/.agent/state/current-task.json" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    data = json.load(f)
data["test_case_mode"] = True
data["test_case_execution_mode"] = "invalid"
data["test_case_doc"] = ""
with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
    f.write("\n")
PY
  if "$KIT_ROOT/scripts/validate_target.sh" "$target" >/tmp/agent-workflow-kit-invalid-test-case-mode.log 2>&1; then
    echo "Expected invalid test case mode validation to fail for stack: $stack" >&2
    exit 1
  fi
  cp "$TMP_ROOT/current-task.$stack.json" "$target/.agent/state/current-task.json"

  echo "==> Verify overwrite protection: $stack"
  if "$KIT_ROOT/scripts/generate_workflow.sh" "$target" --stack "$stack" >/tmp/agent-workflow-kit-overwrite.log 2>&1; then
    echo "Expected overwrite protection to fail for stack: $stack" >&2
    exit 1
  fi

  "$KIT_ROOT/scripts/generate_workflow.sh" "$target" --stack "$stack" --force >/dev/null
  "$KIT_ROOT/scripts/validate_target.sh" "$target" >/dev/null
done

echo "==> Verify optional Flutter Patrol workflow prompt path"
patrol_target="$TMP_ROOT/patrol-project"
mkdir -p "$patrol_target"
cat > "$patrol_target/pubspec.yaml" <<'YAML'
name: patrol_project
description: Patrol workflow fixture
environment:
  sdk: ^3.8.0
dependencies:
  flutter:
    sdk: flutter
YAML
AGENT_WORKFLOW_PATROL=yes "$KIT_ROOT/scripts/generate_workflow.sh" "$patrol_target" --stack flutter --project-name patrol-project > "$TMP_ROOT/patrol-generate.log"
grep -q 'Patrol' "$TMP_ROOT/patrol-generate.log"
test -f "$patrol_target/docs/testing/patrol.md"
test -f "$patrol_target/scripts/patrol_acceptance.sh"
grep -q 'patrol test' "$patrol_target/docs/testing/patrol.md"
grep -q 'patrol test' "$patrol_target/scripts/patrol_acceptance.sh"
grep -q '需求级用例生成' "$patrol_target/docs/testing/patrol.md"
grep -q 'PATROL_TARGET' "$patrol_target/docs/testing/patrol.md"
grep -q 'PATROL_DRY_RUN' "$patrol_target/scripts/patrol_acceptance.sh"
grep -q 'dart_define_file' "$patrol_target/scripts/patrol_acceptance.sh"
grep -q '"patrol": true' "$patrol_target/.agent/config.json"
"$KIT_ROOT/scripts/validate_target.sh" "$patrol_target" >/dev/null
PATROL_DRY_RUN=1 PATROL_TARGET="patrol_test/req_example_test.dart" PATROL_SCENARIO="REQ-EXAMPLE" "$patrol_target/scripts/patrol_acceptance.sh" >/dev/null
patrol_evidence_file="$(find "$patrol_target/.dart_tool/acceptance" -name evidence.json | sort | tail -n 1)"
test -f "$patrol_evidence_file"
grep -q '"status": "dry-run"' "$patrol_evidence_file"
grep -q '"target": "patrol_test/req_example_test.dart"' "$patrol_evidence_file"

echo "==> Verify optional CodeGraph workflow prompt path"
codegraph_target="$TMP_ROOT/codegraph-project"
mkdir -p "$codegraph_target"
printf '%s\n' '{"name":"codegraph-project"}' > "$codegraph_target/package.json"
AGENT_WORKFLOW_CODEGRAPH=yes "$KIT_ROOT/scripts/generate_workflow.sh" "$codegraph_target" --stack node --project-name codegraph-project > "$TMP_ROOT/codegraph-generate.log"
grep -q 'CodeGraph' "$TMP_ROOT/codegraph-generate.log"
test -f "$codegraph_target/docs/tools/codegraph.md"
grep -q 'codegraph init -i' "$codegraph_target/docs/tools/codegraph.md"
grep -q '"codegraph": true' "$codegraph_target/.agent/config.json"
"$KIT_ROOT/scripts/validate_target.sh" "$codegraph_target" >/dev/null

echo "==> Verify optional Open Design workflow prompt path"
opendesign_target="$TMP_ROOT/opendesign-project"
mkdir -p "$opendesign_target"
printf '%s\n' '{"name":"opendesign-project"}' > "$opendesign_target/package.json"
AGENT_WORKFLOW_OPENDESIGN=yes "$KIT_ROOT/scripts/generate_workflow.sh" "$opendesign_target" --stack node --project-name opendesign-project > "$TMP_ROOT/opendesign-generate.log"
grep -q 'Open Design' "$TMP_ROOT/opendesign-generate.log"
test -f "$opendesign_target/docs/tools/opendesign.md"
grep -q '用户明确要求' "$opendesign_target/docs/tools/opendesign.md"
grep -q 'od mcp install codex --print' "$opendesign_target/docs/tools/opendesign.md"
grep -q 'codex mcp list' "$opendesign_target/docs/tools/opendesign.md"
grep -q '生成质量提示词' "$opendesign_target/docs/tools/opendesign.md"
grep -q '不要 AI demo 感' "$opendesign_target/docs/tools/opendesign.md"
grep -q '质量门禁' "$opendesign_target/docs/tools/opendesign.md"
grep -q '\$openai-image-gateway' "$opendesign_target/docs/tools/opendesign.md"
grep -q '素材板' "$opendesign_target/docs/tools/opendesign.md"
grep -q '"opendesign": true' "$opendesign_target/.agent/config.json"
"$KIT_ROOT/scripts/validate_target.sh" "$opendesign_target" >/dev/null

echo "==> Verify workflow upgrade dry-run and apply"
upgrade_target="$TMP_ROOT/upgrade-project"
mkdir -p "$upgrade_target"
"$KIT_ROOT/scripts/generate_workflow.sh" "$upgrade_target" --stack flutter --project-name upgrade-project >/dev/null

printf '%s\n' 'custom progress must stay' > "$upgrade_target/docs/coding-progress.md"
printf '%s\n' 'old common index' > "$upgrade_target/docs/index.md"
printf '%s\n' 'old acceptance script' > "$upgrade_target/scripts/acceptance_simulator.sh"
cat > "$upgrade_target/.gitignore" <<'EOF'
# BEGIN agent-workflow-kit
# Generated agent workflow files
/.agent/
/docs/design/workflow-bootstrap.md
/docs/requirements/traceability.md
# END agent-workflow-kit
EOF
python3 - "$upgrade_target/.agent/config.json" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    data = json.load(f)

data["kit_version"] = "0.0.0"
data["template_revision"] = "2000-01-01"
data["local_config_must_stay"] = "preserved"

with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
    f.write("\n")
PY

"$KIT_ROOT/scripts/upgrade_workflow.sh" "$upgrade_target" --stack flutter > "$TMP_ROOT/upgrade-dry-run.log"
grep -q 'DRY-RUN' "$TMP_ROOT/upgrade-dry-run.log"
grep -q 'update docs/index.md' "$TMP_ROOT/upgrade-dry-run.log"
grep -q 'update scripts/acceptance_simulator.sh' "$TMP_ROOT/upgrade-dry-run.log"
grep -q 'old common index' "$upgrade_target/docs/index.md"

AGENT_WORKFLOW_CODEGRAPH=yes AGENT_WORKFLOW_OPENDESIGN=yes "$KIT_ROOT/scripts/upgrade_workflow.sh" "$upgrade_target" --stack flutter --apply > "$TMP_ROOT/upgrade-apply.log"
grep -q 'APPLY' "$TMP_ROOT/upgrade-apply.log"
grep -q 'gitignore workflow ignore block' "$TMP_ROOT/upgrade-apply.log"
grep -q 'CodeGraph: yes' "$TMP_ROOT/upgrade-apply.log"
grep -q 'Open Design: yes' "$TMP_ROOT/upgrade-apply.log"
grep -q 'dokichat\|upgrade-project' "$upgrade_target/docs/index.md"
upgrade_target_root="$(cd "$upgrade_target" && pwd)"
grep -Fq "$upgrade_target_root" "$upgrade_target/AGENTS.md"
grep -q 'BEGIN agent-workflow-kit' "$upgrade_target/.gitignore"
grep -q '/docs/design/' "$upgrade_target/.gitignore"
grep -q '/docs/requirements/' "$upgrade_target/.gitignore"
if grep -q '/docs/design/workflow-bootstrap.md' "$upgrade_target/.gitignore"; then
  echo "Upgrade should replace stale file-level workflow document ignore rules." >&2
  exit 1
fi
test -f "$upgrade_target/docs/tools/codegraph.md"
test -f "$upgrade_target/docs/tools/opendesign.md"
grep -q 'od mcp install codex --print' "$upgrade_target/docs/tools/opendesign.md"
grep -q '不要 AI demo 感' "$upgrade_target/docs/tools/opendesign.md"
grep -q '\$openai-image-gateway' "$upgrade_target/docs/tools/opendesign.md"
grep -q '素材板' "$upgrade_target/docs/tools/opendesign.md"
python3 - "$upgrade_target/.agent/config.json" "$KIT_VERSION" "$TEMPLATE_REVISION" <<'PY'
import json
import sys

path, expected_kit_version, expected_template_revision = sys.argv[1:4]
with open(path, encoding="utf-8") as f:
    data = json.load(f)

if data.get("kit_version") != expected_kit_version:
    print("Upgrade did not refresh kit_version", file=sys.stderr)
    sys.exit(1)
if data.get("template_revision") != expected_template_revision:
    print("Upgrade did not refresh template_revision", file=sys.stderr)
    sys.exit(1)
if data.get("enhancements", {}).get("codegraph") is not True:
    print("Upgrade did not enable codegraph enhancement", file=sys.stderr)
    sys.exit(1)
if data.get("enhancements", {}).get("opendesign") is not True:
    print("Upgrade did not enable opendesign enhancement", file=sys.stderr)
    sys.exit(1)
if data.get("local_config_must_stay") != "preserved":
    print("Upgrade should preserve local config fields", file=sys.stderr)
    sys.exit(1)
PY
grep -q 'custom progress must stay' "$upgrade_target/docs/coding-progress.md"
"$KIT_ROOT/scripts/validate_target.sh" "$upgrade_target" >/dev/null
AGENT_WORKFLOW_CODEGRAPH=yes AGENT_WORKFLOW_OPENDESIGN=yes "$KIT_ROOT/scripts/upgrade_workflow.sh" "$upgrade_target" --stack flutter > "$TMP_ROOT/upgrade-after-apply-dry-run.log"
if grep -q 'refresh .agent/config.json version metadata' "$TMP_ROOT/upgrade-after-apply-dry-run.log"; then
  echo "Upgrade should not refresh config metadata when version and enhancement fields are current." >&2
  exit 1
fi

echo "==> Verify workflow upgrade adds missing generated files"
mkdir -p "$upgrade_target/docs/test-cases"
printf '%s\n' 'local requirement test case must stay' > "$upgrade_target/docs/test-cases/REQ-LOCAL.md"
rm "$upgrade_target/docs/test-cases/README.md"
rm "$upgrade_target/docs/acceptance_simulator.md"
rm -rf "$upgrade_target/.agent"
rm "$upgrade_target/docs/process/failure-taxonomy.md"
rm "$upgrade_target/docs/reports/eval-report.md"
"$KIT_ROOT/scripts/upgrade_workflow.sh" "$upgrade_target" --stack flutter --apply >/dev/null
test -f "$upgrade_target/docs/acceptance_simulator.md"
test -f "$upgrade_target/.agent/state/current-task.json"
test -f "$upgrade_target/.agent/config.json"
test -f "$upgrade_target/.agent/traces/README.md"
test -f "$upgrade_target/.agent/traces/schema.json"
test -f "$upgrade_target/.agent/evals/README.md"
test -f "$upgrade_target/docs/process/failure-taxonomy.md"
test -f "$upgrade_target/docs/process/badcase-analysis.md"
test -f "$upgrade_target/docs/reports/eval-report.md"
test -f "$upgrade_target/docs/test-cases/README.md"
grep -q 'local requirement test case must stay' "$upgrade_target/docs/test-cases/REQ-LOCAL.md"
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
