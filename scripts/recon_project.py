#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import datetime
from pathlib import Path


AUTO_BLOCK_PREFIX = "AUTO-RECON"
AUTO_SECTION_TITLE = "## 自动侦察补充"
CAPABILITIES_FILE = "docs/workflow-capabilities.md"
PROJECT_DOC_FILES = {
    "overview": "docs/project/structure/overview.md",
    "architecture": "docs/project/structure/architecture.md",
    "features": "docs/project/features/overview.md",
    "frontend": "docs/project/frontend.md",
    "constraints": "docs/project/constraints.md",
    "capabilities": CAPABILITIES_FILE,
}


def detect_stack(root: Path) -> str:
    if (root / "pubspec.yaml").is_file():
        return "flutter"
    if (root / "package.json").is_file():
        return "node"
    if any((root / name).is_file() for name in ("pyproject.toml", "requirements.txt", "setup.py")):
        return "python"
    return "generic"


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except OSError:
        return ""


def write_text(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def detect_surfaces(root: Path, stack: str) -> list[str]:
    surfaces: list[str] = []
    for name, label in (
        ("android", "Android"),
        ("ios", "iOS"),
        ("web", "Web"),
        ("macos", "macOS"),
        ("windows", "Windows"),
        ("linux", "Linux"),
    ):
        if (root / name).is_dir():
            surfaces.append(label)
    if stack == "node":
        surfaces.append("Node/npm")
    elif stack == "python":
        surfaces.append("Python")
    elif stack == "generic" and not surfaces:
        surfaces.append("CLI/脚本")
    return surfaces


def read_readme_summary(root: Path) -> str:
    for name in ("README.md", "readme.md", "README", "readme"):
        path = root / name
        if not path.is_file():
            continue
        lines = []
        for raw in read_text(path).splitlines():
            line = raw.strip()
            if not line or line.startswith("#") or line.startswith("```"):
                continue
            lines.append(line)
            if len(lines) == 2:
                break
        if lines:
            return " ".join(lines)[:180]
    return "未从 README 中识别到稳定的项目说明。"


def detect_core_directories(root: Path) -> list[tuple[str, str, str]]:
    known = [
        ("lib", "应用或业务源码目录", "目录存在"),
        ("src", "源码目录", "目录存在"),
        ("app", "应用入口或路由目录", "目录存在"),
        ("pages", "页面或路由目录", "目录存在"),
        ("components", "组件目录", "目录存在"),
        ("features", "功能模块目录", "目录存在"),
        ("modules", "模块目录", "目录存在"),
        ("services", "服务目录", "目录存在"),
        ("public", "公开静态资源目录", "目录存在"),
        ("assets", "静态资源目录", "目录存在"),
        ("test", "自动化测试目录", "目录存在"),
        ("scripts", "项目脚本目录", "目录存在"),
        ("docs", "项目文档目录", "目录存在"),
    ]
    rows = [(path, purpose, basis) for path, purpose, basis in known if (root / path).is_dir()]
    if rows:
        return rows[:10]

    fallback = []
    for child in sorted(root.iterdir()):
        if child.name.startswith(".") or not child.is_dir():
            continue
        fallback.append((child.name, "顶层目录，需人工补充用途", "目录存在"))
        if len(fallback) == 8:
            break
    return fallback or [("待补充", "未识别到常见目录", "项目侦察")]


def detect_key_files(root: Path) -> list[tuple[str, str, str]]:
    known = [
        ("pubspec.yaml", "Flutter 依赖与项目配置", "文件存在"),
        ("package.json", "Node/npm 项目配置", "文件存在"),
        ("pyproject.toml", "Python 项目配置", "文件存在"),
        ("requirements.txt", "Python 依赖清单", "文件存在"),
        ("README.md", "项目说明入口", "文件存在"),
        ("analysis_options.yaml", "Dart 静态分析配置", "文件存在"),
        ("tsconfig.json", "TypeScript 编译配置", "文件存在"),
        ("vite.config.ts", "Vite 构建配置", "文件存在"),
        ("next.config.js", "Next.js 配置", "文件存在"),
        (".vscode/launch.json", "本地启动配置", "文件存在"),
        ("define_config/.custom.json", "本地环境参数文件", "文件存在"),
    ]
    rows = [(path, purpose, basis) for path, purpose, basis in known if (root / path).is_file()]
    return rows or [("待补充", "未识别到常见配置文件", "项目侦察")]


def detect_entrypoints(root: Path, stack: str) -> list[str]:
    entries: list[str] = []
    if stack == "flutter":
        for path in sorted((root / "lib").glob("main*.dart")) if (root / "lib").is_dir() else []:
            entries.append(str(path.relative_to(root)))
    elif stack == "node":
        package_json = root / "package.json"
        if package_json.is_file():
            try:
                data = json.loads(read_text(package_json))
            except json.JSONDecodeError:
                data = {}
            main_field = data.get("main")
            if isinstance(main_field, str) and main_field.strip():
                entries.append(main_field.strip())
            for candidate in ("src/index.ts", "src/index.js", "src/main.ts", "src/main.js", "app.js", "server.js", "index.js"):
                if (root / candidate).is_file():
                    entries.append(candidate)
    elif stack == "python":
        for candidate in ("main.py", "app.py", "manage.py"):
            if (root / candidate).is_file():
                entries.append(candidate)
        for candidate in sorted(root.glob("*/__main__.py")):
            entries.append(str(candidate.relative_to(root)))
    if not entries and (root / "README.md").is_file():
        entries.append("README.md")
    return list(dict.fromkeys(entries))[:6]


def detect_module_roots(root: Path) -> list[tuple[str, str, str]]:
    module_parents = [
        root / "lib" / "features",
        root / "lib" / "modules",
        root / "src" / "features",
        root / "src" / "modules",
        root / "app" / "features",
        root / "app" / "modules",
        root / "features",
        root / "modules",
    ]
    rows: list[tuple[str, str, str]] = []
    for parent in module_parents:
        if not parent.is_dir():
            continue
        for child in sorted(parent.iterdir()):
            if child.is_dir() and not child.name.startswith("."):
                rows.append((child.name, str(child.relative_to(root)), "目录命名显示为功能模块"))
    if rows:
        return rows[:10]

    fallbacks = []
    for parent_name in ("lib", "src", "app"):
        parent = root / parent_name
        if not parent.is_dir():
            continue
        for child in sorted(parent.iterdir()):
            if child.is_dir() and child.name not in {"core", "common", "shared", "widgets", "components", "generated"}:
                fallbacks.append((child.name, str(child.relative_to(root)), "顶层源码子目录，疑似模块边界"))
        if fallbacks:
            break
    return fallbacks[:8]


def parse_pubspec_packages(root: Path) -> set[str]:
    path = root / "pubspec.yaml"
    if not path.is_file():
        return set()
    packages: set[str] = set()
    for raw in read_text(path).splitlines():
        if re.match(r"^[A-Za-z0-9_]+:", raw) and not raw.startswith("  "):
            continue
        match = re.match(r"^\s{2}([A-Za-z0-9_]+):", raw)
        if match:
            packages.add(match.group(1))
    return packages


def parse_package_json_deps(root: Path) -> set[str]:
    path = root / "package.json"
    if not path.is_file():
        return set()
    try:
        data = json.loads(read_text(path))
    except json.JSONDecodeError:
        return set()
    packages: set[str] = set()
    for key in ("dependencies", "devDependencies", "peerDependencies"):
        value = data.get(key, {})
        if isinstance(value, dict):
            packages.update(value.keys())
    return packages


def parse_requirements_deps(root: Path) -> set[str]:
    packages: set[str] = set()
    for name in ("requirements.txt", "pyproject.toml"):
        path = root / name
        if not path.is_file():
            continue
        for raw in read_text(path).splitlines():
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            match = re.match(r"([A-Za-z0-9_.-]+)", line)
            if match:
                packages.add(match.group(1))
    return packages


def detect_framework_signals(root: Path, stack: str) -> dict[str, list[str] | str]:
    frameworks: list[str] = []
    state: list[str] = []
    routing: list[str] = []

    if stack == "flutter":
        packages = parse_pubspec_packages(root)
        frameworks.append("Flutter")
        for package, label in (
            ("provider", "Provider"),
            ("flutter_bloc", "Bloc"),
            ("hooks_riverpod", "Riverpod"),
            ("riverpod", "Riverpod"),
            ("get", "GetX"),
        ):
            if package in packages:
                state.append(label)
        for package, label in (("go_router", "go_router"), ("auto_route", "auto_route"), ("beamer", "beamer")):
            if package in packages:
                routing.append(label)
    elif stack == "node":
        packages = parse_package_json_deps(root)
        for package, label in (
            ("react", "React"),
            ("next", "Next.js"),
            ("vue", "Vue"),
            ("nuxt", "Nuxt"),
            ("express", "Express"),
            ("@nestjs/core", "NestJS"),
        ):
            if package in packages:
                frameworks.append(label)
        for package, label in (
            ("redux", "Redux"),
            ("@reduxjs/toolkit", "Redux Toolkit"),
            ("zustand", "Zustand"),
            ("pinia", "Pinia"),
        ):
            if package in packages:
                state.append(label)
        for package, label in (
            ("react-router-dom", "React Router"),
            ("vue-router", "Vue Router"),
        ):
            if package in packages:
                routing.append(label)
    elif stack == "python":
        packages = parse_requirements_deps(root)
        for package, label in (("django", "Django"), ("fastapi", "FastAPI"), ("flask", "Flask")):
            if package in packages:
                frameworks.append(label)

    if not frameworks:
        frameworks.append(stack)
    return {"frameworks": frameworks[:4], "state": state[:3], "routing": routing[:3]}


def detect_constraints(root: Path) -> list[str]:
    items: list[str] = []
    if (root / ".vscode/launch.json").is_file():
        items.append("存在 `.vscode/launch.json`，启动与验收应优先复用其中的本地参数。")
    if (root / "define_config/.custom.json").is_file():
        items.append("存在 `define_config/.custom.json`，Flutter 启动或验收时应复用 dart define。")
    env_files = [path.name for path in root.glob(".env*") if path.is_file()]
    if env_files:
        items.append("检测到环境变量文件：`%s`，不要把其中的敏感配置写入文档或模板。" % "`, `".join(sorted(env_files)[:5]))
    if (root / ".git").exists():
        items.append("项目处于 Git 仓库中，回填时应避免覆盖已有人工文档。")
    return items or ["当前未识别到额外环境限制，仍应按最小改动和敏感信息保护原则处理。"]


def render_table(headers: list[str], rows: list[list[str]]) -> str:
    lines = [
        "| " + " | ".join(headers) + " |",
        "| " + " | ".join(["---"] * len(headers)) + " |",
    ]
    for row in rows:
        lines.append("| " + " | ".join(row) + " |")
    return "\n".join(lines)


def marker_pair(block_id: str) -> tuple[str, str]:
    return (f"<!-- BEGIN {AUTO_BLOCK_PREFIX}:{block_id} -->", f"<!-- END {AUTO_BLOCK_PREFIX}:{block_id} -->")


def replace_or_append_auto_block(existing: str, block_id: str, body: str) -> str:
    begin, end = marker_pair(block_id)
    block = f"{begin}\n{body.rstrip()}\n{end}"
    if begin in existing and end in existing:
        pattern = re.compile(re.escape(begin) + r".*?" + re.escape(end), re.S)
        return pattern.sub(block, existing)

    suffix = ""
    if existing and not existing.endswith("\n"):
        suffix += "\n"
    if existing:
        suffix += "\n"
    suffix += f"{AUTO_SECTION_TITLE}\n\n{block}\n"
    return existing + suffix


def detect_text_conflicts(path: Path, block_id: str, detected_stack: str, surfaces: list[str]) -> list[dict[str, str]]:
    text = read_text(path)
    conflicts: list[dict[str, str]] = []
    if not text:
        return conflicts

    if block_id in {"overview", "architecture"}:
        for match in re.finditer(r"- 技术栈：`?([^`\n]+)`?", text):
            current = match.group(1).strip()
            if current and "待" not in current and current.lower() != detected_stack.lower():
                conflicts.append(
                    {
                        "file": str(path),
                        "summary": "现有文档技术栈描述与扫描结果不一致",
                        "current": current,
                        "detected": detected_stack,
                    }
                )
                break

        surfaces_text = " / ".join(surfaces) if surfaces else "CLI/脚本"
        detected_surface_tokens = {token for token in re.split(r"[、/,\s]+", surfaces_text) if token}
        for match in re.finditer(r"- 运行面：([^\n]+)", text):
            current = match.group(1).strip().strip("`")
            current_tokens = {token for token in re.split(r"[、/,\s]+", current) if token}
            if current and "待" not in current and not detected_surface_tokens.issubset(current_tokens):
                conflicts.append(
                    {
                        "file": str(path),
                        "summary": "现有文档运行面描述与扫描结果不一致",
                        "current": current,
                        "detected": surfaces_text,
                    }
                )
                break

    return conflicts


def render_overview_block(root: Path, stack: str, surfaces: list[str], readme_summary: str, entries: list[str], dirs: list[tuple[str, str, str]], modules: list[tuple[str, str, str]], config_files: list[tuple[str, str, str]], timestamp: str) -> str:
    lines = [
        f"- 侦察时间：`{timestamp}`",
        f"- 识别摘要：{readme_summary}",
        f"- 运行面补充：`{' / '.join(surfaces) if surfaces else 'CLI/脚本'}`",
        f"- 入口候选：`{'`, `'.join(entries) if entries else '待补充'}`",
        "",
        "### 识别到的核心目录",
        "",
        render_table(["路径", "作用", "依据"], [[f"`{path}/`", purpose, basis] for path, purpose, basis in dirs]),
        "",
        "### 识别到的主要功能模块",
        "",
    ]
    module_rows = [[name, "从目录命名推断的用户价值", entry, note] for name, entry, note in modules] or [["待补充", "待补充", "待补充", "未识别到稳定模块目录"]]
    lines.extend(
        [
            render_table(["模块", "用户价值", "主要入口", "依据"], module_rows),
            "",
            "### 关键配置补充",
            "",
            render_table(["文件", "作用", "依据"], [[f"`{path}`", purpose, basis] for path, purpose, basis in config_files]),
        ]
    )
    return "\n".join(lines)


def render_architecture_block(stack: str, entries: list[str], frameworks: dict[str, list[str] | str], modules: list[tuple[str, str, str]], timestamp: str) -> str:
    rows = []
    for name, entry, note in modules[:8]:
        rows.append([name, "待结合需求补充职责", f"`{entry}`", note])
    if not rows:
        rows.append(["待补充", "待补充", "待补充", "未识别到稳定模块边界"])

    lines = [
        f"- 侦察时间：`{timestamp}`",
        f"- 框架信号：`{'`, `'.join(frameworks['frameworks'])}`",
        f"- 状态管理信号：`{'`, `'.join(frameworks['state']) if frameworks['state'] else '待补充'}`",
        f"- 路由信号：`{'`, `'.join(frameworks['routing']) if frameworks['routing'] else '待补充'}`",
        f"- 入口候选补充：`{'`, `'.join(entries) if entries else '待补充'}`",
        "",
        "### 侦察到的领域地图补充",
        "",
        render_table(["领域", "负责什么", "主要入口", "依据"], rows),
        "",
        "### 当前可复用的边界判断",
        "",
        "- 若存在 `features/`、`modules/` 或等价目录，优先把它们视为业务边界。",
        "- 入口文件、路由文件和状态管理文件应优先落在架构变更评估范围中。",
        "- 未识别到完整分层时，先按现有目录边界工作，不主动重塑架构。",
    ]
    return "\n".join(lines)


def render_features_block(modules: list[tuple[str, str, str]], timestamp: str) -> str:
    rows = [[name, f"`{entry}`", "discovered", note] for name, entry, note in modules] or [["待补充", "待补充", "open", "未识别到稳定功能模块目录"]]
    lines = [
        f"- 侦察时间：`{timestamp}`",
        "- 下表为目录和命名层面的功能线索，后续仍需结合真实需求补足业务说明。",
        "",
        render_table(["功能", "文档/入口", "状态", "备注"], rows),
    ]
    return "\n".join(lines)


def render_frontend_block(stack: str, surfaces: list[str], frameworks: dict[str, list[str] | str], timestamp: str) -> str:
    ui_rows = [
        ["运行面", " / ".join(surfaces) if surfaces else "CLI/脚本", "项目侦察"],
        ["框架", "、".join(frameworks["frameworks"]), "依赖或配置文件"],
        ["状态管理", "、".join(frameworks["state"]) if frameworks["state"] else "待补充", "依赖或配置文件"],
        ["路由", "、".join(frameworks["routing"]) if frameworks["routing"] else "待补充", "依赖或配置文件"],
    ]
    if stack == "flutter":
        ui_rows.append(["设计系统线索", "Material / Cupertino 需按源码复核", "Flutter 默认生态推断"])
    lines = [
        f"- 侦察时间：`{timestamp}`",
        "- 当前补充只记录稳定的框架与运行面信号，不替代真实 UI 规范。",
        "",
        render_table(["主题", "约定", "参考"], ui_rows),
    ]
    return "\n".join(lines)


def render_constraints_block(constraints: list[str], timestamp: str) -> str:
    lines = [f"- 侦察时间：`{timestamp}`", "- 本节补充来自环境文件和目录结构的高置信约束：", ""]
    for item in constraints:
        lines.append(f"- {item}")
    return "\n".join(lines)


def load_enhancements(root: Path) -> dict[str, bool]:
    config_path = root / ".agent/config.json"
    if not config_path.is_file():
        return {"patrol": False, "codegraph": False, "opendesign": False}
    try:
        data = json.loads(read_text(config_path))
    except json.JSONDecodeError:
        return {"patrol": False, "codegraph": False, "opendesign": False}
    enhancements = data.get("enhancements", {})
    if not isinstance(enhancements, dict):
        return {"patrol": False, "codegraph": False, "opendesign": False}
    return {key: bool(enhancements.get(key, False)) for key in ("patrol", "codegraph", "opendesign")}


def build_capabilities_doc(root: Path, stack: str, enhancements: dict[str, bool]) -> str:
    patrol_status = "enabled" if enhancements.get("patrol") else "disabled"
    codegraph_status = "enabled" if enhancements.get("codegraph") else "disabled"
    opendesign_status = "enabled" if enhancements.get("opendesign") else "disabled"
    return "\n".join(
        [
            "# 主动功能使用说明",
            "",
            "## 什么时候读",
            "",
            "想知道当前工作流能主动执行什么动作、怎么触发、默认作用到哪里时读取。",
            "",
            "## 当前项目概况",
            "",
            f"- 项目名称：`{root.name}`",
            f"- 项目根目录：`{root}`",
            f"- 技术栈：`{stack}`",
            "- 默认目标：当前工作目录所在项目。",
            "",
            "## 主动功能",
            "",
            render_table(
                ["功能", "状态", "对话触发方式", "默认目标", "产出"],
                [
                    ["项目深度扫描并回填", "enabled", "`进行项目深度扫描并回填`", "当前工作目录项目", "`docs/project/*`、`.agent/traces/*-recon-project.json`"],
                    ["校验当前工作流", "enabled", "`校验当前工作流`", "当前工作目录项目", "运行 `scripts/validate_target.sh`"],
                    ["同步当前工作流到最新版", "enabled", "`同步当前工作流到最新版`", "当前工作目录项目", "工作流升级 dry-run 或 apply"],
                    ["修复或补齐当前工作流", "enabled", "`修复当前工作流` / `补齐当前工作流`", "当前工作目录项目", "补齐缺失 workflow 文件"],
                    ["测试用例驱动验证", "enabled", "`需要测试用例` / `根据需求生成测试用例并执行测试`", "当前需求", "`docs/test-cases/<requirement-id>.md`、自动化测试与验收证据"],
                    ["Patrol 验收", patrol_status, "`用 Patrol 验证这个需求`", "当前需求", "`docs/testing/patrol.md`、验收证据"],
                    ["CodeGraph 影响分析", codegraph_status, "`用 CodeGraph 做影响分析`", "当前需求", "`docs/tools/codegraph.md` 指引与分析证据"],
                    ["Open Design 设计链路", opendesign_status, "`用 Open Design 生成设计稿`", "当前需求", "`docs/tools/opendesign.md` 指引与设计证据"],
                ],
            ),
            "",
            "## 项目深度扫描默认策略",
            "",
            "- 默认只补充缺失信息，不改已有描述。",
            "- 如果扫描结论会改动现有文字描述，应先向用户确认。",
            "- 脚本入口：`scripts/recon_project.sh <target-project-path>`；在对话里优先通过 Agent 触发。",
            "",
            "## 测试用例驱动验证",
            "",
            "- 当前状态：`enabled`。",
            "- 默认关闭：未明确提出测试用例要求时，不启用、不提醒，继续使用项目默认验证配置。",
            "- 开发前模式：需求解析后生成测试用例，用户确认后先生成自动化测试，再开发并复测。",
            "- 开发后模式：用户提供已完成需求时，根据原始需求生成测试用例，确认后直接生成并运行测试。",
            "- 需求依据：测试目标来自原始需求和验收标准，不能根据现有实现反向削弱断言。",
            "- 人工降级：无法自动化时记录原因、步骤、环境、证据和剩余风险，可人工验收完成。",
            "- 主要产出：`docs/test-cases/<requirement-id>.md`、自动化测试文件、`docs/reports/test-report.md` 和验收证据。",
            "",
            "## 最近一次项目深度扫描",
            "",
            "<!-- BEGIN AUTO-RECON:capabilities -->",
            "- 尚未运行项目深度扫描。",
            "<!-- END AUTO-RECON:capabilities -->",
            "",
            "## 文档路由",
            "",
            render_table(
                ["场景", "读取"],
                [
                    ["看项目结构", "`docs/project/structure/overview.md`"],
                    ["看架构边界", "`docs/project/structure/architecture.md`"],
                    ["看功能模块", "`docs/project/features/overview.md`"],
                    ["看项目规则", "`docs/project/constraints.md`"],
                    ["看 UI/交互约定", "`docs/project/frontend.md`"],
                ],
            ),
        ]
    ) + "\n"


def render_capabilities_block(timestamp: str, updated_files: list[str], conflicts: list[dict[str, str]]) -> str:
    lines = [
        f"- 最近扫描时间：`{timestamp}`",
        f"- 回填结果：`{'成功' if not conflicts else '发现冲突，等待确认'}`",
        f"- 影响文件：`{'`, `'.join(updated_files) if updated_files else '无写入'}`",
    ]
    if conflicts:
        lines.append("- 冲突摘要：")
        for item in conflicts:
            lines.append(f"  - `{item['file']}`：{item['summary']}（现有：`{item['current']}`，扫描：`{item['detected']}`）")
    else:
        lines.append("- 冲突摘要：无。")
    return "\n".join(lines)


def build_report_path(root: Path, override: str | None) -> Path:
    if override:
        return Path(override).expanduser().resolve()
    trace_dir = root / ".agent" / "traces"
    trace_dir.mkdir(parents=True, exist_ok=True)
    timestamp = datetime.now().strftime("%Y-%m-%d-%H%M%S")
    return trace_dir / f"{timestamp}-recon-project.json"


def main() -> int:
    parser = argparse.ArgumentParser(prog="recon_project")
    parser.add_argument("--target", required=True)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--report-json")
    args = parser.parse_args()

    root = Path(args.target).resolve()
    if not root.is_dir():
        print(f"Target project does not exist: {root}", file=sys.stderr)
        return 1

    stack = detect_stack(root)
    surfaces = detect_surfaces(root, stack)
    readme_summary = read_readme_summary(root)
    core_dirs = detect_core_directories(root)
    config_files = detect_key_files(root)
    entries = detect_entrypoints(root, stack)
    modules = detect_module_roots(root)
    frameworks = detect_framework_signals(root, stack)
    constraints = detect_constraints(root)
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S %z").strip()
    enhancements = load_enhancements(root)

    capabilities_path = root / CAPABILITIES_FILE
    if not capabilities_path.exists():
        write_text(capabilities_path, build_capabilities_doc(root, stack, enhancements))

    bodies = {
        "overview": render_overview_block(root, stack, surfaces, readme_summary, entries, core_dirs, modules, config_files, timestamp),
        "architecture": render_architecture_block(stack, entries, frameworks, modules, timestamp),
        "features": render_features_block(modules, timestamp),
        "frontend": render_frontend_block(stack, surfaces, frameworks, timestamp),
        "constraints": render_constraints_block(constraints, timestamp),
    }

    conflicts: list[dict[str, str]] = []
    for block_id, relative_path in PROJECT_DOC_FILES.items():
        if block_id == "capabilities":
            continue
        path = root / relative_path
        if path.exists():
            conflicts.extend(detect_text_conflicts(path, block_id, stack, surfaces))

    report_path = build_report_path(root, args.report_json)
    updated_files: list[str] = []

    if conflicts:
        report = {
            "task": "recon_project",
            "status": "conflict",
            "target_path": str(root),
            "detected_stack": stack,
            "surfaces": surfaces,
            "entrypoints": entries,
            "conflicts": conflicts,
            "updated_files": [],
        }
        write_text(report_path, json.dumps(report, ensure_ascii=False, indent=2) + "\n")
        print(f"项目深度扫描发现冲突，未写入文档。报告：{report_path}", file=sys.stderr)
        return 2

    for block_id, relative_path in PROJECT_DOC_FILES.items():
        path = root / relative_path
        existing = read_text(path)
        if block_id == "capabilities":
            new_content = replace_or_append_auto_block(
                existing or build_capabilities_doc(root, stack, enhancements),
                block_id,
                render_capabilities_block(timestamp, [PROJECT_DOC_FILES[key] for key in bodies], conflicts),
            )
        else:
            if not path.exists():
                continue
            new_content = replace_or_append_auto_block(existing, block_id, bodies[block_id])
        if new_content != existing:
            updated_files.append(relative_path)
            if not args.dry_run:
                write_text(path, new_content)

    report = {
        "task": "recon_project",
        "status": "dry-run" if args.dry_run else "passed",
        "target_path": str(root),
        "detected_stack": stack,
        "surfaces": surfaces,
        "readme_summary": readme_summary,
        "entrypoints": entries,
        "modules": [{"name": name, "entry": entry, "basis": basis} for name, entry, basis in modules],
        "frameworks": frameworks,
        "constraints": constraints,
        "updated_files": updated_files,
        "conflicts": conflicts,
    }
    write_text(report_path, json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    action = "预览完成" if args.dry_run else "回填完成"
    print(f"{action}：{root}")
    print(f"Stack: {stack}")
    print(f"Updated files: {', '.join(updated_files) if updated_files else 'none'}")
    print(f"Report: {report_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
