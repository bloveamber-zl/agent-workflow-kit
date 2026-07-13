#!/usr/bin/env bash

set -euo pipefail

KIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_PATH=""
STACK="generic"
FORCE=0
PROJECT_NAME=""
PROJECT_ROOT_OVERRIDE=""

usage() {
  cat <<'USAGE'
Usage:
  scripts/generate_workflow.sh <target-project-path> [--stack generic|flutter|node|python] [--project-name name] [--force]

Options:
  --stack         Select stack config. Default: generic
  --project-name  Override project name. Default: target directory name
  --project-root  Override rendered project root. Default: target project path
  --force         Overwrite existing workflow files
  -h, --help      Show help
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --stack)
      STACK="${2:-}"
      shift 2
      ;;
    --project-name)
      PROJECT_NAME="${2:-}"
      shift 2
      ;;
    --project-root)
      PROJECT_ROOT_OVERRIDE="${2:-}"
      shift 2
      ;;
    --force)
      FORCE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      if [ -n "$TARGET_PATH" ]; then
        echo "Only one target path is allowed." >&2
        exit 1
      fi
      TARGET_PATH="$1"
      shift
      ;;
  esac
done

if [ -z "$TARGET_PATH" ]; then
  usage >&2
  exit 1
fi

if [ ! -d "$TARGET_PATH" ]; then
  echo "Target project does not exist: $TARGET_PATH" >&2
  exit 1
fi

STACK_FILE="$KIT_ROOT/templates/stacks/$STACK.yaml"
if [ ! -f "$STACK_FILE" ]; then
  echo "Unsupported stack: $STACK" >&2
  echo "Available stacks:" >&2
  find "$KIT_ROOT/templates/stacks" -maxdepth 1 -name '*.yaml' -exec basename {} .yaml \; | sort >&2
  exit 1
fi

TARGET_ROOT="$(cd "$TARGET_PATH" && pwd)"
if [ -z "$PROJECT_NAME" ]; then
  PROJECT_NAME="$(basename "$TARGET_ROOT")"
fi
if [ -z "$PROJECT_ROOT_OVERRIDE" ]; then
  PROJECT_ROOT_FOR_TEMPLATE="$TARGET_ROOT"
else
  PROJECT_ROOT_FOR_TEMPLATE="$PROJECT_ROOT_OVERRIDE"
fi
CURRENT_DATE="$(date +%F)"
KIT_VERSION="$(tr -d '[:space:]' < "$KIT_ROOT/VERSION")"
TEMPLATE_REVISION="$(tr -d '[:space:]' < "$KIT_ROOT/templates/VERSION")"

yaml_value() {
  local key="$1"
  awk -v key="$key" '
    $0 ~ "^[[:space:]]*" key ":[[:space:]]*" {
      value = $0
      sub("^[[:space:]]*" key ":[[:space:]]*", "", value)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      if (value ~ /^'\''.*'\''$/ || value ~ /^".*"$/) {
        value = substr(value, 2, length(value) - 2)
      }
      print value
      exit
    }
  ' "$STACK_FILE"
}

shell_quote() {
  printf '%q' "$1"
}

STACK_NAME="$(yaml_value stack_name)"
PRIMARY_VERIFY_COMMAND="$(yaml_value primary_verify_command)"
STRICT_VERIFY_COMMAND="$(yaml_value strict_verify_command)"
TEST_COMMAND="$(yaml_value test_command)"
START_COMMAND="$(yaml_value start_command)"
DEPENDENCY_SYNC_COMMAND="$(yaml_value dependency_sync_command)"
BUILD_DOCS="$(yaml_value build_docs)"
LIGHTWEIGHT_VALIDATION_NOTE="$(yaml_value lightweight_validation_note)"
E2E_TOOL_NAME="$(yaml_value e2e_tool_name)"
E2E_TEST_COMMAND="$(yaml_value e2e_test_command)"
E2E_SETUP_NOTE="$(yaml_value e2e_setup_note)"

PRIMARY_VERIFY_COMMAND_SHELL="$(shell_quote "$PRIMARY_VERIFY_COMMAND")"
STRICT_VERIFY_COMMAND_SHELL="$(shell_quote "$STRICT_VERIFY_COMMAND")"
TEST_COMMAND_SHELL="$(shell_quote "$TEST_COMMAND")"
START_COMMAND_SHELL="$(shell_quote "$START_COMMAND")"
DEPENDENCY_SYNC_COMMAND_SHELL="$(shell_quote "$DEPENDENCY_SYNC_COMMAND")"
E2E_TEST_COMMAND_SHELL="$(shell_quote "$E2E_TEST_COMMAND")"

required_values=(
  STACK_NAME
  PRIMARY_VERIFY_COMMAND
  STRICT_VERIFY_COMMAND
  TEST_COMMAND
  START_COMMAND
  DEPENDENCY_SYNC_COMMAND
  E2E_TOOL_NAME
  E2E_TEST_COMMAND
  E2E_SETUP_NOTE
)

for name in "${required_values[@]}"; do
  if [ -z "${!name}" ]; then
    echo "Missing stack value: $name in $STACK_FILE" >&2
    exit 1
  fi
