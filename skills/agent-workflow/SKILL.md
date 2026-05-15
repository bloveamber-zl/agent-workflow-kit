---
name: agent-workflow
description: Use when a project needs Codex agent workflow files generated, installed, validated, accepted, or improved using the local agent-workflow-kit; includes AGENTS.md, init.sh, requirement intake, project understanding docs, design docs, exec plans, traceability, verification/acceptance files, stack detection, safe non-overwrite generation, and target workflow optimization.
---

# Agent Workflow

## Purpose

Use this skill to land the reusable Codex workflow from `agent-workflow-kit` into another project, or to tighten an existing workflow without losing project-specific rules.

The generated workflow is demand-driven:

```text
requirements intake -> project reconnaissance -> design doc -> exec plan -> user approval -> implementation -> requirement-based verification -> fix/retest loop -> status handoff
```

Default kit root after installation:

```text
{{AGENT_WORKFLOW_KIT_ROOT}}
```

If that path is unavailable, check `AGENT_WORKFLOW_KIT_ROOT`, then ask the user for the kit path. Do not guess a private path.

## Workflow

1. Confirm the target project:
   - Default to the current working directory.
   - If the user named a project path, use that path.
   - Run `pwd` and inspect files before changing anything.

2. Locate the kit:
   - Prefer the installed default path above.
   - Verify both scripts exist:
     - `scripts/generate_workflow.sh`
     - `scripts/validate_target.sh`
     - `scripts/install_codex_skill.sh`

3. Decide the operation:
   - If `AGENTS.md`, `init.sh`, `docs/feature_list.json`, `docs/verification.md`, `docs/process/verification.md`, `docs/acceptance_simulator.md`, `docs/project/structure/overview.md`, `docs/project/features/overview.md`, `docs/requirements/parsed-requirements.md`, `docs/design/index.md`, `docs/exec-plans/active/index.md`, `docs/reports/test-report.md`, or `scripts/acceptance_simulator.sh` is missing, generate the workflow for a new target or optimize the existing workflow in place.
   - If workflow files already exist, optimize in place after reading them.
   - Never use `--force` unless the user explicitly asks to overwrite generated workflow files.

4. Infer stack for generation:
   - `pubspec.yaml` -> `flutter`
   - `package.json` -> `node`
   - `pyproject.toml`, `requirements.txt`, or `setup.py` -> `python`
   - Otherwise -> `generic`

5. Generate when safe:

```bash
"/path/to/agent-workflow-kit/scripts/generate_workflow.sh" "/path/to/target" --stack flutter
```

Replace paths and stack with the actual values. If generation stops because files already exist, switch to the optimization workflow unless the user requested `--force`.

6. Optimize existing workflow:
   - Read current `AGENTS.md`, `init.sh`, `docs/index.md`, `docs/verification.md`, `docs/process/verification.md`, `docs/acceptance_simulator.md`, `docs/coding-progress.md`, `docs/feature_list.json`, `docs/session-handoff.md`, `docs/project/*`, `docs/requirements/*`, `docs/design/index.md`, `docs/exec-plans/active/index.md`, `docs/exec-plans/tech-debt-tracker.md`, `docs/reports/test-report.md`, and `scripts/acceptance_simulator.sh` when present.
   - Preserve project-specific instructions, build notes, private constraints, and verification commands.
   - Keep common workflow guidance generic; do not hard-code one business project's rules into reusable templates.
   - Prefer narrow edits: fix missing files, unresolved placeholders, stale commands, invalid JSON, weak verification notes, missing acceptance guidance, missing requirement traceability, missing project constraints, or missing active plan status.
   - Keep `docs/feature_list.json` as a project-level requirement index only; detailed steps belong in `docs/exec-plans/active/*.md`.
   - Keep `docs/coding-progress.md` as a session-level progress log only; full plans and evidence belong in active plans, traceability, and test reports.
   - Put project-specific rules and limitations in `docs/project/constraints.md`; only summarize the most critical hard rules in `AGENTS.md`.
   - Ensure `docs/project/constraints.md` includes the coding convention that new methods and variables should have comments explaining purpose or business meaning, while simple local temporaries may omit comments when readability is clear.

7. Validate:

```bash
"/path/to/agent-workflow-kit/scripts/validate_target.sh" "/path/to/target"
```

For generated or modified targets, run validation and report the result. Do not run full builds, signing, publishing, or expensive Xcode builds unless explicitly requested.

## Updating This Skill

When `agent-workflow-kit` changes and the installed skill should follow it:

1. Update the source skill in the kit:

```text
skills/agent-workflow/SKILL.md
```

2. Keep the source skill generic. Do not hard-code the kit root placeholder in the source; the install script fills it in.

3. Reinstall the skill:

```bash
scripts/install_codex_skill.sh
```

4. Confirm the installed copy exists and points at the current kit root:

```bash
grep -F "$(pwd)" ~/.codex/skills/agent-workflow/SKILL.md
```

The grep command should print the installed kit root line.

## Safety Rules

- Check `git status --short` in the target when it is a Git repo.
- Do not overwrite user edits or existing workflow files by default.
- Do not edit secrets, account values, or private machine paths into templates.
- When modifying JSON, keep it valid and rerun validation.
- If validation fails, fix the workflow issue or record the blocker clearly.
- Do not preserve original Word/PDF requirement files unless the user explicitly asks; keep structured requirements in `docs/requirements/parsed-requirements.md`.
- Do not start implementation from a new requirement until requirements, project adaptation, design doc, and exec plan have been confirmed when confirmation is needed.

## Done Criteria

Report:

- target path
- chosen stack
- generated or optimized files
- validation command and outcome
- acceptance command outcome when acceptance was required
- requirement/design/plan files created or updated
- traceability and test-report status
- any skipped step and why
