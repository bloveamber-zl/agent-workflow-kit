# Opt-in Test Case Driven Workflow Implementation Plan

> **For agentic workers:** Follow the project execution plan task-by-task and keep verification evidence.

**Goal:** 为生成后的项目增加默认关闭、由用户明确触发的测试用例驱动流程，并支持开发前测试先行与开发后直接验证两种模式。

**Architecture:** `agent-workflow` skill 和生成后的流程文档负责真正的需求理解、用例设计、测试生成与证据写回；轻量 Runtime 只识别意图、判定运行模式并输出 Agent handoff plan，不伪装成能够独立编写跨技术栈测试。生成器与项目扫描器共同维护 `docs/workflow-capabilities.md`，状态在实现和全量验证完成后从 `planned` 切换为 `enabled`。

**Tech Stack:** Python 3 标准库、Bash、Markdown/JSON 模板、`unittest`、现有 Runtime 与生成/升级/校验脚本。

---

## 实施约束

- 当前工作树存在用户和其他任务留下的未提交改动；每个提交只包含本任务明确列出的文件，不得清理或回滚其他改动。
- 不新增外部依赖，不实现通用测试代码生成器。
- 未出现明确测试用例触发语时，现有 L0-L4、TDD、Patrol 和人工验收行为保持不变，也不主动提醒。
- Runtime 对该能力只输出 `agent_action_required`，规划成功的 trace 状态使用 `passed`；实际文件和测试代码必须由 Agent 按 skill 执行。
- `docs/test-cases/<requirement-id>.md` 只在当前需求显式启用后创建；生成器只提供 `docs/test-cases/README.md` 作为格式和流程说明。
- 下文提交命令只在对应文件的完整 diff 都属于本任务时执行。若文件开工前已有无关改动，先用 `git diff -- <path>` 核对；无法无交互地安全拆分时，保留未暂存并把提交推迟到用户处理原改动之后。

## 文件结构

- Create: `templates/base/docs/test-cases/README.md.template`、`docs/test-cases/README.md`：需求级测试用例格式、两种运行模式和完成门禁。
- Modify: `templates/base/.agent/state/current-task.json.template`：增加默认关闭的测试用例字段。
- Modify: `templates/base/AGENTS.md.template`、`templates/base/docs/index.md.template`、`templates/base/docs/process/verification.md.template`：增加显式触发路由。
- Modify: `templates/base/docs/requirements/traceability.md.template`、`templates/base/docs/reports/test-report.md.template`：增加用例 ID、模式和证据映射。
- Modify: `runtime/models.py`、`runtime/router.py`、`runtime/query_rewriter.py`、`runtime/requirement_parser.py`、`runtime/planner.py`、`runtime/skill_selector.py`、`runtime/cli.py`、`runtime/reporter.py`：识别测试用例意图并生成 Agent handoff plan。
- Modify: `skills/agent-workflow/SKILL.md`：实现 Agent 侧开发前/开发后流程。
- Modify: `scripts/generate_workflow.sh`、`scripts/recon_project.py`：生成并重建一致的能力说明。
- Modify: `scripts/upgrade_workflow.sh`、`scripts/validate_target.sh`、`scripts/self_test.sh`：升级、校验与回归覆盖。
- Modify: `runtime/eval_runner.py`、`tests/runtime/test_planning_components.py`、`tests/runtime/test_runtime_mvp.py`、`tests/runtime/test_eval_runner.py`：Runtime 与 eval 单测。
- Create: `eval/cases/test_case_pre_implementation.json`、`eval/cases/test_case_post_implementation.json`：意图评估样例。
- Modify: `README.md`、`docs/usage.md`、`docs/workflow-capabilities.md`、`VERSION`、`templates/VERSION`：用户入口、能力状态与版本。
- Modify at closeout: `.agent/state/current-task.json`、`docs/coding-progress.md`、`docs/feature_list.json`、`docs/requirements/parsed-requirements.md`、`docs/requirements/traceability.md`、`docs/reports/test-report.md`：当前仓库任务证据。

