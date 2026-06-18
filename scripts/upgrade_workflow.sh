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

resolve_patrol_enabled() {
  if [ "$STACK" != "flutter" ]; then
    return 1
  fi

  local mode="${AGENT_WORKFLOW_PATROL:-ask}"
  case "$mode" in
    yes|true|1)
      return 0
      ;;
    no|false|0)
      return 1
      ;;
    ask|"")
      if [ -t 0 ] && [ -t 1 ]; then
        printf '%s\n' "检测到 Flutter 工作流。是否生成或刷新 Patrol 验收支持文件？[y/N]"
        local answer
        read -r answer || answer=""
        case "$answer" in
          y|Y|yes|YES)
            return 0
            ;;
        esac
      fi
      return 1
      ;;
    *)
      echo "Invalid AGENT_WORKFLOW_PATROL value: $mode" >&2
      echo "Allowed values: ask, yes, no" >&2
      exit 1
      ;;
  esac
}

resolve_codegraph_enabled() {
  local mode="${AGENT_WORKFLOW_CODEGRAPH:-ask}"
  case "$mode" in
    yes|true|1)
      return 0
      ;;
    no|false|0)
      return 1
      ;;
    ask|"")
      if [ -t 0 ] && [ -t 1 ]; then
        printf '%s\n' "是否生成或刷新 CodeGraph 可选增强配置（安装/索引说明，不自动安装）？[y/N]"
        local answer
        read -r answer || answer=""
        case "$answer" in
          y|Y|yes|YES)
            return 0
            ;;
        esac
      fi
      return 1
      ;;
    *)
      echo "Invalid AGENT_WORKFLOW_CODEGRAPH value: $mode" >&2
      echo "Allowed values: ask, yes, no" >&2
      exit 1
      ;;
  esac
}

resolve_opendesign_enabled() {
  local mode="${AGENT_WORKFLOW_OPENDESIGN:-ask}"
  case "$mode" in
    yes|true|1)
      return 0
      ;;
    no|false|0)
      return 1
      ;;
    ask|"")
      if [ -t 0 ] && [ -t 1 ]; then
        printf '%s\n' "是否生成或刷新 Open Design 可选增强说明（仅用户明确要求时使用）？[y/N]"
        local answer
        read -r answer || answer=""
        case "$answer" in
          y|Y|yes|YES)
            return 0
            ;;
        esac
      fi
      return 1
      ;;
    *)
      echo "Invalid AGENT_WORKFLOW_OPENDESIGN value: $mode" >&2
      echo "Allowed values: ask, yes, no" >&2
      exit 1
      ;;
  esac
}

PATROL_ENV=no
if resolve_patrol_enabled; then
  PATROL_ENV=yes
fi

CODEGRAPH_ENV=no
if resolve_codegraph_enabled; then
  CODEGRAPH_ENV=yes
fi

OPENDESIGN_ENV=no
if resolve_opendesign_enabled; then
  OPENDESIGN_ENV=yes
fi

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/agent-workflow-upgrade.XXXXXX")"
cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

generated="$TMP_ROOT/generated"
mkdir -p "$generated"
AGENT_WORKFLOW_PATROL="$PATROL_ENV" AGENT_WORKFLOW_CODEGRAPH="$CODEGRAPH_ENV" AGENT_WORKFLOW_OPENDESIGN="$OPENDESIGN_ENV" "$KIT_ROOT/scripts/generate_workflow.sh" "$generated" --stack "$STACK" --project-name "$PROJECT_NAME" --project-root "$TARGET_ROOT" >/dev/null

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

if [ "$PATROL_ENV" = "yes" ]; then
  update_files+=(
    "docs/testing/patrol.md"
    "scripts/patrol_acceptance.sh"
  )
fi

if [ "$CODEGRAPH_ENV" = "yes" ]; then
  update_files+=(
    "docs/tools/codegraph.md"
  )
fi

if [ "$OPENDESIGN_ENV" = "yes" ]; then
  update_files+=(
    "docs/tools/opendesign.md"
  )
fi

# State and project-adapted files are only added if missing. Existing content
# may contain local requirements, plans, project constraints, or test evidence.
add_only_files=(
  ".agent/state/current-task.json"
  ".agent/config.json"
  ".agent/traces/README.md"
  ".agent/traces/schema.json"
  ".agent/evals/README.md"
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
  "docs/process/badcase-analysis.md"
  "docs/design/index.md"
  "docs/design/workflow-bootstrap.md"
  "docs/exec-plans/active/index.md"
  "docs/exec-plans/active/workflow-bootstrap.md"
  "docs/exec-plans/completed/index.md"
  "docs/exec-plans/tech-debt-tracker.md"
  "docs/reports/eval-report.md"
  "docs/reports/test-report.md"
)

workflow_ignore_paths=(
  "/.agent/"
  "/AGENTS.md"
  "/init.sh"
  "/docs/index.md"
  "/docs/verification.md"
  "/docs/acceptance_simulator.md"
  "/docs/coding-progress.md"
  "/docs/feature_list.json"
  "/docs/session-handoff.md"
  "/docs/design/"
  "/docs/exec-plans/"
  "/docs/process/"
  "/docs/project/"
  "/docs/reports/"
  "/docs/requirements/"
  "/docs/testing/"
  "/docs/tools/"
  "/scripts/acceptance_simulator.sh"
  "/scripts/patrol_acceptance.sh"
)

