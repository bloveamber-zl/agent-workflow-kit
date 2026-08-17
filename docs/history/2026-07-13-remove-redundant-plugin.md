# 执行计划：移除冗余第三方流程插件

| 步骤 | 状态 | 内容 | 验证 |
| --- | --- | --- | --- |
| step-01 | verified | 移除两个 Codex 插件配置 | `codex plugin remove` 返回成功 |
| step-02 | verified | 清理全局、项目和模板指令，迁移历史文档路径 | 仓库残留检查为空 |
| step-03 | verified | 回归验证工作流生成与校验链路 | `scripts/self_test.sh` 通过 |