### Task 1: 生成测试用例流程模板和默认关闭状态

**Files:**
- Create: `templates/base/docs/test-cases/README.md.template`
- Create: `docs/test-cases/README.md`
- Modify: `templates/base/.agent/state/current-task.json.template`
- Modify: `templates/base/AGENTS.md.template`
- Modify: `templates/base/docs/index.md.template`
- Modify: `templates/base/docs/process/verification.md.template`
- Modify: `templates/base/docs/requirements/traceability.md.template`
- Modify: `templates/base/docs/reports/test-report.md.template`
- Modify: `scripts/generate_workflow.sh`
- Test: `scripts/self_test.sh`

- [ ] **Step 1: 在 self-test 中写入失败断言**

在每个生成目标的基础断言区加入：

```bash
test -f "$target/docs/test-cases/README.md"
grep -q 'test_case_mode' "$target/.agent/state/current-task.json"
grep -q '默认关闭' "$target/docs/test-cases/README.md"
grep -q 'post_implementation' "$target/docs/test-cases/README.md"
grep -q '测试用例驱动模式' "$target/docs/process/verification.md"
grep -q '测试用例 ID' "$target/docs/requirements/traceability.md"
grep -q '执行模式' "$target/docs/reports/test-report.md"
```

- [ ] **Step 2: 运行 self-test 并确认因模板缺失失败**

Run: `scripts/self_test.sh`

Expected: FAIL，首个相关错误是缺少 `docs/test-cases/README.md` 或找不到 `test_case_mode`。

- [ ] **Step 3: 创建测试用例格式模板**

`templates/base/docs/test-cases/README.md.template` 至少写入以下固定结构：

```markdown
# 测试用例驱动流程

## 启用条件

- 默认关闭，不提醒。
- 仅当用户明确要求“需要测试用例”或语义等价表达时，对当前需求启用。

## 运行模式

- `pre_implementation`：确认用例后先生成自动化测试，再实现功能。
- `post_implementation`：根据原始需求生成用例，确认后直接测试现有实现。

## 需求级文件

启用后创建 `docs/test-cases/<requirement-id>.md`。每条用例包含：用例 ID、验收标准、场景类型、前置条件、步骤、预期结果、验证方式、自动化文件或人工路径、状态、证据和剩余风险。

## 完成门禁

所有用例必须为“通过”或“人工通过”；人工通过必须包含不可自动化原因和验收证据。
```

当前仓库的 `docs/test-cases/README.md` 使用同一内容，作为本项目后续主动调用入口。

- [ ] **Step 4: 增加默认关闭的任务字段**

把 `templates/base/.agent/state/current-task.json.template` 扩展为：

```json
{
  "status": "intake",
  "requirement_id": "",
  "design_doc": "",
  "exec_plan": "",
  "test_case_mode": false,
  "test_case_execution_mode": "",
  "test_case_doc": "",
  "changed_files": [],
  "verification": [],
  "blockers": [],
  "updated_at": "{{CURRENT_DATE}}"
}
```

- [ ] **Step 5: 把显式触发流程接入模板文档**

在 `AGENTS.md.template` 和 `verification.md.template` 中写明：未明确触发时保持默认流程；触发后必须创建需求级用例、让用户确认、按模式生成测试。`docs/index.md.template` 增加“用户明确要求测试用例 -> docs/test-cases/README.md”的读取路由。追踪矩阵增加“测试用例模式 / 测试用例 ID / 自动化或人工证据”，测试报告增加“执行模式 / 用例 ID / 测试文件 / 结果 / 降级原因 / 证据”。

- [ ] **Step 6: 让生成器输出说明文件并忽略动态用例目录**

在 `scripts/generate_workflow.sh` 的 `outputs`、render 调用和 `workflow_ignore_paths` 中分别加入：

```bash
"docs/test-cases/README.md"
"/docs/test-cases/"
```

- [ ] **Step 7: 运行 self-test 验证模板通过**

Run: `scripts/self_test.sh`

Expected: 新增断言 PASS；如果后续任务尚未实现的断言不存在，不在本任务提前加入。

