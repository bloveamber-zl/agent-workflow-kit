# 20 问能力映射

本项目适合包装为“面向 Coding Agent 的轻量 Workflow Runtime + Skills + Eval/Badcase 闭环”作品。

## 强支撑

- 架构选型：自研轻量 workflow，不是 LangGraph。
- 单/多 Agent：用 Router、Parser、Planner、Validator 等多角色节点拆分认知任务。
- 首次生成和多轮补充：generate、upgrade、repair、validate 路由区分。
- Prompt 和上下文工程：Prompt Registry、Context Builder、文件化上下文。
- 查询改写：Query Rewriter 和 missing slot。
- Skills：Codex skill 与 Runtime Skill Selector。
- 效果评估：`scripts/run_eval.sh`、eval cases 和指标报告。
- Badcase 定位：trace、badcase-analysis、节点级失败归因。
- Prompt 回归：Prompt 版本化 + eval 回归。

## 弱支撑

- SFT、vLLM、KV Cache、continuous batching：当前项目只覆盖 Agent 应用层，不做底层推理服务。
- 代码覆盖率插桩和 Mock：可通过 runtime 单测展示工程能力，但不是本项目主线。
- TUI 视频剪辑：建议作为单独作品，不放进本项目。

## 推荐表述

> 我把一个 workflow 模板生成器升级成轻量 Agent Workflow Runtime。它支持自然语言任务路由、上下文构建、需求结构化、计划生成、Skill 选择、脚本执行、验证闭环、Trace 回放和 Eval 回归，用于解决 Coding Agent 长任务、多轮补充、上下文丢失和 badcase 定位问题。
