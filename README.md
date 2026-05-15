# agent-workflow-kit

可复用的 agent 工作流生成器。它把一套长期运行 coding agent 需要的文件生成到目标项目中：

- `AGENTS.md`
- `init.sh`
- `docs/index.md`
- `docs/verification.md`
- `docs/process/verification.md`
- `docs/acceptance_simulator.md`
- `docs/coding-progress.md`
- `docs/feature_list.json`
- `docs/session-handoff.md`
- `docs/project/`：项目理解、规则、限制、验证事实和前端约束
- `docs/requirements/`：解析后的需求、待确认问题和需求追踪矩阵
- `docs/design/`：结合项目现状后的开发文档
- `docs/exec-plans/`：active/completed 执行计划和技术债
- `docs/reports/test-report.md`
- `scripts/acceptance_simulator.sh`

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

默认不会覆盖目标项目已有文件。确实需要覆盖时：

```bash
scripts/generate_workflow.sh /path/to/project --stack flutter --force
```

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
4. 如果验证失败，把失败原因记录到 `docs/reports/test-report.md`、当前 active plan 和 `docs/coding-progress.md`。
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
- `docs/coding-progress.md`：会话级进度日志，不替代 active plan。
- `docs/requirements/traceability.md`：需求、步骤、实现和测试证据的追踪矩阵。
- `docs/exec-plans/active/*.md`：开发步骤、当前状态、验证和证据。
- `docs/project/constraints.md`：项目特定规则、编码约定、安全限制和风险。

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
scripts/              生成、校验、自测脚本
docs/                 模板变量和使用说明
examples/             预留示例目录
```

## 验证本项目

```bash
scripts/self_test.sh
```
