# 使用指南

## 目标

把统一的 agent 工作流安装到任意项目中，让后续 coding agent 可以只依赖仓库文件恢复上下文、解析需求、了解项目、生成开发文档、执行计划、运行验证并交接。

## 标准流程

```bash
scripts/generate_workflow.sh /path/to/project --stack flutter
cd /path/to/project
./init.sh
```

如果目标项目已有同名文件，生成器会停止并提示冲突文件。确认要重建时再使用 `--force`。

## 可选增强

Flutter 项目可按需生成 Patrol 验收或 HarmonyOS/Flutter-OH 依赖适配支持；任何项目都可按需生成 CodeGraph 或 Open Design 说明文件。非交互环境建议显式传环境变量，避免默认跳过：

```bash
AGENT_WORKFLOW_PATROL=yes scripts/generate_workflow.sh /path/to/project --stack flutter
AGENT_WORKFLOW_HARMONYOS=yes scripts/generate_workflow.sh /path/to/project --stack flutter
AGENT_WORKFLOW_CODEGRAPH=yes scripts/generate_workflow.sh /path/to/project --stack node
AGENT_WORKFLOW_OPENDESIGN=yes scripts/generate_workflow.sh /path/to/project --stack node
```

HarmonyOS 增强生成 `docs/platforms/harmonyos.md`、依赖兼容台账、验收说明和 `scripts/harmonyos_acceptance.sh`。它只提供可复现的项目级入口；每个原生插件仍须在真实设备上留下构建与关键路径证据。需要 Fork 时在自有仓库维护，禁止修改 `pub-cache`。

Open Design 仅生成 `docs/tools/opendesign.md` 和配置记录，不会静默安装 MCP。Codex 侧接入按 Open Design 官方 installer 执行：

```bash
od mcp install codex --print
od mcp install codex
codex mcp list
```

即使启用该文档，agent 也只能在用户明确要求使用 Open Design、生成设计稿/视觉稿或按 Open Design 设计稿生成代码时调用它。

## 主动功能入口

生成后的项目会附带 `docs/workflow-capabilities.md`，用来说明当前工作流已启用的主动功能、触发方式、默认目标和输出位置。

当前已落地的主动功能包括：

- `进行项目深度扫描并回填`：由 Agent 调用 `scripts/recon_project.sh`，扫描当前项目并补充 `docs/project/*`；默认只补充缺失信息，不改已有描述，若会改动现有文字结论则应先询问用户。
- `校验当前工作流`：校验 workflow 文件完整性与 JSON/脚本合法性。
- `同步当前工作流到最新版`：执行升级 dry-run 或 apply。
- `修复当前工作流` / `补齐当前工作流`：补齐缺失或损坏的 workflow 文件。
- `需要测试用例`：对当前需求启用开发前模式，先确认用例、生成自动化测试，再开发和复测。
- `根据需求生成测试用例并执行测试`：对已开发需求启用开发后模式，按原始需求直接验证现有实现。
- `适配鸿蒙` / `检查鸿蒙依赖`：已启用 HarmonyOS 支持时，维护依赖台账并按项目配置执行逐库验收。

测试用例驱动验证默认关闭且不主动提醒。详细格式、人工降级和完成门禁见 `docs/test-cases/README.md`。

生成设计稿时必须合入质量提示词：真实产品级、行业识别明确、信息模块场景化、禁止泛用 AI/SaaS 仪表盘、渐变光斑、空泛文案和大卡片堆叠。生成后需要记录质感、去 AI 味、行业识别度、信息密度和可实现性评分；核心项低于 4/5 时应重新生成或迭代。若设计稿需要额外素材，可在用户确认后调用 `$openai-image-gateway`，并优先生成单张素材板再拆分，减少按张计费。

## 同步已有项目

修改 `agent-workflow-kit` 的模板后，优先用半自动升级脚本同步已有项目。默认 dry-run，只打印计划：

```bash
# 单项目预览
scripts/upgrade_workflow.sh /path/to/project

# 单项目应用
scripts/upgrade_workflow.sh /path/to/project --apply

# 批量扫描 ~/project 并预览
scripts/upgrade_all_workflows.sh

# 批量应用
scripts/upgrade_all_workflows.sh --apply
```

升级脚本会自动检测技术栈，也可以显式指定：

