from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Any


@dataclass(frozen=True)
class RouteResult:
    intent: str
    confidence: float
    requires_user_input: bool = False
    risk_level: str = "low"
    execution_mode: str = ""


@dataclass(frozen=True)
class ProjectContext:
    target_path: Path
    detected_stack: str
    has_workflow: bool
    workflow_version: str
    dirty_git: bool
    recommended_action: str


@dataclass(frozen=True)
class CommandResult:
    command: list[str]
    exit_code: int
    stdout: str
    stderr: str

    @property
    def status(self) -> str:
        return "passed" if self.exit_code == 0 else "failed"


@dataclass
class TraceNode:
    name: str
    status: str
    output: dict[str, Any] = field(default_factory=dict)
    error: str = ""

    def to_dict(self) -> dict[str, Any]:
        data: dict[str, Any] = {
            "name": self.name,
            "status": self.status,
            "output": self.output,
        }
        if self.error:
            data["error"] = self.error
        return data


@dataclass(frozen=True)
class StructuredTask:
    intent: str
    target_path: str
    stack: str
    constraints: list[str]
    missing_slots: list[str]
    questions: list[str]
    execution_mode: str = ""

    @property
    def requires_user_input(self) -> bool:
        return bool(self.missing_slots)


@dataclass(frozen=True)
class Requirement:
    goal: str
    constraints: list[str]
    acceptance: list[str]
    risks: list[str]


@dataclass(frozen=True)
class PlanStep:
    id: str
    action: str
    status: str = "pending"


@dataclass(frozen=True)
class WorkflowPlan:
    steps: list[PlanStep]


@dataclass(frozen=True)
class SkillSelection:
    skill: str
    reason: str
    entrypoints: list[str]