- [ ] **Step 8: 提交模板基础**

```bash
git add -f docs/test-cases/README.md
git add templates/base/docs/test-cases/README.md.template templates/base/.agent/state/current-task.json.template templates/base/AGENTS.md.template templates/base/docs/index.md.template templates/base/docs/process/verification.md.template templates/base/docs/requirements/traceability.md.template templates/base/docs/reports/test-report.md.template scripts/generate_workflow.sh scripts/self_test.sh
git commit -m "feat: 增加可选测试用例流程模板" -m "需求：显式触发时生成需求级测试用例，默认流程保持关闭。" -m "实现：补充用例说明、任务字段、追踪报告和生成器输出。"
```

### Task 2: 实现 Agent skill 的两种测试用例运行模式

**Files:**
- Modify: `skills/agent-workflow/SKILL.md`
- Modify: `scripts/self_test.sh`

- [ ] **Step 1: 增加已安装 skill 的失败断言**

在安装 skill 检查区加入：

```bash
grep -Fq 'test_case_mode' "$INSTALLED_SKILL"
grep -Fq 'pre_implementation' "$INSTALLED_SKILL"
grep -Fq 'post_implementation' "$INSTALLED_SKILL"
grep -Fq 'docs/test-cases/<requirement-id>.md' "$INSTALLED_SKILL"
grep -Fq '不主动提醒' "$INSTALLED_SKILL"
```

- [ ] **Step 2: 运行 self-test 确认 skill 断言失败**

Run: `scripts/self_test.sh`

Expected: FAIL，已安装 skill 缺少 `test_case_mode` 或运行模式说明。

- [ ] **Step 3: 在 skill 中加入显式触发路由**

在 `Decide the operation` 之前加入以下等价规则：

```text
If the user explicitly asks for test cases, set test_case_mode=true for the current requirement. Do not enable or suggest this mode based only on risk level. Choose pre_implementation unless the user says the feature is already implemented; then choose post_implementation.
```

如果目标项目尚未安装 workflow，skill 先走现有安全生成/确认流程，确保测试用例说明、状态文件和报告入口存在，再进入当前需求的测试用例模式。

- [ ] **Step 4: 写入开发前流程**

skill 必须要求 Agent 按顺序执行：解析需求和验收标准、创建 `docs/test-cases/<requirement-id>.md`、与设计/计划一起确认、生成可执行测试、验证真实红灯或记录无法先红原因、实现、复测和写回证据。

- [ ] **Step 5: 写入开发后流程**

skill 必须要求 Agent 先检查原始需求、当前实现和 Git 历史，再生成用例并确认；随后直接运行自动化测试。能够定位旧提交时只在隔离工作区验证旧版本红灯；不能定位时记录“无修复前红灯证据”，禁止修改当前工作树来伪造红灯。

- [ ] **Step 6: 写入人工降级和退出规则**

人工降级必须包含原因、步骤、环境、证据和剩余风险；只有用户明确取消才退出当前需求的测试用例模式。测试失败时区分业务失败、测试实现错误、环境阻塞和不可自动化。

- [ ] **Step 7: 运行 self-test 验证安装后的 skill**

Run: `scripts/self_test.sh`

Expected: skill 安装与新增 grep 断言 PASS。

- [ ] **Step 8: 同步本机已安装 skill**

Run: `scripts/install_codex_skill.sh`

Expected: 输出 `Installed Codex skill: agent-workflow`，目标为 `$CODEX_HOME/skills/agent-workflow`。

- [ ] **Step 9: 提交 skill 行为**

```bash
git add skills/agent-workflow/SKILL.md scripts/self_test.sh
git commit -m "feat: 接入测试用例驱动 Agent 流程" -m "需求：仅在用户明确要求时支持开发前和开发后测试用例模式。" -m "实现：补充用例确认、测试生成、人工降级和证据门禁。"
```

### Task 3: Runtime 识别意图并输出 Agent handoff plan

