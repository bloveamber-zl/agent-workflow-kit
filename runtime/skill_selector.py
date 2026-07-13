from __future__ import annotations

from runtime.models import ProjectContext, SkillSelection, StructuredTask


def select_skill(task: StructuredTask, context: ProjectContext) -> SkillSelection:
    if task.intent == "test_case_workflow":
        return SkillSelection(
            skill="agent-workflow",
            reason="任务需要 Agent 解析需求、生成用例与测试并写回证据",
            entrypoints=[
                "docs/test-cases/README.md",
                "docs/process/verification.md",
                "docs/reports/test-report.md",
            ],
        )
    return SkillSelection(
        skill="agent-workflow",
        reason="任务需要生成、升级、修复、扫描或校验目标项目 workflow",
        entrypoints=[
            "scripts/generate_workflow.sh",
            "scripts/recon_project.sh",
            "scripts/upgrade_workflow.sh",
            "scripts/validate_target.sh",
        ],
    )