```bash
scripts/upgrade_workflow.sh /path/to/project --stack flutter --apply
scripts/upgrade_all_workflows.sh ~/project --stack flutter
```

半自动模式会更新通用工作流入口、验证说明和失败归因说明，但不会覆盖项目状态、需求、计划、测试证据和项目理解文档。已有的 `.agent/state/current-task.json`、`.agent/traces/README.md`、`docs/coding-progress.md`、`docs/feature_list.json`、`docs/project/`、`docs/requirements/`、`docs/design/`、`docs/exec-plans/`、`docs/reports/test-report.md` 会保留；缺失时才补模板文件。

升级脚本内部会把模板中的项目根目录渲染为真实目标路径，而不是临时生成目录。

升级脚本会刷新 `.gitignore` 中的 `agent-workflow-kit` 忽略块。动态生成的工作流文档目录（如 `docs/requirements/`、`docs/design/`、`docs/exec-plans/`、`docs/reports/`）使用目录级忽略，避免后续新增文档漏出。

## 轻量运行时状态

生成后的项目包含：

- `.agent/state/current-task.json`：记录当前任务状态、关联需求、设计文档、执行计划、改动文件、验证记录和 blocker。
- `docs/test-cases/README.md`：显式触发的测试用例驱动流程；需求级用例按 `docs/test-cases/<requirement-id>.md` 保存。
- `.agent/config.json`：记录 workflow 版本、技术栈、trace 开关和默认覆盖策略。
- `.agent/traces/README.md`：说明如何保存轻量任务轨迹。
- `.agent/traces/schema.json`：约定 Runtime trace 的 JSON 结构。
- `.agent/evals/README.md`：说明目标项目如何记录专属 eval 或 badcase 复测事实。
- `docs/process/failure-taxonomy.md`：统一失败归因类型。
- `docs/process/badcase-analysis.md`：定位 Agent 链路 badcase 的记录流程。
- `docs/reports/eval-report.md`：目标项目级 eval 和 badcase 回归记录。

`current-task.json` 的 `status` 只允许：

```text
intake
understanding
designing
planning
approved
implementing
verifying
done
blocked
```

`scripts/validate_target.sh` 会检查这些文件存在、JSON 合法，并验证状态值是否在允许集合内。

## 通过 Codex Skill 使用

本仓库提供 `agent-workflow` skill 源码，可安装到本机 Codex：

```bash
scripts/install_codex_skill.sh
```

安装后在任意目标项目中让 Codex 使用 `$agent-workflow`。Skill 会：

- 默认把当前目录作为目标项目。
- 按项目文件自动判断技术栈。
- 无工作流时调用 `scripts/generate_workflow.sh`。
- 已有工作流时先读取现状，再做窄范围优化。
- 修改后调用 `scripts/validate_target.sh` 校验。

## 技术栈选择

- Flutter：选择 `--stack flutter`
- Node：选择 `--stack node`
- Python：选择 `--stack python`
- 其他：选择 `--stack generic`，生成后手动改 `init.sh` 中的命令

## 适配建议

- 先跑轻量验证，再考虑严格分析或完整测试。
- 构建、签名、发布等耗时或高风险命令不要放进默认 `./init.sh`。
- 平台构建文档可以单独写在目标项目的 `docs/build_*.md`。
- 私有路径、账号、密钥不要写进模板。

## 文档分层

生成后的文档按渐进披露组织：

- `docs/index.md`：阅读路由器。
- `.agent/state/current-task.json`：机器可读的当前任务状态。
- `.agent/config.json`：机器可读的 workflow 元数据。
- `.agent/traces/`：轻量任务轨迹。
- `.agent/evals/`：目标项目级评估说明或本地评估输入。
- `docs/feature_list.json`：项目级需求索引。
- `docs/coding-progress.md`：会话级进度日志。
- `docs/project/`：项目理解、特定规则、限制、验证事实和风险。
- `docs/requirements/`：解析后的需求、待确认问题和追踪矩阵。
- `docs/design/`：结合当前项目后的开发文档。
- `docs/exec-plans/active/`：用户确认后的执行计划和步骤状态。
- `docs/reports/test-report.md`：测试、失败、修复和复测记录。
- `docs/reports/eval-report.md`：Agent workflow 评估和 badcase 回归记录。

需求实现时不要把详细步骤写进 `feature_list.json`，也不要把完整计划写进 `coding-progress.md`；它们只负责索引和最近状态。