**Files:**
- Modify: `runtime/models.py`
- Modify: `runtime/router.py`
- Modify: `runtime/query_rewriter.py`
- Modify: `runtime/requirement_parser.py`
- Modify: `runtime/planner.py`
- Modify: `runtime/skill_selector.py`
- Modify: `runtime/cli.py`
- Modify: `runtime/reporter.py`
- Modify: `runtime/eval_runner.py`
- Modify: `tests/runtime/test_planning_components.py`
- Modify: `tests/runtime/test_runtime_mvp.py`
- Create: `eval/cases/test_case_pre_implementation.json`
- Create: `eval/cases/test_case_post_implementation.json`
- Modify: `tests/runtime/test_eval_runner.py`

- [ ] **Step 1: 写 Runtime 失败测试**

覆盖以下断言：

```python
self.assertEqual(route_intent("这个需求需要测试用例").intent, "test_case_workflow")
self.assertEqual(route_intent("这个功能已经开发完成，请根据需求生成测试用例并执行测试").execution_mode, "post_implementation")
self.assertEqual(rewrite_query("需要测试用例", target_path="/tmp/demo").execution_mode, "pre_implementation")
```

Planner 断言开发前步骤包含 `verify_expected_failure`，开发后步骤包含 `inspect_existing_implementation` 且不包含 `verify_expected_failure`。CLI 断言输出：

```text
Intent: test_case_workflow
Result: agent_action_required
Mode: post_implementation
```

- [ ] **Step 2: 运行 Runtime 测试确认失败**

Run: `python3 -m unittest tests.runtime.test_runtime_mvp tests.runtime.test_planning_components tests.runtime.test_eval_runner`

Expected: FAIL，`RouteResult` 没有 `execution_mode` 或意图仍被路由到 `validate_workflow`。

- [ ] **Step 3: 扩展 Runtime 数据模型**

给 `RouteResult` 和 `StructuredTask` 增加默认空字符串字段：

```python
execution_mode: str = ""
```

`query_rewriter` 把路由结果传入 `StructuredTask`，并在测试用例意图下增加 `test_case_mode_enabled` 约束。

- [ ] **Step 4: 在通用验证关键词前识别测试用例意图**

`router.py` 先匹配“需要测试用例、生成测试用例、测试用例流程”等明确语义；包含“已经开发、已开发完成、现有实现、直接进行测试”时返回 `post_implementation`，否则返回 `pre_implementation`。普通“验证当前 workflow”仍路由到 `validate_workflow`。

- [ ] **Step 5: 生成 Agent 可执行计划而非调用脚本**

开发前 actions：

```python
[
    "inspect_target",
    "parse_requirement",
    "generate_test_case_doc",
    "request_test_case_approval",
    "generate_automated_tests",
    "verify_expected_failure",
    "implement_feature",
    "run_requirement_tests",
    "record_test_evidence",
]
```

开发后 actions：

```python
[
    "inspect_target",
    "parse_requirement",
    "inspect_existing_implementation",
    "generate_test_case_doc",
    "request_test_case_approval",
    "generate_automated_tests",
    "run_requirement_tests",
    "record_test_evidence",
]
```

- [ ] **Step 6: 生成需求摘要并选择 Agent skill**

`requirement_parser.py` 对 `test_case_workflow` 返回：

```python
goal = "根据原始需求生成测试用例并验证目标实现"
acceptance = [
    "每个验收标准映射到测试用例 ID",
    "可自动化用例有测试代码和运行结果",
    "人工用例有降级原因和验收证据",
]
risks = ["测试不得根据现有实现反向削弱原始需求"]
```

`skill_selector.py` 对该意图仍选择 `agent-workflow`，但 reason 使用“需要 Agent 解析需求、生成用例与测试并写回证据”，entrypoints 使用 `docs/test-cases/README.md`、`docs/process/verification.md` 和 `docs/reports/test-report.md`，不返回不存在的测试生成脚本。

- [ ] **Step 7: CLI 和 reporter 输出 handoff 而不进入 executor**

