#!/usr/bin/env bash

set -euo pipefail

KIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_PATH=""
STACK="generic"
FORCE=0
PROJECT_NAME=""

usage() {
  cat <<'USAGE'
Usage:
  scripts/generate_workflow.sh <target-project-path> [--stack generic|flutter|node|python] [--project-name name] [--force]

Options:
  --stack         Select stack config. Default: generic
  --project-name  Override project name. Default: target directory name
  --force         Overwrite existing workflow files
  -h, --help      Show help
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --stack)
      STACK="${2:-}"
      shift 2
      ;;
    --project-name)
      PROJECT_NAME="${2:-}"
      shift 2
      ;;
    --force)
      FORCE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      if [ -n "$TARGET_PATH" ]; then
        echo "Only one target path is allowed." >&2
        exit 1
      fi
      TARGET_PATH="$1"
      shift
      ;;
  esac
done

if [ -z "$TARGET_PATH" ]; then
  usage >&2
  exit 1
fi

if [ ! -d "$TARGET_PATH" ]; then
  echo "Target project does not exist: $TARGET_PATH" >&2
  exit 1
fi

STACK_FILE="$KIT_ROOT/templates/stacks/$STACK.yaml"
if [ ! -f "$STACK_FILE" ]; then
  echo "Unsupported stack: $STACK" >&2
  echo "Available stacks:" >&2
  find "$KIT_ROOT/templates/stacks" -maxdepth 1 -name '*.yaml' -exec basename {} .yaml \; | sort >&2
  exit 1
fi

TARGET_ROOT="$(cd "$TARGET_PATH" && pwd)"
if [ -z "$PROJECT_NAME" ]; then
  PROJECT_NAME="$(basename "$TARGET_ROOT")"
fi
CURRENT_DATE="$(date +%F)"

yaml_value() {
  local key="$1"
  awk -v key="$key" '
    $0 ~ "^[[:space:]]*" key ":[[:space:]]*" {
      value = $0
      sub("^[[:space:]]*" key ":[[:space:]]*", "", value)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      if (value ~ /^'\''.*'\''$/ || value ~ /^".*"$/) {
        value = substr(value, 2, length(value) - 2)
      }
      print value
      exit
    }
  ' "$STACK_FILE"
}

shell_quote() {
  printf '%q' "$1"
}

STACK_NAME="$(yaml_value stack_name)"
PRIMARY_VERIFY_COMMAND="$(yaml_value primary_verify_command)"
STRICT_VERIFY_COMMAND="$(yaml_value strict_verify_command)"
TEST_COMMAND="$(yaml_value test_command)"
START_COMMAND="$(yaml_value start_command)"
DEPENDENCY_SYNC_COMMAND="$(yaml_value dependency_sync_command)"
BUILD_DOCS="$(yaml_value build_docs)"
LIGHTWEIGHT_VALIDATION_NOTE="$(yaml_value lightweight_validation_note)"

PRIMARY_VERIFY_COMMAND_SHELL="$(shell_quote "$PRIMARY_VERIFY_COMMAND")"
STRICT_VERIFY_COMMAND_SHELL="$(shell_quote "$STRICT_VERIFY_COMMAND")"
TEST_COMMAND_SHELL="$(shell_quote "$TEST_COMMAND")"
START_COMMAND_SHELL="$(shell_quote "$START_COMMAND")"
DEPENDENCY_SYNC_COMMAND_SHELL="$(shell_quote "$DEPENDENCY_SYNC_COMMAND")"

required_values=(
  STACK_NAME
  PRIMARY_VERIFY_COMMAND
  STRICT_VERIFY_COMMAND
  TEST_COMMAND
  START_COMMAND
  DEPENDENCY_SYNC_COMMAND
)

for name in "${required_values[@]}"; do
  if [ -z "${!name}" ]; then
    echo "Missing stack value: $name in $STACK_FILE" >&2
    exit 1
  fi
done

