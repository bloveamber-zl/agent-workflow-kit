from __future__ import annotations

from runtime.models import Requirement, StructuredTask


def parse_requirement(task: StructuredTask) -> Requirement:
    if task.intent == "test_case_workflow":
        goal = "根据原始需求生成测试用例并验证目标实现"
    elif task.intent in {"upgrade_workflow", "repair_workflow"}:
        goal = "同步或修复目标项目 agent workflow"
    elif task.intent == "recon_project":
        goal = "为目标项目执行项目深度扫描并回填项目文档"
    elif task.intent == "validate_workflow":
        goal = "校验目标项目 agent workflow"
    else:
        goal = "为目标项目安装 agent workflow"

    acceptance = ["生成或保留必需 workflow 文件", "validate_target.sh 通过"]
    risks = ["目标项目已有同名文件时需要转入升级或修复流程"]
    if task.intent == "recon_project":
        acceptance = ["`docs/project/*` 得到补充或刷新自动侦察区块", "validate_target.sh 通过"]
        risks = ["如果扫描事实与现有人工描述冲突，需要先向用户确认"]
    elif task.intent == "test_case_workflow":
        acceptance = [
            "每个验收标准映射到测试用例 ID",
            "可自动化用例有测试代码和运行结果",
            "人工用例有降级原因和验收证据",
        ]
        risks = ["测试不得根据现有实现反向削弱原始需求"]

    return Requirement(
        goal=goal,
        constraints=["不得覆盖已有文件", "默认使用轻量验证", *task.constraints],
        acceptance=acceptance,
        risks=risks,
    )
