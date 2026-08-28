---
name: agent-workflow
description: Use when a project needs Codex agent workflow files generated, installed, validated, accepted, or improved using the local agent-workflow-kit; includes AGENTS.md, init.sh, requirement intake, project understanding docs, design docs, exec plans, traceability, verification/acceptance files, stack detection, safe non-overwrite generation, and target workflow optimization.
---

# Agent Workflow

## Purpose

Use this skill to land the reusable Codex workflow from `agent-workflow-kit` into another project, tighten an existing workflow without losing project-specific rules, or perform a deep project scan that backfills `docs/project/*`.

The generated workflow is demand-driven:

```text
requirements intake -> project reconnaissance -> design doc -> exec plan -> user approval -> implementation -> requirement-based verification -> fix/retest loop -> status handoff
```

Current generated targets use Workflow V2 metadata:

```text
.agent/config.json -> workflow version, template revision, kit version, stack, trace and overwrite policy
.agent/traces/schema.json -> node-level Runtime trace schema
.agent/evals/README.md -> target-level eval guidance
docs/process/badcase-analysis.md -> Agent-chain badcase workflow
docs/reports/eval-report.md -> eval and badcase regression evidence
docs/process/verification.md -> L0-L4 acceptance routing, test-case self-validation and evidence rules
docs/test-cases/README.md -> opt-in requirement test-case workflow and completion gates
scripts/acceptance_simulator.sh -> local/simulator acceptance with evidence.json
docs/platforms/harmonyos-dependency-matrix.md -> optional Flutter-OH dependency compatibility ledger
scripts/harmonyos_acceptance.sh -> optional HarmonyOS build/run/install evidence
```

`AGENTS.md` is intentionally a slim entry and routing layer. Keep detailed document maps, verification policy, failure taxonomy, badcase workflow, project constraints, execution plans and evidence in `docs/`; do not expand `AGENTS.md` back into a full handbook.

The kit also includes a local lightweight Runtime:

```bash
python3 -m runtime.cli run "给这个项目生成 agent workflow" --target /path/to/project
```

The Runtime routes natural-language requests, detects project stack and workflow state, calls the existing scripts, validates the target, and writes trace files. Use the Runtime when the user asks for natural-language initialization or when intent routing/trace evidence is useful. Use the lower-level scripts when the user gives exact stack/path details or wants a deterministic command.

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
     - `scripts/recon_project.sh`
     - `scripts/validate_target.sh`
     - `scripts/install_codex_skill.sh`
     - `scripts/upgrade_workflow.sh`
     - `scripts/upgrade_all_workflows.sh`
     - `scripts/run_eval.sh`
   - If using Runtime, verify `runtime/cli.py` exists.

3. Decide the operation:
   - If the user explicitly asks for test cases, enable `test_case_mode` only for the current requirement. 默认关闭且不主动提醒；do not enable or suggest it based only on risk level.
   - Choose `pre_implementation` unless the user says the feature is already implemented; then choose `post_implementation`.
   - If the user asks to "进行项目深度扫描并回填", "项目深度扫描", "扫描当前项目并补全文档", or equivalent, run the project reconnaissance path.
   - If `.agent/state/current-task.json`, `.agent/config.json`, `.agent/traces/README.md`, `.agent/traces/schema.json`, `.agent/evals/README.md`, `AGENTS.md`, `init.sh`, `docs/feature_list.json`, `docs/verification.md`, `docs/process/verification.md`, `docs/process/failure-taxonomy.md`, `docs/process/badcase-analysis.md`, `docs/acceptance_simulator.md`, `docs/project/structure/overview.md`, `docs/project/features/overview.md`, `docs/requirements/parsed-requirements.md`, `docs/design/index.md`, `docs/exec-plans/active/index.md`, `docs/reports/eval-report.md`, `docs/reports/test-report.md`, or `scripts/acceptance_simulator.sh` is missing, generate the workflow for a new target or optimize the existing workflow in place.
   - If workflow files already exist, optimize in place after reading them.
   - Never use `--force` unless the user explicitly asks to overwrite generated workflow files.