outputs=(
  "AGENTS.md"
  "init.sh"
  "docs/index.md"
  "docs/verification.md"
  "docs/process/verification.md"
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

if [ "$FORCE" -ne 1 ]; then
  conflicts=()
  for path in "${outputs[@]}"; do
    if [ -e "$TARGET_ROOT/$path" ]; then
      conflicts+=("$path")
    fi
  done

  if [ "${#conflicts[@]}" -gt 0 ]; then
    echo "Refusing to overwrite existing files in $TARGET_ROOT:" >&2
    printf '  %s\n' "${conflicts[@]}" >&2
    echo "Re-run with --force to overwrite these workflow files." >&2
    exit 1
  fi
fi

render_template() {
  local source="$1"
  local dest="$2"
  mkdir -p "$(dirname "$dest")"

  PROJECT_NAME="$PROJECT_NAME" \
  PROJECT_ROOT="$TARGET_ROOT" \
  STACK_NAME="$STACK_NAME" \
  CURRENT_DATE="$CURRENT_DATE" \
  PRIMARY_VERIFY_COMMAND="$PRIMARY_VERIFY_COMMAND" \
  STRICT_VERIFY_COMMAND="$STRICT_VERIFY_COMMAND" \
  TEST_COMMAND="$TEST_COMMAND" \
  START_COMMAND="$START_COMMAND" \
  DEPENDENCY_SYNC_COMMAND="$DEPENDENCY_SYNC_COMMAND" \
  BUILD_DOCS="$BUILD_DOCS" \
  LIGHTWEIGHT_VALIDATION_NOTE="$LIGHTWEIGHT_VALIDATION_NOTE" \
  PRIMARY_VERIFY_COMMAND_SHELL="$PRIMARY_VERIFY_COMMAND_SHELL" \
  STRICT_VERIFY_COMMAND_SHELL="$STRICT_VERIFY_COMMAND_SHELL" \
  TEST_COMMAND_SHELL="$TEST_COMMAND_SHELL" \
  START_COMMAND_SHELL="$START_COMMAND_SHELL" \
  DEPENDENCY_SYNC_COMMAND_SHELL="$DEPENDENCY_SYNC_COMMAND_SHELL" \
  perl -0pe '
    s/\{\{PROJECT_NAME\}\}/$ENV{PROJECT_NAME}/g;
    s/\{\{PROJECT_ROOT\}\}/$ENV{PROJECT_ROOT}/g;
    s/\{\{STACK_NAME\}\}/$ENV{STACK_NAME}/g;
    s/\{\{CURRENT_DATE\}\}/$ENV{CURRENT_DATE}/g;
    s/\{\{PRIMARY_VERIFY_COMMAND\}\}/$ENV{PRIMARY_VERIFY_COMMAND}/g;
    s/\{\{STRICT_VERIFY_COMMAND\}\}/$ENV{STRICT_VERIFY_COMMAND}/g;
    s/\{\{TEST_COMMAND\}\}/$ENV{TEST_COMMAND}/g;
    s/\{\{START_COMMAND\}\}/$ENV{START_COMMAND}/g;
    s/\{\{DEPENDENCY_SYNC_COMMAND\}\}/$ENV{DEPENDENCY_SYNC_COMMAND}/g;
    s/\{\{BUILD_DOCS\}\}/$ENV{BUILD_DOCS}/g;
    s/\{\{LIGHTWEIGHT_VALIDATION_NOTE\}\}/$ENV{LIGHTWEIGHT_VALIDATION_NOTE}/g;
    s/\{\{PRIMARY_VERIFY_COMMAND_SHELL\}\}/$ENV{PRIMARY_VERIFY_COMMAND_SHELL}/g;
    s/\{\{STRICT_VERIFY_COMMAND_SHELL\}\}/$ENV{STRICT_VERIFY_COMMAND_SHELL}/g;
    s/\{\{TEST_COMMAND_SHELL\}\}/$ENV{TEST_COMMAND_SHELL}/g;
    s/\{\{START_COMMAND_SHELL\}\}/$ENV{START_COMMAND_SHELL}/g;
    s/\{\{DEPENDENCY_SYNC_COMMAND_SHELL\}\}/$ENV{DEPENDENCY_SYNC_COMMAND_SHELL}/g;
  ' "$source" > "$dest"
}

render_template "$KIT_ROOT/templates/base/AGENTS.md.template" "$TARGET_ROOT/AGENTS.md"
render_template "$KIT_ROOT/templates/base/init.sh.template" "$TARGET_ROOT/init.sh"
render_template "$KIT_ROOT/templates/base/docs/index.md.template" "$TARGET_ROOT/docs/index.md"
render_template "$KIT_ROOT/templates/base/docs/verification.md.template" "$TARGET_ROOT/docs/verification.md"
render_template "$KIT_ROOT/templates/base/docs/process/verification.md.template" "$TARGET_ROOT/docs/process/verification.md"
render_template "$KIT_ROOT/templates/base/docs/acceptance_simulator.md.template" "$TARGET_ROOT/docs/acceptance_simulator.md"
render_template "$KIT_ROOT/templates/base/docs/coding-progress.md.template" "$TARGET_ROOT/docs/coding-progress.md"
render_template "$KIT_ROOT/templates/base/docs/feature_list.json.template" "$TARGET_ROOT/docs/feature_list.json"
render_template "$KIT_ROOT/templates/base/docs/session-handoff.md.template" "$TARGET_ROOT/docs/session-handoff.md"
render_template "$KIT_ROOT/templates/base/docs/project/structure/overview.md.template" "$TARGET_ROOT/docs/project/structure/overview.md"
render_template "$KIT_ROOT/templates/base/docs/project/structure/architecture.md.template" "$TARGET_ROOT/docs/project/structure/architecture.md"
render_template "$KIT_ROOT/templates/base/docs/project/constraints.md.template" "$TARGET_ROOT/docs/project/constraints.md"
render_template "$KIT_ROOT/templates/base/docs/project/frontend.md.template" "$TARGET_ROOT/docs/project/frontend.md"
render_template "$KIT_ROOT/templates/base/docs/project/features/overview.md.template" "$TARGET_ROOT/docs/project/features/overview.md"
render_template "$KIT_ROOT/templates/base/docs/requirements/parsed-requirements.md.template" "$TARGET_ROOT/docs/requirements/parsed-requirements.md"
render_template "$KIT_ROOT/templates/base/docs/requirements/open-questions.md.template" "$TARGET_ROOT/docs/requirements/open-questions.md"
render_template "$KIT_ROOT/templates/base/docs/requirements/traceability.md.template" "$TARGET_ROOT/docs/requirements/traceability.md"
render_template "$KIT_ROOT/templates/base/docs/design/index.md.template" "$TARGET_ROOT/docs/design/index.md"
render_template "$KIT_ROOT/templates/base/docs/design/workflow-bootstrap.md.template" "$TARGET_ROOT/docs/design/workflow-bootstrap.md"
render_template "$KIT_ROOT/templates/base/docs/exec-plans/active/index.md.template" "$TARGET_ROOT/docs/exec-plans/active/index.md"
render_template "$KIT_ROOT/templates/base/docs/exec-plans/active/workflow-bootstrap.md.template" "$TARGET_ROOT/docs/exec-plans/active/workflow-bootstrap.md"
render_template "$KIT_ROOT/templates/base/docs/exec-plans/completed/index.md.template" "$TARGET_ROOT/docs/exec-plans/completed/index.md"
render_template "$KIT_ROOT/templates/base/docs/exec-plans/tech-debt-tracker.md.template" "$TARGET_ROOT/docs/exec-plans/tech-debt-tracker.md"
render_template "$KIT_ROOT/templates/base/docs/reports/test-report.md.template" "$TARGET_ROOT/docs/reports/test-report.md"
render_template "$KIT_ROOT/templates/base/scripts/acceptance_simulator.sh.template" "$TARGET_ROOT/scripts/acceptance_simulator.sh"

chmod +x "$TARGET_ROOT/init.sh"
chmod +x "$TARGET_ROOT/scripts/acceptance_simulator.sh"

echo "Generated agent workflow for $PROJECT_NAME"
echo "Target: $TARGET_ROOT"
echo "Stack: $STACK_NAME"
echo
echo "Next steps:"
echo "  cd $TARGET_ROOT"
echo "  ./init.sh"
