# 模板变量

生成器会替换 `templates/base` 中的占位符。

| 变量 | 来源 | 说明 |
| --- | --- | --- |
| `{{PROJECT_NAME}}` | 目标目录名或 `--project-name` | 项目名称 |
| `{{PROJECT_ROOT}}` | 目标项目绝对路径 | 项目根目录 |
| `{{STACK_NAME}}` | `--stack` | 技术栈名称 |
| `{{CURRENT_DATE}}` | 系统日期 | 生成日期 |
| `{{KIT_VERSION}}` | 根目录 `VERSION` | 生成器版本，用于排查脚本来源 |
| `{{TEMPLATE_REVISION}}` | `templates/VERSION` | 模板修订号，用于判断目标项目是否需要同步 |
| `{{PATROL_ENABLED_JSON}}` | 生成脚本 | 是否启用 Patrol 可选增强，JSON 布尔值 |
| `{{HARMONYOS_ENABLED_JSON}}` | 生成脚本 | 是否启用 HarmonyOS 依赖适配增强，JSON 布尔值 |
| `{{CODEGRAPH_ENABLED_JSON}}` | 生成脚本 | 是否启用 CodeGraph 可选增强，JSON 布尔值 |
| `{{OPENDESIGN_ENABLED_JSON}}` | 生成脚本 | 是否启用 Open Design 可选增强，JSON 布尔值 |
| `{{PRIMARY_VERIFY_COMMAND}}` | stack 配置 | 默认轻量验证命令 |
| `{{STRICT_VERIFY_COMMAND}}` | stack 配置 | 严格验证命令 |
| `{{TEST_COMMAND}}` | stack 配置 | 测试命令 |
| `{{START_COMMAND}}` | stack 配置 | 启动命令 |
| `{{DEPENDENCY_SYNC_COMMAND}}` | stack 配置 | 依赖同步命令 |
| `{{BUILD_DOCS}}` | stack 配置 | 构建文档提示 |
| `{{LIGHTWEIGHT_VALIDATION_NOTE}}` | stack 配置 | 轻量验证说明 |
| `{{E2E_TOOL_NAME}}` | stack 配置 | 推荐 E2E/高风险验收工具名称 |
| `{{E2E_TEST_COMMAND}}` | stack 配置 | 推荐 E2E/高风险验收命令 |
| `{{E2E_SETUP_NOTE}}` | stack 配置 | E2E/高风险验收接入说明 |

脚本内部还会生成 shell 字面量变量，用于安全写入 `init.sh`：

- `{{PRIMARY_VERIFY_COMMAND_SHELL}}`
- `{{STRICT_VERIFY_COMMAND_SHELL}}`
- `{{TEST_COMMAND_SHELL}}`
- `{{START_COMMAND_SHELL}}`
- `{{DEPENDENCY_SYNC_COMMAND_SHELL}}`
- `{{E2E_TEST_COMMAND_SHELL}}`

当前 V2 运行时模板会复用已有变量初始化 `.agent/config.json`、`.agent/traces/schema.json`、`.agent/evals/README.md`、`docs/process/badcase-analysis.md`、`docs/reports/eval-report.md`，并使用 E2E 变量生成高风险验收说明。

每次工作流模板、生成行为或同步规则变动时，更新 `templates/VERSION`；生成器脚本能力变动时同步更新根目录 `VERSION`。目标项目的 `.agent/config.json` 会记录 `workflow_version`、`template_revision` 和 `kit_version`，便于批量判断是否需要同步。

新增变量时需要同步更新：

1. `scripts/generate_workflow.sh`
2. `docs/template-variables.md`
3. 相关模板文件
4. `scripts/self_test.sh`

`scripts/generate_workflow.sh --project-root <path>` 只用于升级脚本等中间渲染场景，让模板中的 `{{PROJECT_ROOT}}` 指向真实目标项目，而输出文件仍写入临时目录。
