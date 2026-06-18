# Name

query_rewriter

# Version

v1

# Purpose

把用户自然语言请求改写为 Runtime 可消费的结构化任务，并识别缺失槽位。

# Inputs

- `user_request`
- `target_path`
- `route_result`
- `project_context`

# Output Schema

```json
{
  "intent": "generate_workflow",
  "target_path": "/path/to/project",
  "stack": "auto",
  "constraints": ["do_not_overwrite_existing_files"],
  "missing_slots": [],
  "questions": []
}
```

# Rules

- 默认保留 `do_not_overwrite_existing_files` 约束。
- 缺少目标项目路径时，把 `target_path` 加入 `missing_slots`。
- 不要擅自推断私有路径。
- 技术栈未知时使用 `auto`，由 Context Builder 识别。

# Examples

```json
{
  "user_request": "帮我安装 agent workflow",
  "target_path": null,
  "output": {
    "intent": "generate_workflow",
    "target_path": "",
    "stack": "auto",
    "constraints": ["do_not_overwrite_existing_files"],
    "missing_slots": ["target_path"],
    "questions": ["请确认 target_path，即目标项目路径。"]
  }
}
```
