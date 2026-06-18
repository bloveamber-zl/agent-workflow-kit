# Agent Workflow Runtime 升级开发文档

## 背景

`agent-workflow-kit` 当前是一个可复用的 agent 工作流生成器，核心能力是通过模板和 Bash 脚本，把 `AGENTS.md`、`init.sh`、`.agent/` 状态文件、`docs/` 工作流文档和验收脚本生成到目标项目中。

本次升级目标不是重写现有工具，而是在保留当前生成、升级、校验脚本的基础上，新增轻量 Runtime、Trace、Eval 和 Badcase 闭环能力，让项目从“模板生成器”演进为“面向 Coding Agent 的轻量工作流编排与评估框架”。

## 目标

升级后项目应支持：

- 接收自然语言任务，并识别生成、升级、修复、校验或解释 workflow 的意图。
- 根据目标项目现状构造最小必要上下文。
- 把用户请求改写为结构化任务，缺少关键信息时返回澄清问题。
- 生成可执行计划，并选择合适 skill 或底层脚本。
- 复用现有 `generate_workflow.sh`、`upgrade_workflow.sh` 和 `validate_target.sh` 执行确定性操作。
- 为每次执行写入 node-level trace，便于 badcase 定位和回放。
- 提供离线 eval case 和指标报告，支撑 Prompt、路由和规划能力的回归评估。
- 生成目标项目 Workflow V2 元数据文件，同时保持旧用法可用。

非目标：

- 不做 Web GUI。
- 不在第一阶段引入 LangGraph、数据库或外部服务依赖。
- 不把 Runtime 代码复制到每个目标项目。
- 不承诺实现模型训练、SFT、vLLM 或底层推理服务。

## 总体架构

```text
User Request
  -> Runtime CLI
  -> Intent Router
  -> Query Rewriter
  -> Context Builder
  -> Requirement Parser
  -> Workflow Planner
  -> Skill Selector
  -> Executor
  -> Validator
  -> Reporter
  -> Trace Store / Eval Runner / Badcase Report
```

模块边界：

- `runtime/`：负责自然语言入口、任务路由、上下文构建、计划生成和执行编排。
- `scripts/`：继续负责生成、升级、校验、自测等确定性操作。
- `templates/`：继续负责目标项目 workflow 文件模板。
- `skills/`：继续保存 Codex skill 源文件，并作为 Runtime skill 选择的元数据来源。
- `prompts/`：保存 Prompt 模板和版本说明。
- `eval/`：保存离线评估 case、fixture 和报告。
- `docs/`：保存架构、流程、badcase 和面试作品映射说明。

## 目标项目 Workflow V2

目标项目生成物保持兼容，新增少量机器可读元数据和评估文档。

新增模板：

```text
templates/base/.agent/config.json.template
templates/base/.agent/traces/schema.json.template
templates/base/.agent/evals/README.md.template
templates/base/docs/process/badcase-analysis.md.template
templates/base/docs/reports/eval-report.md.template
```

`.agent/config.json` 示例：

```json
{
  "workflow_version": "2.0",
  "stack": "{{STACK_NAME}}",
  "trace_enabled": true,
  "eval_enabled": false,
  "allow_overwrite": false
}
```

生成脚本变更：

- `scripts/generate_workflow.sh` 将上述文件加入输出列表并渲染。
- `scripts/validate_target.sh` 校验新增 JSON 和文档存在性。
- `scripts/upgrade_workflow.sh` 对新增文件采用 add-only 策略，已有文件不覆盖。
- `scripts/self_test.sh` 覆盖 Workflow V2 文件生成、校验和升级补齐。

兼容策略：

- 旧命令保持可用。
- 升级默认 dry-run。
- 目标项目已有状态、需求、设计、执行计划、测试报告和项目理解文档不覆盖。
- Runtime 留在 kit 中，目标项目只保存配置、trace、eval 结果和文档。

## Runtime 模块

### CLI

入口：

```bash
python3 -m runtime.cli run "给当前项目生成 agent workflow" --target /path/to/project
```

职责：

- 解析命令参数。
- 调用 Runtime pipeline。
- 输出最终报告。
- 返回非零退出码表示执行失败或验证失败。

### Intent Router

识别用户任务类型：

```text
generate_workflow
upgrade_workflow
optimize_workflow
validate_workflow
repair_workflow
explain_workflow
unknown
```

输出示例：

```json
{
  "intent": "generate_workflow",
  "confidence": 0.91,
  "requires_user_input": false,
  "risk_level": "medium"
}
```

第一版优先使用规则实现，后续可接 Prompt 或 LLM。

### Query Rewriter

把自然语言请求改写为结构化任务：

```json
{
  "intent": "generate_workflow",
  "target_path": "/path/to/project",
  "stack": "auto",
  "constraints": ["do_not_overwrite_existing_files"],
  "missing_slots": []
}
```

缺信息时返回：

```json
{
  "requires_user_input": true,
  "missing_slots": ["target_path"],
  "questions": ["请确认目标项目路径。"]
}
```