done

outputs=(
  ".agent/state/current-task.json"
  ".agent/config.json"
  ".agent/traces/README.md"
  ".agent/traces/schema.json"
  ".agent/evals/README.md"
  "AGENTS.md"
  "init.sh"
  "docs/index.md"
  "docs/verification.md"
  "docs/process/verification.md"
  "docs/process/failure-taxonomy.md"
  "docs/process/badcase-analysis.md"
  "docs/acceptance_simulator.md"
  "docs/workflow-capabilities.md"
  "docs/test-cases/README.md"
  "docs/coding-progress.md"
  "docs/feature_list.json"
  "docs/session-handoff.md"
  "docs/project/structure/overview.md"
  "docs/project/structure/architecture.md"
  "docs/project/constraints.md"
  "docs/project/frontend.md"
  "docs/project/features/overview.md"
  "docs/requirements/parsed-requirements.md"
  "docs/requirements/open-questions.md"
  "docs/requirements/traceability.md"
  "docs/design/index.md"
  "docs/design/workflow-bootstrap.md"
  "docs/exec-plans/active/index.md"
  "docs/exec-plans/active/workflow-bootstrap.md"
  "docs/exec-plans/completed/index.md"
  "docs/exec-plans/tech-debt-tracker.md"
  "docs/reports/eval-report.md"
  "docs/reports/test-report.md"
  "scripts/acceptance_simulator.sh"
)

workflow_ignore_paths=(
  "/.agent/"
  "/AGENTS.md"
  "/init.sh"
  "/docs/index.md"
  "/docs/verification.md"
  "/docs/acceptance_simulator.md"
  "/docs/workflow-capabilities.md"
  "/docs/test-cases/"
  "/docs/coding-progress.md"
  "/docs/feature_list.json"
  "/docs/session-handoff.md"
  "/docs/design/"
  "/docs/exec-plans/"
  "/docs/process/"
  "/docs/project/"
  "/docs/reports/"
  "/docs/requirements/"
  "/docs/testing/"
  "/docs/tools/"
  "/scripts/acceptance_simulator.sh"
  "/scripts/patrol_acceptance.sh"
)

write_workflow_gitignore_block() {
  printf '%s\n' "# BEGIN agent-workflow-kit"
  printf '%s\n' "# Generated agent workflow files"
  printf '%s\n' "${workflow_ignore_paths[@]}"
  printf '%s\n' "# END agent-workflow-kit"
}

upsert_workflow_gitignore() {
  local gitignore="$TARGET_ROOT/.gitignore"
  local marker_begin="# BEGIN agent-workflow-kit"
  local marker_end="# END agent-workflow-kit"

  if [ -f "$gitignore" ] && grep -Fq "$marker_begin" "$gitignore"; then
    local tmp
    tmp="$(mktemp)"
    awk -v begin="$marker_begin" -v end="$marker_end" '
      $0 == begin {
        while ((getline line) > 0 && line != end) {}
        next
      }
      { print }
    ' "$gitignore" > "$tmp"
    {
      cat "$tmp"
      if [ -s "$tmp" ] && [ "$(tail -c 1 "$tmp" | wc -l | tr -d ' ')" -eq 0 ]; then
        printf '\n'
      fi
      if [ -s "$tmp" ]; then
        printf '\n'
      fi
      write_workflow_gitignore_block
    } > "$gitignore"
    rm -f "$tmp"
    return
  fi

  if [ -s "$gitignore" ]; then
    printf '\n' >> "$gitignore"
  fi

  write_workflow_gitignore_block >> "$gitignore"
}

has_dir() {
  [ -d "$TARGET_ROOT/$1" ]
}

has_file() {
  [ -f "$TARGET_ROOT/$1" ]
}

append_line() {
  printf '%s\n' "$1" >> "$2"
}

append_detected_directories_table() {
  local dest="$1"
  local found=0

  append_line "| 路径 | 推断作用 | 依据 |" "$dest"
  append_line "| --- | --- | --- |" "$dest"

  add_dir_row() {
    local path="$1"
    local purpose="$2"
    local basis="$3"
    if has_dir "$path"; then
      append_line "| \`$path/\` | $purpose | $basis |" "$dest"
      found=1
    fi
  }

  add_dir_row "lib" "应用/业务代码目录" "目录存在"
  add_dir_row "test" "自动化测试目录" "目录存在"
  add_dir_row "assets" "静态资源目录" "目录存在"
  add_dir_row "android" "Android 平台工程" "目录存在"
  add_dir_row "ios" "iOS 平台工程" "目录存在"
  add_dir_row "web" "Web 平台工程" "目录存在"
  add_dir_row "macos" "macOS 平台工程" "目录存在"
  add_dir_row "windows" "Windows 平台工程" "目录存在"
  add_dir_row "linux" "Linux 平台工程" "目录存在"
  add_dir_row "src" "源码目录" "目录存在"
  add_dir_row "app" "应用入口或路由目录" "目录存在"
  add_dir_row "pages" "页面/路由目录" "目录存在"
  add_dir_row "components" "组件目录" "目录存在"
  add_dir_row "public" "公开静态资源目录" "目录存在"
  add_dir_row "scripts" "项目脚本目录" "目录存在"
  add_dir_row "tools" "工具脚本目录" "目录存在"
  add_dir_row "docs" "项目文档目录" "目录存在"

  if [ "$found" -eq 0 ]; then
    append_line "| 待补充 | 未识别到常见目录 | 初始化自动侦察 |" "$dest"
  fi
}

