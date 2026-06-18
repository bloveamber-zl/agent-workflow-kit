# Eval 架构

`eval/` 用于离线检查 Runtime 的路由、技术栈识别和缺槽判断。它补充 `scripts/self_test.sh`，让项目不只验证脚本能运行，也验证 Agent 行为是否符合预期。

## 目录

```text
eval/cases/      评估用例
eval/fixtures/   目标项目夹具
eval/reports/    指标报告
```

## Case

```json
{
  "id": "generate_flutter_workflow",
  "input": "给这个 Flutter 项目生成 agent 工作流",
  "fixture": "flutter_empty_project",
  "expected": {
    "intent": "generate_workflow",
    "stack": "flutter",
    "requires_user_input": false
  }
}
```

## 命令

```bash
scripts/run_eval.sh
```

指标包括 intent accuracy、stack detection accuracy 和 slot filling accuracy。
