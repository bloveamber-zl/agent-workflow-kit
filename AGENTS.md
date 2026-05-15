# AGENTS.md

这个仓库用于维护可复用的 agent 工作流模板和生成脚本。目标是让 Codex 或其他 coding agent 读取本项目后，可以为不同技术栈项目生成一致的开工、验证、记录和交接流程。

## 项目偏好

- 默认中文回复，言简意赅。
- 优先保持模板通用，不把单个业务项目的规则写死到 base 模板。
- 脚本保持无外部依赖；默认使用 Bash、awk、perl、python3 等常见系统工具。
- 新增模板变量时，同时更新 `docs/template-variables.md`、`README.md` 和 `scripts/generate_workflow.sh`。
- 修改生成行为后，运行 `scripts/self_test.sh`。

## 工作规则

1. 先确认目标是改模板、改脚本，还是新增技术栈配置。
2. 不覆盖已有模板语义，除非同步更新文档说明。
3. 生成脚本默认不得覆盖目标项目已有文件，除非用户显式传 `--force`。
4. 技术栈配置只放命令差异；通用流程应留在 `templates/base`。
5. 不把密钥、账号、私有路径写入模板。
6. 新增方法和变量需要增加注释，说明用途或业务含义；简单局部临时变量可按可读性酌情省略。

## 验证

- 基础验证：`scripts/self_test.sh`
- 单目标校验：`scripts/validate_target.sh <target-project-path>`
- 生成测试：`scripts/generate_workflow.sh <target-project-path> --stack generic`

## 收尾

- 更新相关文档。
- 记录新增或变更的模板变量。
- 保证 `scripts/self_test.sh` 通过。