append_detected_files_table() {
  local dest="$1"
  local found=0

  append_line "| 文件 | 推断作用 | 依据 |" "$dest"
  append_line "| --- | --- | --- |" "$dest"

  add_file_row() {
    local path="$1"
    local purpose="$2"
    local basis="$3"
    if has_file "$path"; then
      append_line "| \`$path\` | $purpose | $basis |" "$dest"
      found=1
    fi
  }

  add_file_row "pubspec.yaml" "Flutter/Dart 依赖与项目配置" "文件存在"
  add_file_row "package.json" "Node/npm 项目配置" "文件存在"
  add_file_row "pyproject.toml" "Python 项目配置" "文件存在"
  add_file_row "requirements.txt" "Python 依赖清单" "文件存在"
  add_file_row "README.md" "项目说明入口" "文件存在"
  add_file_row "analysis_options.yaml" "Dart 静态分析配置" "文件存在"
  add_file_row "tsconfig.json" "TypeScript 编译配置" "文件存在"
  add_file_row "vite.config.ts" "Vite 构建配置" "文件存在"
  add_file_row "next.config.js" "Next.js 配置" "文件存在"
  add_file_row "pytest.ini" "pytest 配置" "文件存在"

  if [ "$found" -eq 0 ]; then
    append_line "| 待补充 | 未识别到常见配置文件 | 初始化自动侦察 |" "$dest"
  fi
}

detected_run_surfaces() {
  local surfaces=()
  has_dir "android" && surfaces+=("Android")
  has_dir "ios" && surfaces+=("iOS")
  has_dir "web" && surfaces+=("Web")
  has_dir "macos" && surfaces+=("macOS")
  has_dir "windows" && surfaces+=("Windows")
  has_dir "linux" && surfaces+=("Linux")
  has_file "package.json" && surfaces+=("Node/npm")
  has_file "pyproject.toml" && surfaces+=("Python")
  has_file "requirements.txt" && surfaces+=("Python")

  if [ "${#surfaces[@]}" -eq 0 ]; then
    printf '%s\n' "待补充"
  else
    local joined="${surfaces[0]}"
    local surface
    for surface in "${surfaces[@]:1}"; do
      joined="${joined}、$surface"
    done
    printf '%s\n' "$joined"
  fi
}

