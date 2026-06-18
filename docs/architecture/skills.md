# Skills 体系

本项目的 skill 分两层：

- Codex skill：`skills/agent-workflow/SKILL.md`，指导 Codex 在任意目标项目中生成、升级或优化 workflow。
- Runtime skill selection：`runtime/skill_selector.py`，把结构化任务映射到能力包和脚本入口。

第一版只内置 `agent-workflow` skill。后续可以扩展 Flutter、Node、Python 等 stack-specific skill，但通用流程仍应留在 base workflow，不把单个业务项目规则写死到模板。

## Skill 输出

```json
{
  "skill": "agent-workflow",
  "reason": "任务需要生成、升级、修复或校验目标项目 workflow",
  "entrypoints": [
    "scripts/generate_workflow.sh",
    "scripts/upgrade_workflow.sh",
    "scripts/validate_target.sh"
  ]
}
```