`runtime/cli.py` 在 `test_case_workflow` 分支调用 rewriter、requirement parser 和 planner，写入 router/planner trace，规划成功时 trace final status 使用现有 schema 允许的 `passed`，返回码为 0；用户可见报告结果使用 `agent_action_required`。扩展 `render_report` 的可选参数：

```python
def render_report(
    intent: str,
    context: ProjectContext,
    result: str,
    trace_path: Path,
    execution_mode: str = "",
    plan_steps: list[str] | None = None,
) -> str:
```

报告在可选值存在时追加 `Mode:` 和逐行 `Plan:`。该分支不得调用 `execute_workflow_action` 或 `validate_target`。

- [ ] **Step 8: 增加 eval cases 并调整汇总断言**

两个 case 的 expected intent 均为 `test_case_workflow`，fixture 使用 `workflow_project`，requires_user_input 为 false；分别期望 `pre_implementation` 和 `post_implementation`。扩展 `runtime/eval_runner.py` 比较可选 `execution_mode` 并返回 `execution_mode_accuracy`，最终 `tests/runtime/test_eval_runner.py` 断言 cases/passed 为 5、intent/stack/slot/execution mode 准确率均为 1.0。

- [ ] **Step 9: 运行 Runtime 与 eval 验证**

Run: `python3 -m unittest tests.runtime.test_runtime_mvp tests.runtime.test_planning_components tests.runtime.test_eval_runner`

Expected: PASS。

Run: `scripts/run_eval.sh`

Expected: 5 cases，0 failed，intent/stack/slot accuracy 均为 1.0，并新增 execution mode accuracy 1.0。

- [ ] **Step 10: 提交 Runtime 路由**

```bash
git add runtime/models.py runtime/router.py runtime/query_rewriter.py runtime/requirement_parser.py runtime/planner.py runtime/skill_selector.py runtime/cli.py runtime/reporter.py runtime/eval_runner.py tests/runtime/test_planning_components.py tests/runtime/test_runtime_mvp.py tests/runtime/test_eval_runner.py eval/cases/test_case_pre_implementation.json eval/cases/test_case_post_implementation.json
git commit -m "feat: 识别测试用例驱动意图" -m "需求：区分开发前测试先行与开发后直接验证。" -m "实现：Runtime 仅输出 Agent handoff plan，不伪装执行跨技术栈测试。"
```

### Task 4: 同步主动功能说明、生成器与项目扫描器

**Files:**
- Modify: `scripts/generate_workflow.sh`
- Modify: `scripts/recon_project.py`
- Modify: `docs/workflow-capabilities.md`
- Modify: `scripts/self_test.sh`
- Test: `tests/runtime/test_runtime_mvp.py`

- [ ] **Step 1: 增加能力页失败断言**

在生成后和 recon 后都断言：

```bash
grep -q '测试用例驱动验证 | enabled' "$target/docs/workflow-capabilities.md"
grep -q '开发前模式' "$target/docs/workflow-capabilities.md"
grep -q '开发后模式' "$target/docs/workflow-capabilities.md"
grep -q '默认关闭' "$target/docs/workflow-capabilities.md"
```

- [ ] **Step 2: 运行 self-test 确认能力仍为缺失或 planned**

Run: `scripts/self_test.sh`

Expected: FAIL，生成目标缺少“测试用例驱动验证”或当前状态不是 `enabled`。

- [ ] **Step 3: 更新生成器能力页内容**

在 `initialize_workflow_capabilities_doc` 的能力表加入 enabled 行，并增加说明段，内容与当前 `docs/workflow-capabilities.md` 一致：显式触发、默认关闭、两种模式、需求为事实来源、人工降级和主要产出。

- [ ] **Step 4: 更新 recon 重建内容**

在 `build_capabilities_doc` 加入同一行和说明段，确保运行深度扫描后不会删除测试用例能力。保留 `AUTO-RECON` 区块职责，只更新最近扫描证据。

- [ ] **Step 5: 把当前能力说明页从 planned 切为 enabled**

只有 Task 1-3 测试已通过后，才把 `docs/workflow-capabilities.md` 的状态和说明改为 `enabled`，删除“尚未完成 Runtime、模板和验证链路实现”的描述。

