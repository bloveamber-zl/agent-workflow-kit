#!/usr/bin/env bash

set -euo pipefail

KIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL_NAME="agent-workflow"
SOURCE_DIR="$KIT_ROOT/skills/$SKILL_NAME"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
DEST_PARENT="$CODEX_HOME/skills"
DEST_DIR="$DEST_PARENT/$SKILL_NAME"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/agent-workflow-skill.XXXXXX")"

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

if [ ! -f "$SOURCE_DIR/SKILL.md" ]; then
  echo "Missing skill source: $SOURCE_DIR/SKILL.md" >&2
  exit 1
fi

if [ ! -f "$KIT_ROOT/scripts/generate_workflow.sh" ]; then
  echo "Missing generator script: $KIT_ROOT/scripts/generate_workflow.sh" >&2
  exit 1
fi

if [ "$DEST_DIR" = "$SOURCE_DIR" ]; then
  echo "Refusing to install over source directory: $SOURCE_DIR" >&2
  exit 1
fi

mkdir -p "$DEST_PARENT"
mkdir -p "$TMP_ROOT/$SKILL_NAME"

cp -R "$SOURCE_DIR/." "$TMP_ROOT/$SKILL_NAME/"

KIT_ROOT_FOR_SKILL="$KIT_ROOT" perl -0pi -e 's/\Q{{AGENT_WORKFLOW_KIT_ROOT}}\E/$ENV{KIT_ROOT_FOR_SKILL}/g' "$TMP_ROOT/$SKILL_NAME/SKILL.md"

rm -rf "$DEST_DIR"
mv "$TMP_ROOT/$SKILL_NAME" "$DEST_DIR"

echo "Installed Codex skill: $SKILL_NAME"
echo "Destination: $DEST_DIR"
