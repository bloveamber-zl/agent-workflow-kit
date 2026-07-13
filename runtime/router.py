from __future__ import annotations

from runtime.models import RouteResult


def route_intent(user_request: str) -> RouteResult:
    text = user_request.lower()
    test_case_keywords = (
        "需要测试用例",
        "生成测试用例",
        "测试用例流程",
        "测试用例驱动",
        "根据需求生成测试用例",
    )
    if any(keyword in text for keyword in test_case_keywords):
        post_implementation_keywords = (
            "已经开发",
            "已开发完成",
            "开发完毕",
            "现有实现",
            "直接进行测试",
            "直接测试",
        )
        execution_mode = (
            "post_implementation"
            if any(keyword in text for keyword in post_implementation_keywords)
            else "pre_implementation"
        )
        return RouteResult(
            intent="test_case_workflow",
            confidence=0.94,
            risk_level="medium",
            execution_mode=execution_mode,
        )
    if any(keyword in text for keyword in ("深度扫描", "项目扫描", "回填", "recon")):
        return RouteResult(intent="recon_project", confidence=0.9, risk_level="medium")
    if any(keyword in text for keyword in ("校验", "验证", "validate", "check")):
        return RouteResult(intent="validate_workflow", confidence=0.9, risk_level="low")
    if any(keyword in text for keyword in ("同步", "升级", "最新版", "upgrade", "更新")):
        return RouteResult(intent="upgrade_workflow", confidence=0.86, risk_level="medium")
    if any(keyword in text for keyword in ("修复", "补齐", "repair", "fix")):
        return RouteResult(intent="repair_workflow", confidence=0.82, risk_level="medium")
    if any(keyword in text for keyword in ("解释", "说明", "explain")):
        return RouteResult(intent="explain_workflow", confidence=0.78, risk_level="low")
    if any(keyword in text for keyword in ("生成", "安装", "创建", "加一套", "generate", "install")):
        return RouteResult(intent="generate_workflow", confidence=0.88, risk_level="medium")
    return RouteResult(intent="unknown", confidence=0.2, requires_user_input=True, risk_level="low")