initialize_project_docs() {
  local overview="$TARGET_ROOT/docs/project/structure/overview.md"
  local architecture="$TARGET_ROOT/docs/project/structure/architecture.md"
  local constraints="$TARGET_ROOT/docs/project/constraints.md"
  local frontend="$TARGET_ROOT/docs/project/frontend.md"
  local features="$TARGET_ROOT/docs/project/features/overview.md"
  local surfaces
  surfaces="$(detected_run_surfaces)"

  {
    printf '# 项目总览\n\n'
    printf '## 30 秒摘要\n\n'
    printf -- '- 项目名称：`%s`\n' "$PROJECT_NAME"
    printf -- '- 项目根目录：`%s`\n' "$PROJECT_ROOT_FOR_TEMPLATE"
    printf -- '- 技术栈：`%s`\n' "$STACK_NAME"
    printf -- '- 运行面：%s\n' "$surfaces"
    printf -- '- 初始化自动侦察：已根据目录和配置文件生成基础项目地图，业务定位仍需后续按真实需求补充。\n\n'
    printf '## 核心目录\n\n'
  } > "$overview"
  append_detected_directories_table "$overview"
  {
    printf '\n## 关键配置文件\n\n'
  } >> "$overview"
  append_detected_files_table "$overview"
  {
    printf '\n## 待人工补充\n\n'
    printf -- '- 产品或工具定位。\n'
    printf -- '- 主要用户流程。\n'
    printf -- '- 核心业务模块与长期需求链接。\n'
  } >> "$overview"

  {
    printf '# 项目架构\n\n'
    printf '## 30 秒摘要\n\n'
    printf -- '- 技术栈：`%s`\n' "$STACK_NAME"
    printf -- '- 运行面：%s\n' "$surfaces"
    printf -- '- 初始化自动侦察：已记录可见目录、配置和入口候选；分层模型需在首次代码任务中按实际调用关系补充。\n\n'
    printf '## 入口与平台候选\n\n'
  } > "$architecture"
  append_detected_directories_table "$architecture"
  {
    printf '\n## 配置与依赖候选\n\n'
  } >> "$architecture"
  append_detected_files_table "$architecture"
  {
    printf '\n## 依赖规则\n\n'
    printf -- '- 低层不应依赖高层。\n'
    printf -- '- UI 或入口层不应绕过 service/runtime/repo 等项目既有边界。\n'
    printf -- '- 新增依赖、跨层访问或共享工具扩张，需要在对应 design doc 或 active plan 中说明理由。\n'
  } >> "$architecture"

  {
    printf '# 功能文档总览\n\n'
    printf '## 30 秒摘要\n\n'
    printf -- '- 初始化自动侦察：已建立功能文档入口，具体功能模块需在首次需求侦察或功能改动时补充。\n'
    printf -- '- 新增或明显修改用户可见功能后，应按需在本目录新增或更新对应功能文档。\n\n'
    printf '## 功能模块\n\n'
    printf '| 功能 | 文档 | 状态 | 备注 |\n'
    printf '| --- | --- | --- | --- |\n'
    printf '| 待补充 | 待补充 | open | 初始化自动侦察未猜测业务功能 |\n\n'
    printf '## 维护规则\n\n'
    printf -- '- 功能文档记录长期有效的业务逻辑，不记录一次性开发过程。\n'
    printf -- '- 每次需求的开发方案写入 `docs/design/`。\n'
    printf -- '- 当前执行步骤和证据写入 `docs/exec-plans/active/` 与 `docs/reports/`。\n'
  } > "$features"

  {
    printf '# 前端与交互规则\n\n'
    printf '## 30 秒摘要\n\n'
    printf -- '- 初始化自动侦察：运行面为 %s。\n' "$surfaces"
    printf -- '- 先遵循项目已有设计系统和组件约定。\n'
    printf -- '- UI 改动必须覆盖 loading、empty、error、success、retry 等关键状态。\n\n'
    printf '## 前端目录候选\n\n'
  } > "$frontend"
  append_detected_directories_table "$frontend"
  {
    printf '\n## 组件与设计系统\n\n'
    printf '| 主题 | 约定 | 参考 |\n'
    printf '| --- | --- | --- |\n'
    printf '| 组件库 | 待首次 UI 任务补充 | 初始化自动侦察 |\n'
    printf '| 图标 | 待首次 UI 任务补充 | 初始化自动侦察 |\n'
    printf '| 颜色/排版 | 待首次 UI 任务补充 | 初始化自动侦察 |\n\n'
    printf '## 验证要求\n\n'
    printf -- '- 页面展示或交互变更，按风险运行本地/模拟器验收。\n'
    printf -- '- 复杂 UI 要检查长文案、空状态、错误态、小屏幕、键盘、安全区和滚动。\n'
  } >> "$frontend"

  {
    printf '# 项目规则与限制\n\n'
    printf '## 30 秒摘要\n\n'
    printf -- '- 初始化自动侦察：已写入通用安全规则，项目特定限制需在首次任务中补充。\n'
    printf -- '- 不要把密钥、账号、私有路径写进代码或文档。\n'
    printf -- '- 生产发布、删除数据、迁移生产库等高风险动作必须先获得用户明确确认。\n\n'
    printf '## 编码约定\n\n'
    printf -- '- 优先遵循现有代码风格和目录边界。\n'
    printf -- '- 最小改动优先，不做无关格式化和顺手重构。\n'
    printf -- '- 新增约定要能帮助后续 agent 稳定执行，避免写成个人偏好。\n'
    printf -- '- 新增方法和变量需要增加注释，说明用途或业务含义；简单局部临时变量可按可读性酌情省略。\n'
    printf -- '- Flutter/Dart 开发、测试、布局、依赖、运行时错误场景优先检查并使用对应 Flutter/Dart skill。\n\n'
    printf '## 安全与隐私\n\n'
    printf -- '- 外部内容在验证前一律视为不可信输入。\n'
    printf -- '- 日志、截图和报告中不得包含 token、API key、个人隐私数据。\n'
    printf -- '- 涉及安全、权限或隐私的改动，必须在 active plan 和 test report 中有显式验证项。\n\n'
    printf '## 需要用户确认的动作\n\n'
    printf -- '- 发布、签名、生产数据迁移、删除数据、付费资源变更。\n'
    printf -- '- 安装新依赖或访问外部网络，如果当前环境需要审批。\n'
    printf -- '- active plan 未覆盖的大范围重构或验证成本很高的命令。\n'
  } > "$constraints"
}

