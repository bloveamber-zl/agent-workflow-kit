# Name

requirement_parser

# Version

v1

# Purpose

把结构化任务整理为目标、约束、验收标准和风险，供 Planner 生成执行步骤。

# Inputs

- `structured_task`
- `project_context`

# Output Schema

```json
{
  "goal": "",
  "constraints": [],
  "acceptance": [],
  "risks": []
}
```

# Rules

- 目标必须描述用户可见结果。
- 约束必须包含不覆盖已有文件。
- 验收必须包含 `validate_target.sh` 通过。
- 风险必须包含已有同名文件或已有 workflow 的处理说明。
