# 主动功能使用说明

## 什么时候读

想知道当前工作流能主动执行什么动作、怎么触发、默认作用到哪里时读取。

## 当前项目概况

- 项目名称：`agent-workflow-kit`
- 项目根目录：`/Users/Lin/project/agent-workflow-kit`
- 技术栈：`generic`
- 默认目标：当前工作目录所在项目。

## 主动功能

| 功能 | 状态 | 对话触发方式 | 默认目标 | 产出 |
| --- | --- | --- | --- | --- |
| 项目深度扫描并回填 | enabled | `进行项目深度扫描并回填` | 当前工作目录项目 | `docs/project/*`、`.agent/traces/*-recon-project.json` |
| 校验当前工作流 | enabled | `校验当前工作流` | 当前工作目录项目 | 运行 `scripts/validate_target.sh` |
| 同步当前工作流到最新版 | enabled | `同步当前工作流到最新版` | 当前工作目录项目 | 工作流升级 dry-run 或 apply |
| 修复或补齐当前工作流 | enabled | `修复当前工作流` / `补齐当前工作流` | 当前工作目录项目 | 补齐缺失 workflow 文件 |
| 测试用例驱动验证 | planned | `需要测试用例` / `根据需求生成测试用例并执行测试` | 当前需求 | `docs/test-cases/<requirement-id>.md`、自动化测试与验收证据 |
| Patrol 验收 | disabled | `用 Patrol 验证这个需求` | 当前需求 | `docs/testing/patrol.md`、验收证据 |
| CodeGraph 影响分析 | disabled | `用 CodeGraph 做影响分析` | 当前需求 | `docs/tools/codegraph.md` 指引与分析证据 |
| Open Design 设计链路 | enabled | `用 Open Design 生成设计稿` | 当前需求 | `docs/tools/opendesign.md` 指引与设计证据 |

## 项目深度扫描默认策略

- 默认只补充缺失信息，不改已有描述。
- 如果扫描结论会改动现有文字描述，应先向用户确认。
- 脚本入口：`scripts/recon_project.sh <target-project-path>`；在对话里优先通过 Agent 触发。

## 测试用例驱动验证

- 当前状态：`planned`，设计已确认，尚未完成 Runtime、模板和验证链路实现。
- 默认关闭：未明确提出测试用例要求时，不启用、不提醒，继续使用项目默认验证配置。
- 开发前模式：需求解析后生成测试用例，用户确认后先生成自动化测试，再开发并复测。
- 开发后模式：用户提供已完成需求时，根据原始需求生成测试用例，确认后直接生成并运行测试。
- 需求依据：测试目标来自原始需求和验收标准，不能根据现有实现反向削弱断言。
- 人工降级：无法自动化时记录原因、步骤、环境、证据和剩余风险，可人工验收完成。
- 主要产出：`docs/test-cases/<requirement-id>.md`、自动化测试文件、`docs/reports/test-report.md` 和验收证据。
- 详细设计：`docs/superpowers/specs/2026-07-10-opt-in-test-case-first-workflow-design.md`。

## 最近一次项目深度扫描

<!-- BEGIN AUTO-RECON:capabilities -->
- 最近扫描时间：`2026-07-10 12:02:44`
- 回填结果：`成功`
- 影响文件：`docs/project/structure/overview.md`, `docs/project/structure/architecture.md`, `docs/project/features/overview.md`, `docs/project/frontend.md`, `docs/project/constraints.md`
- 冲突摘要：无。
<!-- END AUTO-RECON:capabilities -->

## 文档路由

| 场景 | 读取 |
| --- | --- |
| 看项目结构 | `docs/project/structure/overview.md` |
| 看架构边界 | `docs/project/structure/architecture.md` |
| 看功能模块 | `docs/project/features/overview.md` |
| 看项目规则 | `docs/project/constraints.md` |
| 看 UI/交互约定 | `docs/project/frontend.md` |