- [ ] **Step 6: 运行生成与 recon 回归**

Run: `scripts/self_test.sh`

Expected: 每种 stack 生成、recon、校验均 PASS，测试用例能力在 recon 前后都存在。

- [ ] **Step 7: 提交能力说明同步**

```bash
git add scripts/generate_workflow.sh scripts/recon_project.py docs/workflow-capabilities.md scripts/self_test.sh
git commit -m "feat: 发布测试用例驱动主动能力" -m "需求：在统一能力说明页中提供可查看、可调用的测试流程。" -m "实现：生成器与项目扫描器共同维护两种运行模式及默认关闭策略。"
```

### Task 5: 加固升级、状态校验和兼容性

**Files:**
- Modify: `scripts/upgrade_workflow.sh`
- Modify: `scripts/validate_target.sh`
- Modify: `scripts/self_test.sh`

- [ ] **Step 1: 增加升级和无效状态失败测试**

self-test 需要验证升级 dry-run/apply 会补缺失的 `docs/test-cases/README.md`，但保留已有 `docs/test-cases/REQ-LOCAL.md`。另外构造：

```json
{
  "test_case_mode": true,
  "test_case_execution_mode": "invalid",
  "test_case_doc": ""
}
```

并断言 `validate_target.sh` 返回非零。

- [ ] **Step 2: 运行 self-test 确认失败**

Run: `scripts/self_test.sh`

Expected: FAIL，升级未补 README 或 validator 未拒绝无效模式。

- [ ] **Step 3: 把说明文件加入 add-only 升级清单**

在 `scripts/upgrade_workflow.sh` 的 `add_only_files` 加入 `docs/test-cases/README.md`，在 ignore block 加入 `/docs/test-cases/`。不得把需求级测试用例文件加入 update_files。

- [ ] **Step 4: 校验可选任务字段**

把已存在的 `docs/test-cases/README.md` 加入 `validate_target.sh` 的可选 placeholder 检查，但不加入 `required_files`，以保持旧项目在升级前仍可校验。current-task Python 校验增加：

```bash
python3 - "$TARGET_ROOT/.agent/state/current-task.json" "$TARGET_ROOT" <<'PY'
```

对应 Python 块导入 `Path`，并初始化：

```python
path, target_root_arg = sys.argv[1:3]
target_root = Path(target_root_arg)
```

随后加入字段规则：

```python
test_case_mode = data.get("test_case_mode", False)
if not isinstance(test_case_mode, bool):
    raise SystemExit("Invalid test_case_mode: expected boolean")
mode = data.get("test_case_execution_mode", "")
doc = data.get("test_case_doc", "")
if test_case_mode and mode not in {"pre_implementation", "post_implementation"}:
    raise SystemExit("Invalid test_case_execution_mode")
if test_case_mode and (not isinstance(doc, str) or not doc.startswith("docs/test-cases/")):
    raise SystemExit("Invalid test_case_doc")
if test_case_mode and not (target_root / "docs/test-cases/README.md").is_file():
    raise SystemExit("Missing docs/test-cases/README.md for enabled test case mode")
if test_case_mode and not (target_root / doc).is_file():
    raise SystemExit("Missing requirement test case document")
```

旧项目缺少三个字段时必须通过。

- [ ] **Step 5: 运行完整 self-test**

Run: `scripts/self_test.sh`

Expected: 所有 stack、覆盖保护、升级、Patrol、CodeGraph、Open Design、recon 和新增兼容性断言 PASS。

- [ ] **Step 6: 提交升级与校验**

```bash
git add scripts/upgrade_workflow.sh scripts/validate_target.sh scripts/self_test.sh
git commit -m "fix: 加固测试用例模式升级与校验" -m "问题：旧项目缺少新字段，错误模式也可能绕过完成门禁。" -m "修复：采用可选字段兼容校验，升级只补说明文件并保留需求级用例。"
```

### Task 6: 更新用户文档、版本和项目证据