### Context Builder

读取目标项目现状并生成精简上下文：

```json
{
  "target_path": "/path/to/project",
  "has_workflow": true,
  "detected_stack": "flutter",
  "workflow_version": "2.0",
  "dirty_git": false,
  "recommended_action": "upgrade_workflow"
}
```

第一版读取：

- `pubspec.yaml`
- `package.json`
- `pyproject.toml`
- `requirements.txt`
- `setup.py`
- `AGENTS.md`
- `init.sh`
- `docs/index.md`
- `.agent/config.json`
- `.agent/state/current-task.json`

### Requirement Parser

把任务整理为目标、约束、验收和风险：

```json
{
  "goal": "为目标项目安装 agent workflow",
  "constraints": ["不得覆盖已有文件", "默认使用轻量验证"],
  "acceptance": ["生成必需文件", "validate_target.sh 通过"],
  "risks": ["目标项目已有同名文件时需要转入升级或修复流程"]
}
```

### Workflow Planner

生成可执行步骤：

```json
{
  "steps": [
    {"id": "inspect_target", "action": "inspect_target"},
    {"id": "detect_stack", "action": "detect_stack"},
    {"id": "generate_workflow", "action": "run_generate_script"},
    {"id": "validate_target", "action": "run_validate_script"}
  ]
}
```

### Skill Selector

根据任务选择能力包：

```json
{
  "skill": "agent-workflow",
  "reason": "任务需要生成或升级目标项目 workflow",
  "entrypoints": [
    "scripts/generate_workflow.sh",
    "scripts/upgrade_workflow.sh",
    "scripts/validate_target.sh"
  ]
}
```

第一版只支持 `agent-workflow`，后续再扩展 stack-specific skill。

### Executor

Executor 只做编排，不重新实现脚本逻辑。

映射关系：

- `generate_workflow` -> `scripts/generate_workflow.sh`
- `upgrade_workflow` -> `scripts/upgrade_workflow.sh`
- `validate_workflow` -> `scripts/validate_target.sh`
- `repair_workflow` -> `scripts/upgrade_workflow.sh --apply` 或窄范围补齐

执行记录示例：

```json
{
  "command": "scripts/generate_workflow.sh /path/to/project --stack flutter",
  "exit_code": 0,
  "status": "passed"
}
```

### Validator

Validator 调用已有 `validate_target.sh`，并在 Runtime 层补充结果解析。

校验层级：

- 结构校验：文件存在、JSON 合法、shell 语法合法。
- 行为校验：生成、升级、校验命令是否成功。
- 质量校验：是否覆盖已有状态文件、是否残留模板占位符、是否缺失 V2 元数据。

### Reporter

输出简明报告：

```text
Intent: generate_workflow
Target: /path/to/project
Stack: flutter
Plan: inspect -> generate -> validate
Result: passed
Trace: /path/to/project/.agent/traces/2026-06-01-153000-generate-workflow.json
```

## Trace 与 Badcase

每次 Runtime 执行写入目标项目：

```text
.agent/traces/YYYY-MM-DD-HHMMSS-<intent>.json
```

Trace 结构：

```json
{
  "task_id": "generate-workflow-001",
  "user_request": "给当前项目生成 agent workflow",
  "target_path": "/path/to/project",
  "nodes": [
    {"name": "router", "status": "passed", "output": {}},
    {"name": "context_builder", "status": "passed", "output": {}},
    {"name": "planner", "status": "passed", "output": {}},
    {"name": "executor", "status": "passed", "output": {}},
    {"name": "validator", "status": "passed", "output": {}}
  ],
  "final_status": "passed"
}
```

Badcase 记录到：

```text
docs/process/badcase-analysis.md
docs/reports/eval-report.md
```

Badcase 字段：

- case id
- 用户输入
- 期望结果
- 实际结果
- 失败节点
- 根因
- 修复方式
- 回归验证结果

## Eval 系统

新增：

```text
eval/cases/
eval/fixtures/
eval/reports/
scripts/run_eval.sh
```

Case 示例：

```json
{
  "id": "generate_flutter_workflow",
  "input": "给这个 Flutter 项目生成 agent 工作流",
  "fixture": "flutter_empty_project",
  "expected": {
    "intent": "generate_workflow",
    "stack": "flutter",
    "validation_pass": true
  }
}
```

指标：

- `intent_accuracy`
- `stack_detection_accuracy`
- `slot_filling_accuracy`
- `generation_success_rate`
- `validation_pass_rate`
- `overwrite_protection_pass_rate`
- `regression_count`

命令：

```bash
scripts/run_eval.sh
```

## Prompt Registry

新增：

```text
prompts/intent_router.v1.md
prompts/query_rewriter.v1.md
prompts/requirement_parser.v1.md
prompts/planner.v1.md
prompts/reviewer.v1.md
```

Prompt 文件结构：

```text
# Name
# Version
# Purpose
# Inputs
# Output Schema
# Rules
# Examples
```

