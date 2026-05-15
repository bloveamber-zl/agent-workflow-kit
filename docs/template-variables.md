# 模板变量

生成器会替换 `templates/base` 中的占位符。

| 变量 | 来源 | 说明 |
| --- | --- | --- |
| `{{PROJECT_NAME}}` | 目标目录名或 `--project-name` | 项目名称 |
| `{{PROJECT_ROOT}}` | 目标项目绝对路径 | 项目根目录 |
| `{{STACK_NAME}}` | `--stack` | 技术栈名称 |
| `{{CURRENT_DATE}}` | 系统日期 | 生成日期 |
| `{{PRIMARY_VERIFY_COMMAND}}` | stack 配置 | 默认轻量验证命令 |
| `{{STRICT_VERIFY_COMMAND}}` | stack 配置 | 严格验证命令 |
| `{{TEST_COMMAND}}` | stack 配置 | 测试命令 |
| `{{START_COMMAND}}` | stack 配置 | 启动命令 |
| `{{DEPENDENCY_SYNC_COMMAND}}` | stack 配置 | 依赖同步命令 |
| `{{BUILD_DOCS}}` | stack 配置 | 构建文档提示 |
| `{{LIGHTWEIGHT_VALIDATION_NOTE}}` | stack 配置 | 轻量验证说明 |

脚本内部还会生成 shell 字面量变量，用于安全写入 `init.sh`：

- `{{PRIMARY_VERIFY_COMMAND_SHELL}}`
- `{{STRICT_VERIFY_COMMAND_SHELL}}`
- `{{TEST_COMMAND_SHELL}}`
- `{{START_COMMAND_SHELL}}`
- `{{DEPENDENCY_SYNC_COMMAND_SHELL}}`

新增变量时需要同步更新：

1. `scripts/generate_workflow.sh`
2. `docs/template-variables.md`
3. 相关模板文件
4. `scripts/self_test.sh`
