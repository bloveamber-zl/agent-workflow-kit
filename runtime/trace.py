from __future__ import annotations

import json
from datetime import datetime
from pathlib import Path

from runtime.models import TraceNode


def write_trace(target_path: str | Path, intent: str, user_request: str, nodes: list[TraceNode], final_status: str) -> Path:
    root = Path(target_path).resolve()
    trace_dir = root / ".agent/traces"
    trace_dir.mkdir(parents=True, exist_ok=True)
    timestamp = datetime.now().strftime("%Y-%m-%d-%H%M%S")
    trace_path = trace_dir / f"{timestamp}-{intent}.json"
    data = {
        "task_id": f"{timestamp}-{intent}",
        "user_request": user_request,
        "target_path": str(root),
        "nodes": [node.to_dict() for node in nodes],
        "final_status": final_status,
    }
    with trace_path.open("w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")
    return trace_path
