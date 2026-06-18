# 上下文工程

本项目采用文件化上下文工程，避免把所有历史和文件一次性塞给模型或 Runtime。

## 分层

- `AGENTS.md`：入口规则和路由。
- `.agent/config.json`：workflow 版本、技术栈、trace 开关和覆盖策略。
- `.agent/state/current-task.json`：当前任务状态。
- `.agent/traces/`：节点级执行事实。
- `docs/feature_list.json`：需求索引。
- `docs/requirements/`：需求、疑问和追踪矩阵。
- `docs/design/`：设计文档。
- `docs/exec-plans/`：执行计划。
- `docs/reports/`：测试、eval 和 badcase 证据。

## Context Builder

`runtime/context_builder.py` 只读取当前决策需要的事实：

- 技术栈标识文件。
- 是否已有 workflow。
- workflow 版本。
- Git 工作树是否有改动。

这样可以降低上下文噪声，并让路由、规划和 badcase 定位更稳定。
