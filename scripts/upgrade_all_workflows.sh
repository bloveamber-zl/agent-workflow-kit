#!/usr/bin/env bash

set -euo pipefail

KIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT_PATH="${HOME}/project"
STACK="auto"
APPLY=0

usage() {
  cat <<'USAGE'
Usage:
  scripts/upgrade_all_workflows.sh [projects-root] [--stack auto|generic|flutter|node|python] [--apply]

Options:
  projects-root
            Directory containing project folders. Default: ~/project
  --stack   Select one stack for all projects. Default: auto
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
      ROOT_PATH="$1"
      shift
      ;;
  esac
done

if [ ! -d "$ROOT_PATH" ]; then
  echo "Projects root does not exist: $ROOT_PATH" >&2
  exit 1
fi

ROOT_PATH="$(cd "$ROOT_PATH" && pwd)"
mode_label="DRY-RUN"
if [ "$APPLY" -eq 1 ]; then
  mode_label="APPLY"
fi

echo "==> $mode_label all workflow upgrades"
echo "Projects root: $ROOT_PATH"
echo "Stack: $STACK"

found=0
while IFS= read -r -d '' project; do
  if [ -f "$project/AGENTS.md" ] && [ -f "$project/init.sh" ] && [ -f "$project/docs/index.md" ]; then
    found=1
    echo
    echo "==> Project: $project"
    args=("$KIT_ROOT/scripts/upgrade_workflow.sh" "$project" --stack "$STACK")
    if [ "$APPLY" -eq 1 ]; then
      args+=(--apply)
    fi
    "${args[@]}"
  fi
done < <(find "$ROOT_PATH" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)

if [ "$found" -eq 0 ]; then
  echo "No installed workflow projects found."
fi