4. Infer stack for generation:
   - `pubspec.yaml` -> `flutter`
   - `package.json` -> `node`
   - `pyproject.toml`, `requirements.txt`, or `setup.py` -> `python`
   - Otherwise -> `generic`
   - Each stack selects common, language and framework rule fragments from `templates/rules/` and merges them into the existing target `docs/project/constraints.md`. Do not create a separate target rules directory or copy unrelated stack rules.

5. Generate when safe:

```bash
"/path/to/agent-workflow-kit/scripts/generate_workflow.sh" "/path/to/target" --stack flutter
```

Replace paths and stack with the actual values. If generation stops because files already exist, switch to the optimization workflow unless the user requested `--force`.

For Flutter targets, generation may ask whether to generate Patrol acceptance support. Use the interactive default when working directly with the user. In non-interactive automation, set the environment explicitly:

```bash
AGENT_WORKFLOW_PATROL=ask "/path/to/agent-workflow-kit/scripts/generate_workflow.sh" "/path/to/target" --stack flutter
AGENT_WORKFLOW_PATROL=yes "/path/to/agent-workflow-kit/scripts/generate_workflow.sh" "/path/to/target" --stack flutter
AGENT_WORKFLOW_PATROL=no "/path/to/agent-workflow-kit/scripts/generate_workflow.sh" "/path/to/target" --stack flutter
```

`yes` generates `docs/testing/patrol.md` and `scripts/patrol_acceptance.sh`. It does not silently install dependencies or edit native project settings; the target project must still pass the Patrol setup checks recorded in the generated docs.

For Flutter targets, generation may also ask whether to generate HarmonyOS/Flutter-OH dependency adaptation support. In non-interactive automation, set it explicitly:

```bash
AGENT_WORKFLOW_HARMONYOS=ask "/path/to/agent-workflow-kit/scripts/generate_workflow.sh" "/path/to/target" --stack flutter
AGENT_WORKFLOW_HARMONYOS=yes "/path/to/agent-workflow-kit/scripts/generate_workflow.sh" "/path/to/target" --stack flutter
AGENT_WORKFLOW_HARMONYOS=no "/path/to/agent-workflow-kit/scripts/generate_workflow.sh" "/path/to/target" --stack flutter
```

`yes` generates the HarmonyOS platform guide, dependency ledger, testing guide and `scripts/harmonyos_acceptance.sh`. It does not install Flutter-OH, sign a HAP, infer private SDK paths, or claim plugin compatibility. For each affected native plugin, the target project must record the compatible branch/tag, `ohos` implementation, build result and real-device critical-path evidence. Maintain a Fork in a traceable repository, never by editing `pub-cache`.

For Flutter targets, generation may also ask whether to enable the optional Flutter product-project style analyzed from the team's existing apps. In non-interactive automation, set it explicitly:

```bash
AGENT_WORKFLOW_FLUTTER_STYLE=ask "/path/to/agent-workflow-kit/scripts/generate_workflow.sh" "/path/to/target" --stack flutter
AGENT_WORKFLOW_FLUTTER_STYLE=yes "/path/to/agent-workflow-kit/scripts/generate_workflow.sh" "/path/to/target" --stack flutter
AGENT_WORKFLOW_FLUTTER_STYLE=no "/path/to/agent-workflow-kit/scripts/generate_workflow.sh" "/path/to/target" --stack flutter
```

`yes` generates `docs/project/flutter-product-style.md` and records `enhancements.flutter_product_style: true`. When enabled, read that document before Flutter coding, refactoring or review. It standardizes the optional directory, GetX Logic/State/View, repository/http, model, localization, color and asset conventions. String obfuscation, XOR/base64 resources, screenshot blocking, device identifiers, request encryption, private forks and review/channel behavior remain separately authorized mechanisms and must not be inferred from this style switch.

Generation may also ask whether to generate CodeGraph optional support. It only writes `docs/tools/codegraph.md` and records the status in `.agent/config.json`; it does not install CodeGraph or build an index silently. In non-interactive automation, set the environment explicitly:

