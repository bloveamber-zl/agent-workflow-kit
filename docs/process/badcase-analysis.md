# Badcase 分析流程

本文件用于 `agent-workflow-kit` 自身的 Runtime、Router、Planner、Executor、Validator 和 Eval badcase 复盘。目标项目生成的同名模板用于项目级记录。

## 记录模板

```text
## Case ID

- 用户输入：
- 目标项目 fixture：
- 期望结果：
- 实际结果：
- 失败节点：router / query_rewriter / context_builder / planner / skill_selector / executor / validator / reporter
- 根因分类：规则缺失 / Prompt 不稳 / 上下文不足 / 脚本失败 / 校验不足 / 用户信息缺失
- 修复方式：规则 / Prompt / 代码 / 文档 / eval case
- 回归验证：
```

## 定位顺序

1. 先看 `eval/reports/latest.json`，确认失败 case 和指标变化。
2. 找对应 case 的输入、fixture 和 expected 字段。
3. 如果 Runtime 已生成目标项目 trace，查看 `.agent/traces/*.json` 的最早失败节点。
4. 对比失败节点输入、输出和预期。
5. 先补或修 eval case，再修改规则、Prompt 或代码。
6. 修复后运行 `scripts/run_eval.sh` 和 `scripts/self_test.sh`。

## 调优原则

- 能用确定性规则解决的问题，不优先交给 Prompt。
- 修改 Prompt 前先确认是否缺上下文、缺 schema 或缺 eval case。
- 单个 badcase 修复不能牺牲已有通过场景。
- 每次新增能力至少增加一个正向 case；每次修复 badcase 至少增加一个回归 case。
