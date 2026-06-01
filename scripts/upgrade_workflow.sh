#!/usr/bin/env bash

set -euo pipefail

KIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_PATH=""
STACK="auto"
APPLY=0

usage() {
  cat <<'USAGE'
Usage:
  scripts/upgrade_workflow.sh <target-project-path> [--stack auto|generic|flutter|node|python] [--apply]

Options:
  --stack   Select stack config. Default: auto
  --apply   Write changes. Without this flag, only print the planned changes.
  -h, --help
            Show help
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --stack)
      STACK="${2:-}"
      shift 2
      ;;
    --apply)
      APPLY=1
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

TARGET_ROOT="$(cd "$TARGET_PATH" && pwd)"
PROJECT_NAME="$(basename "$TARGET_ROOT")"

detect_stack() {
  if [ -f "$TARGET_ROOT/pubspec.yaml" ]; then
    printf '%s\n' flutter
  elif [ -f "$TARGET_ROOT/package.json" ]; then
    printf '%s\n' node
  elif [ -f "$TARGET_ROOT/pyproject.toml" ] || [ -f "$TARGET_ROOT/requirements.txt" ] || [ -f "$TARGET_ROOT/setup.py" ]; then
    printf '%s\n' python
  else
    printf '%s\n' generic
  fi
}

if [ "$STACK" = "auto" ]; then
  STACK="$(detect_stack)"
fi

STACK_FILE="$KIT_ROOT/templates/stacks/$STACK.yaml"
if [ ! -f "$STACK_FILE" ]; then
  echo "Unsupported stack: $STACK" >&2
  echo "Available stacks:" >&2
  find "$KIT_ROOT/templates/stacks" -maxdepth 1 -name '*.yaml' -exec basename {} .yaml \; | sort >&2
  exit 1
fi

if [ ! -f "$TARGET_ROOT/AGENTS.md" ] || [ ! -f "$TARGET_ROOT/init.sh" ] || [ ! -f "$TARGET_ROOT/docs/index.md" ]; then
  echo "Target does not look like an installed workflow project: $TARGET_ROOT" >&2
  echo "Expected AGENTS.md, init.sh, and docs/index.md." >&2
  exit 1
fi

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/agent-workflow-upgrade.XXXXXX")"
cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

generated="$TMP_ROOT/generated"
mkdir -p "$generated"
"$KIT_ROOT/scripts/generate_workflow.sh" "$generated" --stack "$STACK" --project-name "$PROJECT_NAME" >/dev/null

# Files in this list are common workflow entrypoints. In semi-automatic mode
# they can be refreshed from templates because they should not carry project
# progress, requirement state, or implementation evidence.
update_files=(
  "AGENTS.md"
  "init.sh"
  "docs/index.md"
  "docs/verification.md"
  "docs/process/verification.md"
  "docs/process/failure-taxonomy.md"
  "docs/acceptance_simulator.md"
  "scripts/acceptance_simulator.sh"
)

# State and project-adapted files are only added if missing. Existing content
# may contain local requirements, plans, project constraints, or test evidence.
add_only_files=(
  ".agent/state/current-task.json"
  ".agent/traces/README.md"
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
)

mode_label="DRY-RUN"
if [ "$APPLY" -eq 1 ]; then
  mode_label="APPLY"
fi

echo "==> $mode_label workflow upgrade"
echo "Target: $TARGET_ROOT"
echo "Stack: $STACK"

changed=0

copy_file() {
  local path="$1"
  local source="$generated/$path"
  local dest="$TARGET_ROOT/$path"

  if [ ! -f "$source" ]; then
    echo "missing template output $path" >&2
    exit 1
  fi

  if [ "$APPLY" -eq 1 ]; then
    mkdir -p "$(dirname "$dest")"
    cp "$source" "$dest"
    case "$path" in
      init.sh|scripts/*.sh)
        chmod +x "$dest"
        ;;
    esac
  fi
}

for path in "${update_files[@]}"; do
  if [ ! -f "$TARGET_ROOT/$path" ]; then
    echo "  add $path"
    copy_file "$path"
    changed=1
  elif ! cmp -s "$generated/$path" "$TARGET_ROOT/$path"; then
    echo "  update $path"
    copy_file "$path"
    changed=1
  else
    echo "  unchanged $path"
  fi
done

for path in "${add_only_files[@]}"; do
  if [ ! -f "$TARGET_ROOT/$path" ]; then
    echo "  add missing $path"
    copy_file "$path"
    changed=1
  else
    echo "  keep existing $path"
  fi
done

if [ "$changed" -eq 0 ]; then
  echo "No workflow changes needed."
elif [ "$APPLY" -eq 0 ]; then
  echo "Dry-run only. Re-run with --apply to write these changes."
fi

if [ "$APPLY" -eq 1 ]; then
  "$KIT_ROOT/scripts/validate_target.sh" "$TARGET_ROOT"
fi
