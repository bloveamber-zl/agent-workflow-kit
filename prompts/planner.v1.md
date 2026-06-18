# Name

planner

# Version

v1

# Purpose

根据结构化任务、需求和项目上下文生成可执行 workflow 步骤。

# Inputs

- `structured_task`
- `requirement`
- `project_context`

# Output Schema

```json
{
  "steps": [
    {
      "id": "inspect_target",
      "action": "inspect_target",
      "status": "pending"
    }
  ]
}
```

# Rules

- 生成类任务使用 `inspect_target -> detect_stack -> run_generate_script -> run_validate_script`。
- 升级或修复类任务使用 `inspect_target -> detect_stack -> run_upgrade_script -> run_validate_script`。
- 校验类任务使用 `inspect_target -> run_validate_script`。
- 不要把实现细节写入 `docs/feature_list.json`。