```bash
AGENT_WORKFLOW_CODEGRAPH=ask "/path/to/agent-workflow-kit/scripts/generate_workflow.sh" "/path/to/target" --stack node
AGENT_WORKFLOW_CODEGRAPH=yes "/path/to/agent-workflow-kit/scripts/generate_workflow.sh" "/path/to/target" --stack node
AGENT_WORKFLOW_CODEGRAPH=no "/path/to/agent-workflow-kit/scripts/generate_workflow.sh" "/path/to/target" --stack node
```

Generation may also ask whether to generate Open Design optional support. It only writes `docs/tools/opendesign.md` and records the status in `.agent/config.json`; it does not silently install MCP. Codex-side MCP setup must use Open Design's official installer (`od mcp install codex`, previewable with `od mcp install codex --print`). Open Design must still be used only when the user explicitly requests Open Design, a design mockup, or code from an Open Design artifact. When generating design artifacts, the brief must include the quality prompt from `docs/tools/opendesign.md`: real product quality, strong industry signal, scenario-specific content, no generic AI/SaaS dashboard, no glow gradients, no empty marketing copy, and no large-card pileup. When the design needs custom visual assets, use `$openai-image-gateway` only after the user explicitly asks for generated assets or approves generation, and prefer one combined asset board/contact sheet for later cropping because image generation is charged per image. In non-interactive automation, set the environment explicitly:

```bash
AGENT_WORKFLOW_OPENDESIGN=ask "/path/to/agent-workflow-kit/scripts/generate_workflow.sh" "/path/to/target" --stack node
AGENT_WORKFLOW_OPENDESIGN=yes "/path/to/agent-workflow-kit/scripts/generate_workflow.sh" "/path/to/target" --stack node
AGENT_WORKFLOW_OPENDESIGN=no "/path/to/agent-workflow-kit/scripts/generate_workflow.sh" "/path/to/target" --stack node
```

When using this skill from a chat environment, ask the user about optional Patrol, HarmonyOS, CodeGraph and Open Design support before invoking generation or upgrade, then pass `AGENT_WORKFLOW_PATROL=yes|no`, `AGENT_WORKFLOW_HARMONYOS=yes|no`, `AGENT_WORKFLOW_CODEGRAPH=yes|no` and `AGENT_WORKFLOW_OPENDESIGN=yes|no` so non-TTY script execution does not silently skip the optional prompts.

Alternative natural-language Runtime initialization:

```bash
cd "/path/to/agent-workflow-kit"
python3 -m runtime.cli run "给这个项目生成 agent workflow" --target "/path/to/target"
```

Use this path when automatic intent routing, stack detection, validation and trace output are desired. If Runtime returns a failed result, inspect its report and the generated `.agent/traces/*.json`, then either fix the target workflow or fall back to the lower-level scripts.

Project deep-scan entrypoint:

```bash
"/path/to/agent-workflow-kit/scripts/recon_project.sh" "/path/to/target"
```

Use this when the user asks to deeply scan the current project and backfill `docs/project/*`. The reconnaissance flow is append-only by default: preserve existing descriptions, refresh only auto-generated reconnaissance blocks, and stop for user confirmation when the detected facts conflict with existing human-authored conclusions. The script writes a JSON report under `.agent/traces/`.

## Opt-in Test Case Workflow

This workflow is Agent-driven. Runtime may identify and plan it, but no generic Bash command can design cross-stack test cases or write trustworthy tests without Agent reasoning.

Before starting, ensure the target has the generated workflow files, especially `docs/test-cases/README.md`, `.agent/state/current-task.json`, `docs/requirements/traceability.md`, and `docs/reports/test-report.md`. If they are missing, use the existing safe generation or upgrade path first; do not use `--force` without explicit user permission.

When enabled, update the current task fields:

```json
{
  "test_case_mode": true,
  "test_case_execution_mode": "pre_implementation",
  "test_case_doc": "docs/test-cases/<requirement-id>.md"
}
```

### `pre_implementation`

