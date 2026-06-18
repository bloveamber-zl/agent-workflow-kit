# Runtime 架构

`runtime/` 是 `agent-workflow-kit` 的轻量编排层。它不替代现有 Bash 脚本，而是负责把用户自然语言请求转成确定性脚本调用，并记录 trace。

## 链路

```text
Runtime CLI
  -> Intent Router
  -> Context Builder
  -> Executor
  -> Validator
  -> Trace Writer
  -> Reporter
```

M3 后补充：

```text
Query Rewriter
  -> Requirement Parser
  -> Workflow Planner
  -> Skill Selector
```

## 设计原则

- Runtime 只做编排，不重新实现模板生成逻辑。
- 脚本仍是确定性执行入口。
- 目标项目只保存 workflow 文件、配置、trace 和报告。
- 第一版使用规则实现，后续可在同一接口下接入 LLM。

## CLI

```bash
python3 -m runtime.cli run "给这个项目生成 agent workflow" --target /path/to/project
```

输出包括 intent、target、stack、result 和 trace 路径。