第一版 Runtime 可不调用真实 LLM，但 Prompt Registry 要先定义接口和版本管理方式，便于后续接入模型并做回归。

## 测试策略

单元测试：

- Router 意图识别。
- Query Rewriter 缺槽识别。
- Context Builder 技术栈和 workflow 状态识别。
- Planner 步骤生成。
- Skill Selector 能力选择。
- Trace Writer JSON 输出。
- Eval case parser。

集成测试：

- 空 Flutter 项目 -> 生成 -> 校验通过。
- 已有 workflow 项目 -> upgrade dry-run。
- 缺文件 workflow 项目 -> repair 或 upgrade 补齐。
- 非法 `.agent/state/current-task.json` -> 校验失败。
- 已有 V2 配置 -> upgrade 不覆盖。

回归测试：

```bash
scripts/self_test.sh
scripts/run_eval.sh
```

## 里程碑

### M1：Workflow V2 模板

- 新增 V2 模板文件。
- 更新 `generate_workflow.sh`。
- 更新 `validate_target.sh`。
- 更新 `upgrade_workflow.sh`。
- 更新 `self_test.sh`。
- 更新 `README.md` 和 `docs/template-variables.md`。

完成标准：`scripts/self_test.sh` 通过。

### M2：Runtime MVP

- 新增 `runtime/cli.py`、`models.py`、`router.py`、`context_builder.py`、`executor.py`、`validator.py`、`trace.py`、`reporter.py`。
- 支持自然语言入口。
- 支持 generate / upgrade / validate 基础路由。
- 写入 trace。

完成标准：Runtime 能对临时目标项目完成生成、校验和 trace 写入。

### M3：Query Rewrite 与 Planner

- 新增 `query_rewriter.py`、`requirement_parser.py`、`planner.py`、`skill_selector.py`。
- 支持 missing slot。
- 支持结构化计划。
- 支持 skill 选择原因记录。

完成标准：eval 中首次生成、已有升级、缺信息追问 case 通过。

### M4：Eval 与 Badcase

- 新增 `eval/cases`、`fixtures`、`reports`。
- 新增 `scripts/run_eval.sh`。
- 新增 badcase 文档和报告模板。

完成标准：至少 10 个 eval case 通过，并输出指标报告。

### M5：Prompt Registry 与作品化文档

- 新增 `prompts/*.v1.md`。
- 新增架构文档、上下文工程文档、skills 文档、eval 文档。
- 新增 `docs/interview/20-questions-project-mapping.md`。
- 更新 README。

完成标准：项目能清晰展示架构、使用方式、评估方式和 20 问能力映射。

## 开发任务列表

- [ ] M1-1 新增 Workflow V2 目标项目模板。
- [ ] M1-2 更新生成脚本输出列表与模板渲染。
- [ ] M1-3 更新目标项目校验逻辑。
- [ ] M1-4 更新升级脚本 add-only 列表。
- [ ] M1-5 更新自测覆盖 V2 文件。
- [ ] M1-6 更新 README 与模板变量文档。
- [ ] M2-1 新增 Runtime 数据模型与 CLI。
- [ ] M2-2 实现 Intent Router 基础规则。
- [ ] M2-3 实现 Context Builder。
- [ ] M2-4 实现 Executor 调用现有脚本。
- [ ] M2-5 实现 Validator 与 Reporter。
- [ ] M2-6 实现 Trace Writer。
- [ ] M3-1 实现 Query Rewriter。
- [ ] M3-2 实现 Requirement Parser。
- [ ] M3-3 实现 Workflow Planner。
- [ ] M3-4 实现 Skill Selector。
- [ ] M4-1 新增 eval case schema 与 fixture。
- [ ] M4-2 实现 `scripts/run_eval.sh`。
- [ ] M4-3 新增 badcase 分析文档和报告模板。
- [ ] M5-1 新增 Prompt Registry 初版。
- [ ] M5-2 新增架构与作品化文档。
- [ ] M5-3 更新 README 的新架构说明。

## 风险与控制

- 范围膨胀：先完成 CLI 和 Eval，不做 GUI。
- 破坏已有项目：升级默认 dry-run，新增文件 add-only。
- Runtime 与脚本职责重复：Runtime 只编排，脚本继续做确定性执行。
- Eval 流于形式：每个 case 必须声明 expected intent、stack、validation result。
- Prompt 调优互相影响：先加 eval case，再改 Prompt，最后跑全量回归。

## 完成定义

完整升级完成时应满足：

- 旧脚本用法继续可用。
- 目标项目可生成 Workflow V2 文件。
- Runtime CLI 可完成生成、升级、校验基础链路。
- 每次 Runtime 执行有 trace。
- Eval 至少覆盖 10 个关键 case。
- Badcase 能定位到 router、context、planner、executor 或 validator。
- `scripts/self_test.sh` 与 `scripts/run_eval.sh` 通过。
- README 和架构文档能解释项目如何支撑 Agent 架构、上下文工程、skills、评估和 badcase 闭环。