1. Parse the original requirement and acceptance criteria.
2. Create `docs/test-cases/<requirement-id>.md` with case IDs, preconditions, steps, expected results, automation type, manual fallback and evidence fields.
3. Present the test cases together with the design doc and execution plan. Do not write business implementation before user approval.
4. Generate the smallest reliable automated tests for automatable cases.
5. Run each new test and confirm it fails because the required behavior is missing. If a real red state cannot be produced, record the reason instead of fabricating evidence.
6. Implement the minimum behavior, rerun the same tests, then execute required manual cases.
7. Write case IDs, commands, results and evidence back to the active plan, traceability and test report.

### `post_implementation`

1. Read the original requirement first, then inspect the current implementation, related task state and Git history.
2. Generate `docs/test-cases/<requirement-id>.md` from the original requirement, not from what the code happens to do.
3. Ask the user to confirm the cases before generating or running new test code.
4. Generate automated tests and run them against the current implementation.
5. If a pre-feature commit can be identified, verify the historical red state only in an isolated worktree or other safe historical checkout. Never modify the user's current worktree to manufacture a red result.
6. If no safe historical state exists, record `无修复前红灯证据` and strengthen confidence with assertion review, negative cases and boundary cases.
7. Treat mismatches as requirement deviations or test defects after diagnosis; never weaken an accepted assertion merely to match current code.

### Manual fallback and failure handling

- A manual case must record the automation blocker, reproducible steps, environment/device/account type, evidence and residual risk before it can be marked `人工通过`.
- Classify failures as business failure, test implementation error, environment blocker or non-automatable case. Fix and rerun the same case when possible.
- All cases must be `通过` or `人工通过` before the requirement is complete.
- The mode remains active for the current requirement until the user explicitly cancels it.

6. Upgrade existing workflow from current templates:
   - If the user asks to sync or upgrade an existing project from the latest kit templates, run a dry-run first:

```bash
"/path/to/agent-workflow-kit/scripts/upgrade_workflow.sh" "/path/to/target" --stack flutter
```

   - Review the planned changes with the user.
   - Apply only after confirmation:

```bash
"/path/to/agent-workflow-kit/scripts/upgrade_workflow.sh" "/path/to/target" --stack flutter --apply
```

   - Flutter upgrades may ask whether to generate or refresh Patrol acceptance support. Use `AGENT_WORKFLOW_PATROL=yes|no` for deterministic automation.
   - Flutter upgrades may ask whether to generate or refresh HarmonyOS/Flutter-OH dependency adaptation support. Use `AGENT_WORKFLOW_HARMONYOS=yes|no` for deterministic automation.
   - Upgrades may ask whether to generate or refresh CodeGraph optional support. Use `AGENT_WORKFLOW_CODEGRAPH=yes|no` for deterministic automation.
   - Upgrades may ask whether to generate or refresh Open Design optional support. Use `AGENT_WORKFLOW_OPENDESIGN=yes|no` for deterministic automation.

   - For many local projects, default to scanning `~/project` and dry-run first:

```bash
"/path/to/agent-workflow-kit/scripts/upgrade_all_workflows.sh" "$HOME/project"
```

   - Apply batch upgrades only after confirmation:

```bash
"/path/to/agent-workflow-kit/scripts/upgrade_all_workflows.sh" "$HOME/project" --apply
```

   - The upgrade scripts refresh common workflow entrypoints, validation docs, failure taxonomy docs, and `scripts/acceptance_simulator.sh`, but only add missing state, trace, eval and project-adapted files. They must not overwrite existing `.agent/state/current-task.json`, `.agent/config.json`, `.agent/traces/`, `.agent/evals/`, `docs/coding-progress.md`, `docs/feature_list.json`, `docs/project/`, `docs/requirements/`, `docs/design/`, `docs/exec-plans/`, or `docs/reports/` content.
   - If Patrol support is enabled, `docs/testing/patrol.md` and `scripts/patrol_acceptance.sh` are generated or refreshed as workflow support files.
   - If HarmonyOS support is enabled, `docs/platforms/harmonyos.md`, `docs/platforms/harmonyos-dependency-matrix.md`, `docs/testing/harmonyos.md` and `scripts/harmonyos_acceptance.sh` are generated or refreshed as workflow support files.
   - If CodeGraph support is enabled, `docs/tools/codegraph.md` is generated or refreshed as a workflow support file.
   - If Open Design support is enabled, `docs/tools/opendesign.md` is generated or refreshed as a workflow support file. The generated workflow must still call Open Design only after the user explicitly asks for it, and Codex-side MCP setup must be verified with `od mcp install codex --print`, `od mcp install codex`, and `codex mcp list`.

