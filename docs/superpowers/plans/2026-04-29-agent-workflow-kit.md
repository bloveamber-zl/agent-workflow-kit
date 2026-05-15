# Agent Workflow Kit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a standalone template and script project that can generate agent workflow files for generic, Flutter, Node, and Python projects.

**Architecture:** Keep shared workflow content in `templates/base`, stack-specific command values in `templates/stacks`, and orchestration in small Bash scripts. Generated target projects receive only `AGENTS.md`, `init.sh`, and docs state files.

**Tech Stack:** Bash, awk, perl, python3, Markdown, JSON.

---

### Task 1: Project Skeleton

**Files:**
- Create: `AGENTS.md`
- Create: `README.md`
- Create: `docs/usage.md`
- Create: `docs/template-variables.md`

- [x] Create concise project instructions.
- [x] Document supported stacks and generated files.
- [x] Document template variables.

### Task 2: Base Templates

**Files:**
- Create: `templates/base/AGENTS.md.template`
- Create: `templates/base/init.sh.template`
- Create: `templates/base/docs/index.md.template`
- Create: `templates/base/docs/coding-progress.md.template`
- Create: `templates/base/docs/feature_list.json.template`
- Create: `templates/base/docs/session-handoff.md.template`

- [x] Encode the long-running agent workflow.
- [x] Keep templates stack-agnostic.
- [x] Include completion, verification, and handoff rules.

### Task 3: Stack Configs

**Files:**
- Create: `templates/stacks/generic.yaml`
- Create: `templates/stacks/flutter.yaml`
- Create: `templates/stacks/node.yaml`
- Create: `templates/stacks/python.yaml`

- [x] Add flat YAML key-value files.
- [x] Keep stack configs limited to command differences and notes.

### Task 4: Scripts

**Files:**
- Create: `scripts/generate_workflow.sh`
- Create: `scripts/validate_target.sh`
- Create: `scripts/self_test.sh`

- [x] Generate files into target projects.
- [x] Refuse overwrite unless `--force` is set.
- [x] Validate shell syntax and JSON output.
- [x] Self-test all stacks in temporary projects.
