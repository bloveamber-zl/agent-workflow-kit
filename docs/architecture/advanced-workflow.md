# 高级工作流需求评估

## 结论

暂不实现独立的高级工作流。

当前项目始终是工作流生成器，目标是把一套通用 agent 工作流生成到目标项目中。用户当前不需要接入外部工单、自动抢单、平台 API、后台 worker 或任务队列；在这个前提下，现有基础工作流已经能覆盖“需求输入到研发闭环”的主要场景。

因此本阶段不新增 `AGENT_WORKFLOW_ADVANCED` 开关，也不新增 `docs/workflows/issue-to-pr.md` 模板。

## 判断依据

当前基础工作流已经支持：

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
-> 更新追踪矩阵
-> 交接
```

对应生成物已经存在：

```text
docs/requirements/parsed-requirements.md
docs/requirements/open-questions.md
docs/feature_list.json
docs/design/
docs/exec-plans/active/
docs/process/verification.md
docs/reports/test-report.md
docs/session-handoff.md
docs/requirements/traceability.md
```

如果用户只是给出普通需求、bug 描述或功能改动，这些文件已经足够支撑完整研发闭环。

## 不做的内容

本项目不实现以下能力：

- 自动抢单。
- 自动扫描任务池。
- 后台 worker。
- 工单系统。
- 任务队列。
- GitHub、Linear、Jira API 集成。
- 自动回填远端工单。
- 自动创建或 merge PR。
- 独立的 `docs/workflows/issue-to-pr.md` 高级入口。
- `AGENT_WORKFLOW_ADVANCED` 生成开关。

## 曾考虑过的方案

曾考虑新增一个可选高级入口：

```text
docs/workflows/issue-to-pr.md
```

它的定位是把外部 Issue、工单或 PR 描述路由到现有需求、计划、验证和交接文件。

但在不接入外部工单的前提下，这个入口的新增价值较低，且容易造成以下问题：

- 与现有需求解析、执行计划、验证和交接文档重复。
- 让基础工作流看起来像工单处理流程。
- 增加生成、升级、校验和自测复杂度。
- 诱导后续继续扩展平台接入能力，偏离工作流生成器定位。

## 当前推荐方向

保持现有基础工作流，不新增高级工作流功能。

后续如果需要增强，应优先优化已有文件，而不是新增并行流程：

- 优化 `docs/requirements/parsed-requirements.md.template` 的需求字段表达。
- 优化 `docs/exec-plans/active/workflow-bootstrap.md.template` 的步骤状态说明。
- 优化 `docs/process/verification.md.template` 的验证等级和复核规则。
- 优化 `docs/session-handoff.md.template` 的交接摘要结构。
- 在 README 和 usage 中更清楚地说明“当前基础流程已经支持完整研发闭环”。

## 重新评估条件

只有出现以下明确需求时，才重新考虑高级工作流：

- 目标项目需要把外部 Issue、Linear 或 Jira 工单规范化导入现有工作流。
- 用户需要标准 PR 描述草稿模板，并且现有交接文档无法承载。
- 多个目标项目重复出现“外部工单到 PR 草稿”的相同需求。
- 仍然保持只生成文档和模板，不实现平台 API 或后台服务。

在这些条件出现前，高级工作流保持不立项。