7. Optimize existing workflow:
   - Read current `.agent/state/current-task.json`, `.agent/config.json`, `.agent/traces/README.md`, `.agent/traces/schema.json`, `.agent/evals/README.md`, `AGENTS.md`, `init.sh`, `docs/index.md`, `docs/verification.md`, `docs/process/verification.md`, `docs/process/failure-taxonomy.md`, `docs/process/badcase-analysis.md`, `docs/acceptance_simulator.md`, `docs/testing/patrol.md`, `docs/platforms/harmonyos.md`, `docs/platforms/harmonyos-dependency-matrix.md`, `docs/testing/harmonyos.md`, `docs/tools/codegraph.md`, `docs/tools/opendesign.md`, `docs/coding-progress.md`, `docs/feature_list.json`, `docs/session-handoff.md`, `docs/project/*`, `docs/requirements/*`, `docs/design/index.md`, `docs/exec-plans/active/index.md`, `docs/exec-plans/tech-debt-tracker.md`, `docs/reports/eval-report.md`, `docs/reports/test-report.md`, `scripts/acceptance_simulator.sh`, `scripts/patrol_acceptance.sh`, and `scripts/harmonyos_acceptance.sh` when present.
   - Preserve project-specific instructions, build notes, private constraints, and verification commands.
   - Keep `AGENTS.md` concise: project context, startup entry, hard rules, workflow summary, verification entry and handoff summary only.
   - Keep common workflow guidance generic; do not hard-code one business project's rules into reusable templates.
   - Prefer narrow edits: fix missing files, unresolved placeholders, stale commands, invalid JSON, weak verification notes, missing acceptance guidance, missing requirement traceability, missing project constraints, or missing active plan status.
   - Keep `docs/feature_list.json` as a project-level requirement index only; detailed steps belong in `docs/exec-plans/active/*.md`.
   - Keep `docs/coding-progress.md` as a session-level progress log only; full plans and evidence belong in active plans, traceability, and test reports.
   - Keep `.agent/state/current-task.json` as machine-readable current task state only; full plans and evidence belong in active plans, traceability, and test reports.
   - Keep `.agent/config.json` as machine-readable workflow metadata only; project rules belong in `docs/project/constraints.md`.
   - Use `docs/process/failure-taxonomy.md` when verification fails or the task is blocked, and record the failure type with evidence.
   - Use `docs/process/badcase-analysis.md` when Runtime, Router, Planner, Validator or Skill selection behavior is wrong; record eval or replay evidence in `docs/reports/eval-report.md`.
   - Use `docs/process/verification.md` to classify each requirement into L0-L4 before verification. Record acceptance level, reasoning, confidence, selected commands and uncovered risks in active plans, `docs/requirements/traceability.md`, and `docs/reports/test-report.md`.
   - For Flutter startup, local/simulator acceptance or Patrol verification, inspect `.vscode/launch.json` and `define_config/.custom.json` first. Use platform-appropriate launch args when present, and record the selected args or skip reason in verification evidence.
   - Keep enhancement modules scenario-triggered: requirement grilling, PRD synthesis, issue slicing, TDD, diagnosis, architecture review, E2E/Patrol and handoff should run only when their trigger conditions are met, with trigger or skip reasons recorded.
   - When tests are generated from requirements or uncommitted code, perform test-case self-validation first: the test must run, contain meaningful assertions, map to a requirement or reproduction path, and be reusable as a regression case.
   - When the user chooses Patrol for a Flutter requirement, generate or update a requirement-level `patrol_test/<requirement-id>_test.dart`, add minimal stable widget locators when needed, run `scripts/patrol_acceptance.sh`, and write evidence and uncovered risk to the active plan, `docs/requirements/traceability.md`, and `docs/reports/test-report.md`.
   - For Flutter L3/L4 work, consider Patrol when it is configured. If Patrol is not configured or cannot run, record the fallback acceptance path and uncovered Patrol risk instead of claiming E2E coverage.
   - For Flutter-OH work with HarmonyOS support configured, read the platform guide, dependency ledger and testing guide before implementation. Keep pure Dart checks separate from native plugin checks; record per-plugin build and real-device evidence. Patrol does not substitute for HarmonyOS coverage.
   - For projects with CodeGraph configured, consider it during project reconnaissance, impact analysis, affected-test selection and complex diagnosis. If CodeGraph is not configured or unavailable, continue with standard repository search and record the skip reason only when the risk requires it.
   - For projects with Open Design configured, use it only when the user explicitly asks for Open Design, design mockups, or code from an Open Design artifact. Before first use after install or upgrade, verify Codex MCP with `od mcp install codex --print`, `od mcp install codex`, and `codex mcp list`; do not hand-write MCP config. For generated design artifacts, include the quality prompt from `docs/tools/opendesign.md`, then score texture/finish, anti-AI feel, industry recognition, information density and implementability; if any core score is below 4/5, revise the brief and iterate instead of treating the design as final. If custom visual assets are needed, use `$openai-image-gateway` only when the user explicitly asks for generated assets or approves generation, and batch multiple assets into one asset board/contact sheet before local cropping to reduce per-image cost. Record the trigger phrase, asset-generation approval and artifact evidence in the active plan.
   - Put project-specific rules and limitations in `docs/project/constraints.md`; only summarize the most critical hard rules in `AGENTS.md`.
   - Ensure `docs/project/constraints.md` includes the coding convention that new methods and variables should have comments explaining purpose or business meaning, while simple local temporaries may omit comments when readability is clear.