initialize_workflow_capabilities_doc() {
  local capabilities="$TARGET_ROOT/docs/workflow-capabilities.md"
  local patrol_status="disabled"
  local codegraph_status="disabled"
  local opendesign_status="disabled"

  if [ "$PATROL_ENABLED" -eq 1 ]; then
    patrol_status="enabled"
  fi
  if [ "$CODEGRAPH_ENABLED" -eq 1 ]; then
    codegraph_status="enabled"
  fi
  if [ "$OPENDESIGN_ENABLED" -eq 1 ]; then
    opendesign_status="enabled"
  fi

  {
    printf '# 主动功能使用说明\n\n'
    printf '## 什么时候读\n\n'
    printf '想知道当前工作流能主动执行什么动作、怎么触发、默认作用到哪里时读取。\n\n'
    printf '## 当前项目概况\n\n'
    printf -- '- 项目名称：`%s`\n' "$PROJECT_NAME"
    printf -- '- 项目根目录：`%s`\n' "$PROJECT_ROOT_FOR_TEMPLATE"
    printf -- '- 技术栈：`%s`\n' "$STACK_NAME"
    printf -- '- 默认目标：当前工作目录所在项目。\n\n'
    printf '## 主动功能\n\n'
    printf '| 功能 | 状态 | 对话触发方式 | 默认目标 | 产出 |\n'
    printf '| --- | --- | --- | --- | --- |\n'
    printf '| 项目深度扫描并回填 | enabled | `进行项目深度扫描并回填` | 当前工作目录项目 | `docs/project/*`、`.agent/traces/*-recon-project.json` |\n'
    printf '| 校验当前工作流 | enabled | `校验当前工作流` | 当前工作目录项目 | 运行 `scripts/validate_target.sh` |\n'
    printf '| 同步当前工作流到最新版 | enabled | `同步当前工作流到最新版` | 当前工作目录项目 | 工作流升级 dry-run 或 apply |\n'
    printf '| 修复或补齐当前工作流 | enabled | `修复当前工作流` / `补齐当前工作流` | 当前工作目录项目 | 补齐缺失 workflow 文件 |\n'
    printf '| 测试用例驱动验证 | enabled | `需要测试用例` / `根据需求生成测试用例并执行测试` | 当前需求 | `docs/test-cases/<requirement-id>.md`、自动化测试与验收证据 |\n'
    printf '| Patrol 验收 | %s | `用 Patrol 验证这个需求` | 当前需求 | `docs/testing/patrol.md`、验收证据 |\n' "$patrol_status"
    printf '| CodeGraph 影响分析 | %s | `用 CodeGraph 做影响分析` | 当前需求 | `docs/tools/codegraph.md` 指引与分析证据 |\n' "$codegraph_status"
    printf '| Open Design 设计链路 | %s | `用 Open Design 生成设计稿` | 当前需求 | `docs/tools/opendesign.md` 指引与设计证据 |\n\n' "$opendesign_status"
    printf '## 项目深度扫描默认策略\n\n'
    printf -- '- 默认只补充缺失信息，不改已有描述。\n'
    printf -- '- 如果扫描结论会改动现有文字描述，应先向用户确认。\n'
    printf -- '- 脚本入口：`scripts/recon_project.sh <target-project-path>`；在对话里优先通过 Agent 触发。\n\n'
    printf '## 测试用例驱动验证\n\n'
    printf -- '- 当前状态：`enabled`。\n'
    printf -- '- 默认关闭：未明确提出测试用例要求时，不启用、不提醒，继续使用项目默认验证配置。\n'
    printf -- '- 开发前模式：需求解析后生成测试用例，用户确认后先生成自动化测试，再开发并复测。\n'
    printf -- '- 开发后模式：用户提供已完成需求时，根据原始需求生成测试用例，确认后直接生成并运行测试。\n'
    printf -- '- 需求依据：测试目标来自原始需求和验收标准，不能根据现有实现反向削弱断言。\n'
    printf -- '- 人工降级：无法自动化时记录原因、步骤、环境、证据和剩余风险，可人工验收完成。\n'
    printf -- '- 主要产出：`docs/test-cases/<requirement-id>.md`、自动化测试文件、`docs/reports/test-report.md` 和验收证据。\n\n'
    printf '## 最近一次项目深度扫描\n\n'
    printf '<!-- BEGIN AUTO-RECON:capabilities -->\n'
    printf -- '- 尚未运行项目深度扫描。\n'
    printf '<!-- END AUTO-RECON:capabilities -->\n\n'
    printf '## 文档路由\n\n'
    printf '| 场景 | 读取 |\n'
    printf '| --- | --- |\n'
    printf '| 看项目结构 | `docs/project/structure/overview.md` |\n'
    printf '| 看架构边界 | `docs/project/structure/architecture.md` |\n'
    printf '| 看功能模块 | `docs/project/features/overview.md` |\n'
    printf '| 看项目规则 | `docs/project/constraints.md` |\n'
    printf '| 看 UI/交互约定 | `docs/project/frontend.md` |\n'
  } > "$capabilities"
}

resolve_patrol_enabled() {
  if [ "$STACK_NAME" != "flutter" ]; then
    return 1
  fi

  local mode="${AGENT_WORKFLOW_PATROL:-ask}"
  case "$mode" in
    yes|true|1)
      return 0
      ;;
    no|false|0)
      return 1
      ;;
    ask|"")
      if [ -t 0 ] && [ -t 1 ]; then
        printf '%s\n' "检测到 Flutter 工作流。是否生成 Patrol 验收支持文件？[y/N]"
        local answer
        read -r answer || answer=""
        case "$answer" in
          y|Y|yes|YES)
            return 0
            ;;
        esac
      fi
      return 1
      ;;
    *)
      echo "Invalid AGENT_WORKFLOW_PATROL value: $mode" >&2
      echo "Allowed values: ask, yes, no" >&2
      exit 1
      ;;
  esac
}