write_workflow_gitignore_block() {
  printf '%s\n' "# BEGIN agent-workflow-kit"
  printf '%s\n' "# Generated agent workflow files"
  printf '%s\n' "${workflow_ignore_paths[@]}"
  printf '%s\n' "# END agent-workflow-kit"
}

render_workflow_gitignore() {
  local gitignore="$TARGET_ROOT/.gitignore"
  local marker_begin="# BEGIN agent-workflow-kit"
  local marker_end="# END agent-workflow-kit"

  if [ -f "$gitignore" ] && grep -Fq "$marker_begin" "$gitignore"; then
    local without_block
    without_block="$(mktemp)"
    awk -v begin="$marker_begin" -v end="$marker_end" '
      $0 == begin {
        while ((getline line) > 0 && line != end) {}
        next
      }
      { print }
    ' "$gitignore" > "$without_block"
    cat "$without_block"
    if [ -s "$without_block" ] && [ "$(tail -c 1 "$without_block" | wc -l | tr -d ' ')" -eq 0 ]; then
      printf '\n'
    fi
    if [ -s "$without_block" ]; then
      printf '\n'
    fi
    rm -f "$without_block"
    write_workflow_gitignore_block
    return
  fi

  if [ -s "$gitignore" ]; then
    cat "$gitignore"
    if [ "$(tail -c 1 "$gitignore" | wc -l | tr -d ' ')" -eq 0 ]; then
      printf '\n'
    fi
    printf '\n'
  fi

  write_workflow_gitignore_block
}

gitignore_workflow_block_current() {
  local gitignore="$TARGET_ROOT/.gitignore"
  local expected
  local current

  if [ ! -f "$gitignore" ]; then
    return 1
  fi

  expected="$(mktemp)"
  current="$(mktemp)"
  render_workflow_gitignore > "$expected"
  cat "$gitignore" > "$current"
  if cmp -s "$expected" "$current"; then
    rm -f "$expected" "$current"
    return 0
  fi
  rm -f "$expected" "$current"
  return 1
}

upsert_workflow_gitignore() {
  local gitignore="$TARGET_ROOT/.gitignore"
  local tmp

  tmp="$(mktemp)"
  render_workflow_gitignore > "$tmp"
  cat "$tmp" > "$gitignore"
  rm -f "$tmp"
}

merge_config_version_metadata() {
  local source="$generated/.agent/config.json"
  local dest="$TARGET_ROOT/.agent/config.json"

  if [ ! -f "$source" ] || [ ! -f "$dest" ]; then
    return
  fi

  if [ "$APPLY" -eq 1 ]; then
    python3 - "$source" "$dest" <<'PY'
import json
import sys

source_path, dest_path = sys.argv[1:3]
with open(source_path, encoding="utf-8") as f:
    source = json.load(f)
with open(dest_path, encoding="utf-8") as f:
    dest = json.load(f)

for key in ("workflow_version", "template_revision", "kit_version", "enhancements"):
    if key in source:
        dest[key] = source[key]

with open(dest_path, "w", encoding="utf-8") as f:
    json.dump(dest, f, ensure_ascii=False, indent=2)
    f.write("\n")
PY
  fi
}

config_version_metadata_current() {
  local source="$generated/.agent/config.json"
  local dest="$TARGET_ROOT/.agent/config.json"

  if [ ! -f "$source" ] || [ ! -f "$dest" ]; then
    return 1
  fi

  python3 - "$source" "$dest" <<'PY'
import json
import sys

source_path, dest_path = sys.argv[1:3]
with open(source_path, encoding="utf-8") as f:
    source = json.load(f)
with open(dest_path, encoding="utf-8") as f:
    dest = json.load(f)

keys = ("workflow_version", "template_revision", "kit_version", "enhancements")
if all(dest.get(key) == source.get(key) for key in keys):
    sys.exit(0)
sys.exit(1)
PY
}

mode_label="DRY-RUN"
if [ "$APPLY" -eq 1 ]; then
  mode_label="APPLY"
fi

echo "==> $mode_label workflow upgrade"
echo "Target: $TARGET_ROOT"
echo "Stack: $STACK"
echo "Patrol: $PATROL_ENV"
echo "CodeGraph: $CODEGRAPH_ENV"
echo "Open Design: $OPENDESIGN_ENV"

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

if [ -f "$TARGET_ROOT/.agent/config.json" ]; then
  if ! config_version_metadata_current; then
    echo "  refresh .agent/config.json version metadata"
    merge_config_version_metadata
    changed=1
  else
    echo "  unchanged .agent/config.json version metadata"
  fi
fi

if ! gitignore_workflow_block_current; then
  echo "  update .gitignore workflow ignore block"
  if [ "$APPLY" -eq 1 ]; then
    upsert_workflow_gitignore
  fi
  changed=1
else
  echo "  unchanged .gitignore workflow ignore block"
fi

if [ "$changed" -eq 0 ]; then
  echo "No workflow changes needed."
elif [ "$APPLY" -eq 0 ]; then
  echo "Dry-run only. Re-run with --apply to write these changes."
fi

if [ "$APPLY" -eq 1 ]; then
  "$KIT_ROOT/scripts/validate_target.sh" "$TARGET_ROOT"
fi
