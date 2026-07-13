#!/usr/bin/env bash

set -euo pipefail

KIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_PATH=""
DRY_RUN=0
REPORT_JSON=""

usage() {
  cat <<'USAGE'
Usage:
  scripts/recon_project.sh <target-project-path> [--dry-run] [--report-json /path/to/report.json]

Options:
  --dry-run      Analyze only; do not write docs
  --report-json  Override the generated report path
  -h, --help     Show help
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --report-json)
      REPORT_JSON="${2:-}"
      shift 2
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

args=(--target "$TARGET_ROOT")
if [ "$DRY_RUN" -eq 1 ]; then
  args+=(--dry-run)
fi
if [ -n "$REPORT_JSON" ]; then
  args+=(--report-json "$REPORT_JSON")
fi

python3 "$KIT_ROOT/scripts/recon_project.py" "${args[@]}"