resolve_codegraph_enabled() {
  local mode="${AGENT_WORKFLOW_CODEGRAPH:-ask}"
  case "$mode" in
    yes|true|1)
      return 0
      ;;
    no|false|0)
      return 1
      ;;
    ask|"")
      if [ -t 0 ] && [ -t 1 ]; then
        printf '%s\n' "是否生成 CodeGraph 可选增强配置（安装/索引说明，不自动安装）？[y/N]"
        local answer
        read -r answer || answer=""
        case "$answer" in
          y|Y|yes|YES)
            return 0
            ;;
        esac
      fi
      return 1
      ;;
    *)
      echo "Invalid AGENT_WORKFLOW_CODEGRAPH value: $mode" >&2
      echo "Allowed values: ask, yes, no" >&2
      exit 1
      ;;
  esac
}

resolve_opendesign_enabled() {
  local mode="${AGENT_WORKFLOW_OPENDESIGN:-ask}"
  case "$mode" in
    yes|true|1)
      return 0
      ;;
    no|false|0)
      return 1
      ;;
    ask|"")
      if [ -t 0 ] && [ -t 1 ]; then
        printf '%s\n' "是否生成 Open Design 可选增强说明（仅用户明确要求时使用）？[y/N]"
        local answer
        read -r answer || answer=""
        case "$answer" in
          y|Y|yes|YES)
            return 0
            ;;
        esac
      fi
      return 1
      ;;
    *)
      echo "Invalid AGENT_WORKFLOW_OPENDESIGN value: $mode" >&2
      echo "Allowed values: ask, yes, no" >&2
      exit 1
      ;;
  esac
}

PATROL_ENABLED=0
if resolve_patrol_enabled; then
  PATROL_ENABLED=1
  outputs+=(
    "docs/testing/patrol.md"
    "scripts/patrol_acceptance.sh"
  )
fi

CODEGRAPH_ENABLED=0
if resolve_codegraph_enabled; then
  CODEGRAPH_ENABLED=1
  outputs+=(
    "docs/tools/codegraph.md"
  )
fi

OPENDESIGN_ENABLED=0
if resolve_opendesign_enabled; then
  OPENDESIGN_ENABLED=1
  outputs+=(
    "docs/tools/opendesign.md"
  )
fi

PATROL_ENABLED_JSON=false
if [ "$PATROL_ENABLED" -eq 1 ]; then
  PATROL_ENABLED_JSON=true
fi
CODEGRAPH_ENABLED_JSON=false
if [ "$CODEGRAPH_ENABLED" -eq 1 ]; then
  CODEGRAPH_ENABLED_JSON=true
fi
OPENDESIGN_ENABLED_JSON=false
if [ "$OPENDESIGN_ENABLED" -eq 1 ]; then
  OPENDESIGN_ENABLED_JSON=true
fi

if [ "$FORCE" -ne 1 ]; then
  conflicts=()
  for path in "${outputs[@]}"; do
    if [ -e "$TARGET_ROOT/$path" ]; then
      conflicts+=("$path")
    fi
  done

  if [ "${#conflicts[@]}" -gt 0 ]; then
    echo "Refusing to overwrite existing files in $TARGET_ROOT:" >&2
    printf '  %s\n' "${conflicts[@]}" >&2
    echo "Re-run with --force to overwrite these workflow files." >&2
    exit 1
  fi
fi

