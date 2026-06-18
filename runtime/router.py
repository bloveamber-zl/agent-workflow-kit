from __future__ import annotations

from runtime.models import RouteResult


def route_intent(user_request: str) -> RouteResult:
    text = user_request.lower()
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
