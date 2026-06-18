from __future__ import annotations

from runtime.models import Requirement, StructuredTask


def parse_requirement(task: StructuredTask) -> Requirement:
    if task.intent in {"upgrade_workflow", "repair_workflow"}:
        goal = "同步或修复目标项目 agent workflow"
    elif task.intent == "validate_workflow":
        goal = "校验目标项目 agent workflow"
    else:
        goal = "为目标项目安装 agent workflow"

    return Requirement(
        goal=goal,
        constraints=["不得覆盖已有文件", "默认使用轻量验证", *task.constraints],
        acceptance=["生成或保留必需 workflow 文件", "validate_target.sh 通过"],
        risks=["目标项目已有同名文件时需要转入升级或修复流程"],
    )