render_template() {
  local source="$1"
  local dest="$2"
  mkdir -p "$(dirname "$dest")"

  PROJECT_NAME="$PROJECT_NAME" \
  PROJECT_ROOT="$PROJECT_ROOT_FOR_TEMPLATE" \
  STACK_NAME="$STACK_NAME" \
  CURRENT_DATE="$CURRENT_DATE" \
  KIT_VERSION="$KIT_VERSION" \
  TEMPLATE_REVISION="$TEMPLATE_REVISION" \
  PATROL_ENABLED_JSON="$PATROL_ENABLED_JSON" \
  CODEGRAPH_ENABLED_JSON="$CODEGRAPH_ENABLED_JSON" \
  OPENDESIGN_ENABLED_JSON="$OPENDESIGN_ENABLED_JSON" \
  PRIMARY_VERIFY_COMMAND="$PRIMARY_VERIFY_COMMAND" \
  STRICT_VERIFY_COMMAND="$STRICT_VERIFY_COMMAND" \
  TEST_COMMAND="$TEST_COMMAND" \
  START_COMMAND="$START_COMMAND" \
  DEPENDENCY_SYNC_COMMAND="$DEPENDENCY_SYNC_COMMAND" \
  BUILD_DOCS="$BUILD_DOCS" \
  LIGHTWEIGHT_VALIDATION_NOTE="$LIGHTWEIGHT_VALIDATION_NOTE" \
  E2E_TOOL_NAME="$E2E_TOOL_NAME" \
  E2E_TEST_COMMAND="$E2E_TEST_COMMAND" \
  E2E_SETUP_NOTE="$E2E_SETUP_NOTE" \
  PRIMARY_VERIFY_COMMAND_SHELL="$PRIMARY_VERIFY_COMMAND_SHELL" \
  STRICT_VERIFY_COMMAND_SHELL="$STRICT_VERIFY_COMMAND_SHELL" \
  TEST_COMMAND_SHELL="$TEST_COMMAND_SHELL" \
  START_COMMAND_SHELL="$START_COMMAND_SHELL" \
  DEPENDENCY_SYNC_COMMAND_SHELL="$DEPENDENCY_SYNC_COMMAND_SHELL" \
  E2E_TEST_COMMAND_SHELL="$E2E_TEST_COMMAND_SHELL" \
  perl -0pe '
    s/\{\{PROJECT_NAME\}\}/$ENV{PROJECT_NAME}/g;
    s/\{\{PROJECT_ROOT\}\}/$ENV{PROJECT_ROOT}/g;
    s/\{\{STACK_NAME\}\}/$ENV{STACK_NAME}/g;
    s/\{\{CURRENT_DATE\}\}/$ENV{CURRENT_DATE}/g;
    s/\{\{KIT_VERSION\}\}/$ENV{KIT_VERSION}/g;
    s/\{\{TEMPLATE_REVISION\}\}/$ENV{TEMPLATE_REVISION}/g;
    s/\{\{PATROL_ENABLED_JSON\}\}/$ENV{PATROL_ENABLED_JSON}/g;
    s/\{\{CODEGRAPH_ENABLED_JSON\}\}/$ENV{CODEGRAPH_ENABLED_JSON}/g;
    s/\{\{OPENDESIGN_ENABLED_JSON\}\}/$ENV{OPENDESIGN_ENABLED_JSON}/g;
    s/\{\{PRIMARY_VERIFY_COMMAND\}\}/$ENV{PRIMARY_VERIFY_COMMAND}/g;
    s/\{\{STRICT_VERIFY_COMMAND\}\}/$ENV{STRICT_VERIFY_COMMAND}/g;
    s/\{\{TEST_COMMAND\}\}/$ENV{TEST_COMMAND}/g;
    s/\{\{START_COMMAND\}\}/$ENV{START_COMMAND}/g;
    s/\{\{DEPENDENCY_SYNC_COMMAND\}\}/$ENV{DEPENDENCY_SYNC_COMMAND}/g;
    s/\{\{BUILD_DOCS\}\}/$ENV{BUILD_DOCS}/g;
    s/\{\{LIGHTWEIGHT_VALIDATION_NOTE\}\}/$ENV{LIGHTWEIGHT_VALIDATION_NOTE}/g;
    s/\{\{E2E_TOOL_NAME\}\}/$ENV{E2E_TOOL_NAME}/g;
    s/\{\{E2E_TEST_COMMAND\}\}/$ENV{E2E_TEST_COMMAND}/g;
    s/\{\{E2E_SETUP_NOTE\}\}/$ENV{E2E_SETUP_NOTE}/g;
    s/\{\{PRIMARY_VERIFY_COMMAND_SHELL\}\}/$ENV{PRIMARY_VERIFY_COMMAND_SHELL}/g;
    s/\{\{STRICT_VERIFY_COMMAND_SHELL\}\}/$ENV{STRICT_VERIFY_COMMAND_SHELL}/g;
    s/\{\{TEST_COMMAND_SHELL\}\}/$ENV{TEST_COMMAND_SHELL}/g;
    s/\{\{START_COMMAND_SHELL\}\}/$ENV{START_COMMAND_SHELL}/g;
    s/\{\{DEPENDENCY_SYNC_COMMAND_SHELL\}\}/$ENV{DEPENDENCY_SYNC_COMMAND_SHELL}/g;
    s/\{\{E2E_TEST_COMMAND_SHELL\}\}/$ENV{E2E_TEST_COMMAND_SHELL}/g;
  ' "$source" > "$dest"
}

