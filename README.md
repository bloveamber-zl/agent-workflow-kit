# agent-workflow-kit

可复用的 agent 工作流生成器。它把一套长期运行 coding agent 需要的文件生成到目标项目中：

- `AGENTS.md`
- `init.sh`
- `.agent/state/current-task.json`
- `.agent/config.json`
- `.agent/traces/README.md`
- `.agent/traces/schema.json`
- `.agent/evals/README.md`
- `docs/index.md`
- `docs/verification.md`
- `docs/process/verification.md`
- `docs/process/failure-taxonomy.md`
- `docs/process/badcase-analysis.md`
- `docs/acceptance_simulator.md`
- `docs/testing/patrol.md`：Flutter 项目选择 Patrol 验收支持时生成
- `docs/tools/opendesign.md`：选择 Open Design 可选增强时生成，只在用户明确要求 Open Design 时使用
- `docs/coding-progress.md`
- `docs/feature_list.json`
- `docs/session-handoff.md`
- `docs/project/`：项目理解、规则、限制、验证事实和前端约束
- `docs/requirements/`：解析后的需求、待确认问题和需求追踪矩阵
- `docs/design/`：结合项目现状后的开发文档
- `docs/exec-plans/`：active/completed 执行计划和技术债
- `docs/reports/eval-report.md`
- `docs/reports/test-report.md`
- `scripts/acceptance_simulator.sh`
- `scripts/patrol_acceptance.sh`：Flutter 项目选择 Patrol 验收支持时生成

生成或升级工作流时，脚本会在目标项目 `.gitignore` 中写入 `agent-workflow-kit` 忽略块，默认不把这些工作流文件纳入版本管理。`docs/requirements/`、`docs/design/`、`docs/exec-plans/`、`docs/reports/` 等动态文档目录使用目录级忽略，后续新增文档也会自动忽略。

初始化时会根据目标项目的常见目录和配置文件，自动填充 `docs/project/structure/overview.md`、`docs/project/structure/architecture.md`、`docs/project/features/overview.md`、`docs/project/frontend.md` 和 `docs/project/constraints.md` 的基础项目地图；业务定位和领域细节仍需在后续任务中补充。

## 使用方式

```bash
cd /Users/Lin/project/agent-workflow-kit

# 给一个 Flutter 项目生成工作流
scripts/generate_workflow.sh /path/to/project --stack flutter

# 给 Node 项目生成工作流
scripts/generate_workflow.sh /path/to/project --stack node

# 给 Python 项目生成工作流
scripts/generate_workflow.sh /path/to/project --stack python

# 通用项目
scripts/generate_workflow.sh /path/to/project --stack generic
```

也可以通过轻量 Runtime 使用自然语言入口：

```bash
python3 -m runtime.cli run "给这个项目生成 agent workflow" --target /path/to/project
```

Runtime 会识别 intent、检测技术栈、调用底层脚本、运行校验，并把执行轨迹写入目标项目 `.agent/traces/`。

Flutter 项目初始化或升级时，脚本会在交互式终端询问是否生成 Patrol 验收支持文件。非交互环境默认跳过，可用环境变量控制：

```bash
AGENT_WORKFLOW_PATROL=ask scripts/generate_workflow.sh /path/to/project --stack flutter
AGENT_WORKFLOW_PATROL=yes scripts/generate_workflow.sh /path/to/project --stack flutter
AGENT_WORKFLOW_PATROL=no scripts/generate_workflow.sh /path/to/project --stack flutter
```

初始化或升级时也可以生成 CodeGraph 可选增强说明。该流程只生成 `docs/tools/codegraph.md` 和配置记录，不会静默安装 CodeGraph：

```bash
AGENT_WORKFLOW_CODEGRAPH=ask scripts/generate_workflow.sh /path/to/project --stack node
AGENT_WORKFLOW_CODEGRAPH=yes scripts/generate_workflow.sh /path/to/project --stack node
AGENT_WORKFLOW_CODEGRAPH=no scripts/generate_workflow.sh /path/to/project --stack node
```