8. Validate:

```bash
"/path/to/agent-workflow-kit/scripts/validate_target.sh" "/path/to/target"
```

For generated or modified targets, run validation and report the result. Do not run full builds, signing, publishing, or expensive Xcode builds unless explicitly requested.

9. Optional local kit eval:

```bash
"/path/to/agent-workflow-kit/scripts/run_eval.sh"
```

Run this after changing Runtime routing, Query Rewriter, Planner, Skill Selector, Prompt Registry, eval cases, or generated workflow behavior. It is a kit-level regression check, not a target project build.

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

5. Confirm the installed copy includes Workflow V2 and Runtime guidance:

```bash
grep -n "runtime.cli\|config.json\|run_eval" ~/.codex/skills/agent-workflow/SKILL.md
```

When workflow templates, generated behavior, or sync rules change, update `templates/VERSION`. When generator/runtime script capability changes, update root `VERSION`. Generated targets record `workflow_version`, `template_revision`, and `kit_version` in `.agent/config.json` for sync decisions.

After changing agent-workflow-kit, decide whether the installed skill must be refreshed:

- Refresh the installed skill when changes affect workflow behavior, generated/updated files, sync/version rules, validation policy, Runtime/Eval guidance, safety rules, done criteria, or this skill's instructions.
- Reinstall with `scripts/install_codex_skill.sh`, then verify the installed copy with the grep checks above.
- If no refresh is needed, state why in the final handoff so the decision is explicit.

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
- Runtime command and trace path when Runtime was used
- eval command and outcome when kit-level eval was required
- acceptance command outcome when acceptance was required
- acceptance level, classification reason, confidence and uncovered risk when verification was selected automatically
- test-case self-validation result when tests were generated or added
- Patrol support status, generated Patrol test path, command result and evidence path when the user selected Patrol
- requirement/design/plan files created or updated
- traceability, eval-report and test-report status
- any skipped step and why