render_template "$KIT_ROOT/templates/base/.agent/state/current-task.json.template" "$TARGET_ROOT/.agent/state/current-task.json"
render_template "$KIT_ROOT/templates/base/.agent/config.json.template" "$TARGET_ROOT/.agent/config.json"
render_template "$KIT_ROOT/templates/base/.agent/traces/README.md.template" "$TARGET_ROOT/.agent/traces/README.md"
render_template "$KIT_ROOT/templates/base/.agent/traces/schema.json.template" "$TARGET_ROOT/.agent/traces/schema.json"
render_template "$KIT_ROOT/templates/base/.agent/evals/README.md.template" "$TARGET_ROOT/.agent/evals/README.md"
render_template "$KIT_ROOT/templates/base/AGENTS.md.template" "$TARGET_ROOT/AGENTS.md"
render_template "$KIT_ROOT/templates/base/init.sh.template" "$TARGET_ROOT/init.sh"
render_template "$KIT_ROOT/templates/base/docs/index.md.template" "$TARGET_ROOT/docs/index.md"
render_template "$KIT_ROOT/templates/base/docs/verification.md.template" "$TARGET_ROOT/docs/verification.md"
render_template "$KIT_ROOT/templates/base/docs/process/verification.md.template" "$TARGET_ROOT/docs/process/verification.md"
render_template "$KIT_ROOT/templates/base/docs/process/failure-taxonomy.md.template" "$TARGET_ROOT/docs/process/failure-taxonomy.md"
render_template "$KIT_ROOT/templates/base/docs/process/badcase-analysis.md.template" "$TARGET_ROOT/docs/process/badcase-analysis.md"
render_template "$KIT_ROOT/templates/base/docs/acceptance_simulator.md.template" "$TARGET_ROOT/docs/acceptance_simulator.md"
initialize_workflow_capabilities_doc
render_template "$KIT_ROOT/templates/base/docs/test-cases/README.md.template" "$TARGET_ROOT/docs/test-cases/README.md"
render_template "$KIT_ROOT/templates/base/docs/coding-progress.md.template" "$TARGET_ROOT/docs/coding-progress.md"
render_template "$KIT_ROOT/templates/base/docs/feature_list.json.template" "$TARGET_ROOT/docs/feature_list.json"
render_template "$KIT_ROOT/templates/base/docs/session-handoff.md.template" "$TARGET_ROOT/docs/session-handoff.md"
render_template "$KIT_ROOT/templates/base/docs/project/structure/overview.md.template" "$TARGET_ROOT/docs/project/structure/overview.md"
render_template "$KIT_ROOT/templates/base/docs/project/structure/architecture.md.template" "$TARGET_ROOT/docs/project/structure/architecture.md"
render_template "$KIT_ROOT/templates/base/docs/project/constraints.md.template" "$TARGET_ROOT/docs/project/constraints.md"
render_template "$KIT_ROOT/templates/base/docs/project/frontend.md.template" "$TARGET_ROOT/docs/project/frontend.md"
render_template "$KIT_ROOT/templates/base/docs/project/features/overview.md.template" "$TARGET_ROOT/docs/project/features/overview.md"
initialize_project_docs
render_template "$KIT_ROOT/templates/base/docs/requirements/parsed-requirements.md.template" "$TARGET_ROOT/docs/requirements/parsed-requirements.md"
render_template "$KIT_ROOT/templates/base/docs/requirements/open-questions.md.template" "$TARGET_ROOT/docs/requirements/open-questions.md"
render_template "$KIT_ROOT/templates/base/docs/requirements/traceability.md.template" "$TARGET_ROOT/docs/requirements/traceability.md"
render_template "$KIT_ROOT/templates/base/docs/design/index.md.template" "$TARGET_ROOT/docs/design/index.md"
render_template "$KIT_ROOT/templates/base/docs/design/workflow-bootstrap.md.template" "$TARGET_ROOT/docs/design/workflow-bootstrap.md"
render_template "$KIT_ROOT/templates/base/docs/exec-plans/active/index.md.template" "$TARGET_ROOT/docs/exec-plans/active/index.md"
render_template "$KIT_ROOT/templates/base/docs/exec-plans/active/workflow-bootstrap.md.template" "$TARGET_ROOT/docs/exec-plans/active/workflow-bootstrap.md"
render_template "$KIT_ROOT/templates/base/docs/exec-plans/completed/index.md.template" "$TARGET_ROOT/docs/exec-plans/completed/index.md"
render_template "$KIT_ROOT/templates/base/docs/exec-plans/tech-debt-tracker.md.template" "$TARGET_ROOT/docs/exec-plans/tech-debt-tracker.md"
render_template "$KIT_ROOT/templates/base/docs/reports/eval-report.md.template" "$TARGET_ROOT/docs/reports/eval-report.md"
render_template "$KIT_ROOT/templates/base/docs/reports/test-report.md.template" "$TARGET_ROOT/docs/reports/test-report.md"
render_template "$KIT_ROOT/templates/base/scripts/acceptance_simulator.sh.template" "$TARGET_ROOT/scripts/acceptance_simulator.sh"

if [ "$PATROL_ENABLED" -eq 1 ]; then
  render_template "$KIT_ROOT/templates/base/docs/testing/patrol.md.template" "$TARGET_ROOT/docs/testing/patrol.md"
  render_template "$KIT_ROOT/templates/base/scripts/patrol_acceptance.sh.template" "$TARGET_ROOT/scripts/patrol_acceptance.sh"
  chmod +x "$TARGET_ROOT/scripts/patrol_acceptance.sh"
fi

if [ "$CODEGRAPH_ENABLED" -eq 1 ]; then
  render_template "$KIT_ROOT/templates/base/docs/tools/codegraph.md.template" "$TARGET_ROOT/docs/tools/codegraph.md"
fi

if [ "$OPENDESIGN_ENABLED" -eq 1 ]; then
  render_template "$KIT_ROOT/templates/base/docs/tools/opendesign.md.template" "$TARGET_ROOT/docs/tools/opendesign.md"
fi

chmod +x "$TARGET_ROOT/init.sh"
chmod +x "$TARGET_ROOT/scripts/acceptance_simulator.sh"
upsert_workflow_gitignore

echo "Generated agent workflow for $PROJECT_NAME"
echo "Target: $TARGET_ROOT"
echo "Stack: $STACK_NAME"
if [ "$PATROL_ENABLED" -eq 1 ]; then
  echo "Patrol: workflow support generated"
else
  echo "Patrol: skipped"
fi
if [ "$CODEGRAPH_ENABLED" -eq 1 ]; then
  echo "CodeGraph: optional support generated"
else
  echo "CodeGraph: skipped"
fi
if [ "$OPENDESIGN_ENABLED" -eq 1 ]; then
  echo "Open Design: optional support generated"
else
  echo "Open Design: skipped"
fi
echo
echo "Next steps:"
echo "  cd $TARGET_ROOT"
echo "  ./init.sh"