初始化或升级时也可以生成 Open Design 可选增强说明。该流程只生成 `docs/tools/opendesign.md` 和配置记录；Open Design 仍只能在用户明确要求使用 Open Design、生成设计稿/视觉稿或按 Open Design 设计稿生成代码时调用：

```bash
AGENT_WORKFLOW_OPENDESIGN=ask scripts/generate_workflow.sh /path/to/project --stack node
AGENT_WORKFLOW_OPENDESIGN=yes scripts/generate_workflow.sh /path/to/project --stack node
AGENT_WORKFLOW_OPENDESIGN=no scripts/generate_workflow.sh /path/to/project --stack node
```

默认不会覆盖目标项目已有文件。确实需要覆盖时：

```bash
scripts/generate_workflow.sh /path/to/project --stack flutter --force
```

## 同步已有项目

如果修改了本仓库的工作流模板，可用半自动升级脚本同步到已有项目。默认只预览，不写文件：

```bash
# 预览单个项目会更新哪些工作流文件
scripts/upgrade_workflow.sh /path/to/project

# 确认后应用
scripts/upgrade_workflow.sh /path/to/project --apply

# 扫描 ~/project 下已安装工作流的项目并预览
scripts/upgrade_all_workflows.sh

# 确认后批量应用
scripts/upgrade_all_workflows.sh --apply
```

半自动升级会刷新通用入口文件，例如 `AGENTS.md`、`init.sh`、`docs/index.md`、验证说明、失败归因说明和 `scripts/acceptance_simulator.sh`。项目状态、trace、eval 和项目适配文件只补缺失，不覆盖已有内容，例如 `.agent/state/current-task.json`、`.agent/config.json`、`.agent/traces/`、`.agent/evals/`、`docs/coding-progress.md`、`docs/feature_list.json`、`docs/requirements/`、`docs/design/`、`docs/exec-plans/`、`docs/reports/` 和 `docs/project/`。

如果 Flutter 项目选择 Patrol 支持，升级脚本会额外生成或刷新 `docs/testing/patrol.md` 和 `scripts/patrol_acceptance.sh`。如果选择 CodeGraph 支持，会生成或刷新 `docs/tools/codegraph.md`。如果选择 Open Design 支持，会生成或刷新 `docs/tools/opendesign.md`。

升级脚本应用变更时也会补齐或刷新 `.gitignore` 的 workflow 忽略块；已存在旧的文件级规则时会替换为当前目录级规则。

## 轻量 Agent Runtime Harness

生成后的项目会包含一组轻量运行时文件，用于让 agent 任务可恢复、可检查、可复盘：

- `.agent/state/current-task.json`：机器可读的当前任务状态，状态值固定为 `intake`、`understanding`、`designing`、`planning`、`approved`、`implementing`、`verifying`、`done`、`blocked`。
- `.agent/config.json`：机器可读的 workflow 元数据，记录版本、技术栈、trace 开关、覆盖策略和可选增强状态。
- `.agent/traces/README.md`：轻量 trace 约定，记录目标、读写文件、工具调用、验证命令、失败和下一步。
- `.agent/traces/schema.json`：Runtime trace 的 JSON 结构约定，便于后续回放和 badcase 定位。
- `.agent/evals/README.md`：目标项目级评估记录说明，通用评估集仍由本仓库维护。
- `docs/process/failure-taxonomy.md`：失败归因分类，用于把 blocker 和验证失败沉淀为可复盘事实。
- `docs/process/badcase-analysis.md`：定位 Agent 链路 badcase 的记录流程。
- `docs/reports/eval-report.md`：目标项目级 eval 和 badcase 回归记录。

这不是完整 tracing 平台，不接数据库或外部观测系统；它只保证关键信息进入仓库文件，方便下一轮 agent 恢复上下文。

`.agent/config.json` 的版本字段分三层：`workflow_version` 表示结构协议版本，`template_revision` 表示模板修订号，`kit_version` 表示生成器版本。每次工作流模板、生成行为或同步规则变动时，更新 `templates/VERSION`；生成器能力变动时同步更新根目录 `VERSION`。

## Runtime 与 Eval

本仓库内置轻量 Runtime，不复制到目标项目：

