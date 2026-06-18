from __future__ import annotations

from runtime.models import ProjectContext, SkillSelection, StructuredTask


def select_skill(task: StructuredTask, context: ProjectContext) -> SkillSelection:
    return SkillSelection(
        skill="agent-workflow",
        reason="任务需要生成、升级、修复或校验目标项目 workflow",
        entrypoints=[
            "scripts/generate_workflow.sh",
            "scripts/upgrade_workflow.sh",
            "scripts/validate_target.sh",
        ],
    )
