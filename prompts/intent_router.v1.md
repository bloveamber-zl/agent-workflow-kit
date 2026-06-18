# Name

intent_router

# Version

v1

# Purpose

识别用户请求对应的 agent workflow 操作类型。

# Inputs

- `user_request`：用户自然语言请求。
- `project_context`：目标项目是否已有 workflow、技术栈、workflow 版本和 Git 状态。

# Output Schema

```json
{
  "intent": "generate_workflow | upgrade_workflow | optimize_workflow | validate_workflow | repair_workflow | explain_workflow | unknown",
  "confidence": 0.0,
  "requires_user_input": false,
  "risk_level": "low | medium | high"
}
```

# Rules

- 用户要求生成、安装、创建 workflow 时，优先输出 `generate_workflow`。
- 用户要求同步、升级、更新到最新版时，输出 `upgrade_workflow`。
- 用户要求校验、验证、检查时，输出 `validate_workflow`。
- 用户要求修复、补齐缺失文件时，输出 `repair_workflow`。
- 用户只要求解释现有流程时，输出 `explain_workflow`。
- 意图不明确时，输出 `unknown` 并设置 `requires_user_input` 为 `true`。

# Examples

```json
{
  "user_request": "给这个 Flutter 项目生成 agent workflow",
  "output": {
    "intent": "generate_workflow",
    "confidence": 0.88,
    "requires_user_input": false,
    "risk_level": "medium"
  }
}
```
