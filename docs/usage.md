# 使用指南

## 目标

把统一的 agent 工作流安装到任意项目中，让后续 coding agent 可以只依赖仓库文件恢复上下文、解析需求、了解项目、生成开发文档、执行计划、运行验证并交接。

## 标准流程

```bash
scripts/generate_workflow.sh /path/to/project --stack flutter
cd /path/to/project
./init.sh
```

如果目标项目已有同名文件，生成器会停止并提示冲突文件。确认要重建时再使用 `--force`。

## 通过 Codex Skill 使用

本仓库提供 `agent-workflow` skill 源码，可安装到本机 Codex：

```bash
scripts/install_codex_skill.sh
```

安装后在任意目标项目中让 Codex 使用 `$agent-workflow`。Skill 会：

- 默认把当前目录作为目标项目。
- 按项目文件自动判断技术栈。
- 无工作流时调用 `scripts/generate_workflow.sh`。
- 已有工作流时先读取现状，再做窄范围优化。
- 修改后调用 `scripts/validate_target.sh` 校验。

## 技术栈选择

- Flutter：选择 `--stack flutter`
- Node：选择 `--stack node`
- Python：选择 `--stack python`
- 其他：选择 `--stack generic`，生成后手动改 `init.sh` 中的命令

## 适配建议

- 先跑轻量验证，再考虑严格分析或完整测试。
- 构建、签名、发布等耗时或高风险命令不要放进默认 `./init.sh`。
- 平台构建文档可以单独写在目标项目的 `docs/build_*.md`。
- 私有路径、账号、密钥不要写进模板。

## 文档分层

生成后的文档按渐进披露组织：

- `docs/index.md`：阅读路由器。
- `docs/feature_list.json`：项目级需求索引。
- `docs/coding-progress.md`：会话级进度日志。
- `docs/project/`：项目理解、特定规则、限制、验证事实和风险。
- `docs/requirements/`：解析后的需求、待确认问题和追踪矩阵。
- `docs/design/`：结合当前项目后的开发文档。
- `docs/exec-plans/active/`：用户确认后的执行计划和步骤状态。
- `docs/reports/test-report.md`：测试、失败、修复和复测记录。

需求实现时不要把详细步骤写进 `feature_list.json`，也不要把完整计划写进 `coding-progress.md`；它们只负责索引和最近状态。