- `runtime/router.py`：识别生成、升级、修复、校验、解释等 intent。
- `runtime/context_builder.py`：读取目标项目技术栈、workflow 状态和版本。
- `runtime/query_rewriter.py`：把用户请求改写为结构化任务，并识别缺失槽位。
- `runtime/planner.py`：生成可执行 workflow 步骤。
- `runtime/skill_selector.py`：选择 `agent-workflow` skill 和脚本入口。
- `runtime/executor.py`、`runtime/validator.py`：调用现有脚本执行和校验。
- `runtime/trace.py`：写入节点级 trace，便于 badcase 定位。

离线评估入口：

```bash
scripts/run_eval.sh
```

评估 case 位于 `eval/cases/`，fixture 位于 `eval/fixtures/`，报告输出到 `eval/reports/latest.json`。

## 安装 Codex Skill

如果希望在其他项目中通过 Codex skill 落地或优化这套工作流：

```bash
scripts/install_codex_skill.sh
```

安装后在目标项目里请求 Codex 使用 `$agent-workflow`。Skill 会默认以当前目录为目标项目，自动判断 `flutter`、`node`、`python` 或 `generic`，并调用本仓库的生成和校验脚本。

## 生成后要做什么

1. 打开目标项目的 `AGENTS.md`，确认项目根目录、验证命令和构建说明。
2. 运行目标项目的 `./init.sh`。
3. 按 `docs/index.md` 的路由读取 `docs/verification.md`、`docs/process/verification.md` 和当前 active plan。
4. 如果验证失败，按 `docs/process/failure-taxonomy.md` 归因，并把失败原因记录到 `docs/reports/test-report.md`、当前 active plan 和 `docs/coding-progress.md`。
5. 后续需求先进入 `docs/requirements/parsed-requirements.md` 和 `docs/feature_list.json`，再生成 design doc 与 active plan。

## 需求驱动流程

生成后的目标项目支持这条闭环：

```text
需求解析
-> 项目侦察
-> 需求适配分析
-> 开发文档
-> 执行计划
-> 用户确认
-> 开发
-> 按需求验证
-> 修复复测
-> 更新步骤状态和追踪矩阵
```

职责分工：

- `docs/feature_list.json`：项目级需求索引和路由表，不写详细步骤。
- `.agent/state/current-task.json`：机器可读的当前任务状态，不替代 active plan。
- `.agent/traces/`：长任务或失败复盘的轻量事实记录。
- `docs/coding-progress.md`：会话级进度日志，不替代 active plan。
- `docs/requirements/traceability.md`：需求、步骤、实现和测试证据的追踪矩阵。
- `docs/exec-plans/active/*.md`：开发步骤、当前状态、验证和证据。
- `docs/project/constraints.md`：项目特定规则、编码约定、安全限制和风险。

验收阶段按 L0-L4 自动判定验证强度。需求澄清、PRD、拆任务、TDD、诊断、架构巡检、E2E/Patrol 和交接作为按场景触发的增强能力，不进入每个需求的固定步骤；触发或跳过原因写入 active plan、追踪矩阵或测试报告。新增或生成测试用例时，先做测试用例自验证，再用测试验证代码。

## 内置技术栈

- `generic`：通用项目，命令以提示为主。
- `flutter`：Flutter 项目，默认轻量运行 `flutter analyze --no-pub --no-fatal-infos --no-fatal-warnings`。
- `node`：Node 项目，默认使用 `npm run lint --if-present`、`npm test --if-present`。
- `python`：Python 项目，默认使用 `python3 -m compileall .`、`python3 -m pytest`。

## 项目结构

```text
templates/base/       通用模板
templates/stacks/     技术栈变量
skills/               Codex skill 源码
runtime/              轻量 workflow 编排 Runtime
prompts/              Prompt Registry 初版
eval/                 离线评估 case、fixture 和报告
scripts/              生成、校验、自测脚本
docs/                 模板变量和使用说明
examples/             预留示例目录
```

## 验证本项目

```bash
scripts/self_test.sh
```

单独运行 Runtime / Eval 验证：

```bash
python3 -m unittest tests.runtime.test_runtime_mvp
python3 -m unittest tests.runtime.test_planning_components
python3 -m unittest tests.runtime.test_eval_runner
scripts/run_eval.sh
```