**Files:**
- Modify: `README.md`
- Modify: `docs/usage.md`
- Modify: `VERSION`
- Modify: `templates/VERSION`
- Modify: `.agent/state/current-task.json`
- Modify: `docs/coding-progress.md`
- Modify: `docs/feature_list.json`
- Modify: `docs/requirements/parsed-requirements.md`
- Modify: `docs/requirements/traceability.md`
- Modify: `docs/reports/test-report.md`
- Modify or create: `docs/exec-plans/active/2026-07-10-opt-in-test-case-driven-workflow.md`

- [ ] **Step 1: 更新用户入口文档**

README 和 usage 必须说明：

```text
默认不启用、不提醒；用户明确要求测试用例时才对当前需求启用。
需求未开发：先确认用例、生成失败测试、实现和复测。
需求已开发：根据原始需求生成用例并直接测试现有实现，不伪造红灯。
```

- [ ] **Step 2: 更新版本**

在保留工作树已有版本推进的基础上，将根 `VERSION` 和 `templates/VERSION` 各提升一个修订号；先读当前文件，不能回退其他任务已写入的 `0.2.3` 或 `2026-07-07.1`。

- [ ] **Step 3: 写回当前项目需求与执行证据**

登记独立需求 ID `REQ-OPT-IN-TEST-CASE-WORKFLOW`，把状态按实际进度从 implementing 更新到 verifying/done。追踪矩阵必须映射设计文档、实施计划、Runtime/skill/模板实现、单测/self-test/validate 证据。测试报告记录开发前、开发后、默认关闭、人工降级和旧项目兼容场景。

- [ ] **Step 4: 运行全量验证**

Run: `python3 -m unittest tests.runtime.test_runtime_mvp tests.runtime.test_planning_components tests.runtime.test_eval_runner`

Expected: PASS。

Run: `scripts/run_eval.sh`

Expected: 5 cases，0 failed，各准确率为 1.0。

Run: `scripts/self_test.sh`

Expected: PASS。

Run: `scripts/validate_target.sh /Users/Lin/project/agent-workflow-kit`

Expected: `Workflow files look valid: /Users/Lin/project/agent-workflow-kit`。

- [ ] **Step 5: 刷新并验证本机 skill**

Run: `scripts/install_codex_skill.sh`

Expected: 安装成功。

Run: `rg -n 'post_implementation|test_case_mode' "$HOME/.codex/skills/agent-workflow/SKILL.md"`

Expected: 两个关键词均命中。

- [ ] **Step 6: 检查提交范围**

Run: `git status --short`

Expected: 能区分本任务文件与开工前已有未提交文件；不得把无关改动加入暂存区。

Run: `git diff --check`

Expected: 无空白错误。

- [ ] **Step 7: 提交文档、版本和证据**

```bash
git add README.md docs/usage.md VERSION templates/VERSION .agent/state/current-task.json docs/coding-progress.md docs/feature_list.json docs/requirements/parsed-requirements.md docs/requirements/traceability.md docs/reports/test-report.md docs/exec-plans/active/2026-07-10-opt-in-test-case-driven-workflow.md
git commit -m "docs: 完成测试用例驱动工作流交付" -m "需求：提供显式触发的开发前与开发后测试流程，并保持默认验证不变。" -m "验证：Runtime 单测、eval、self-test、目标校验和已安装 skill 检查均通过。"
```

## 最终验收

- 默认请求不会生成需求级测试用例，也不会提示用户启用。
- “需要测试用例”被识别为 `pre_implementation`。
- “已经开发完成，请根据需求生成测试用例并执行测试”被识别为 `post_implementation`。
- Runtime 输出 Agent handoff plan，不调用不存在的通用测试生成脚本。
- skill 能按确认门禁生成用例、测试代码、人工降级和证据。
- 生成、升级和 recon 后的 `docs/workflow-capabilities.md` 均显示能力为 `enabled`。
- 旧项目缺少新字段仍能通过校验；错误字段组合被拒绝。
- 本机安装的 `$agent-workflow` 与仓库源码一致。
