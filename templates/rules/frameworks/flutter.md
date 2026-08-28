## Flutter 规则

- `build` 中存在多个职责明确的元素时按职责提取；简单局部结构优先使用返回 `Widget` 的方法。
- 内容复杂、参数较多、状态边界明确或需要复用时才创建 Widget 类；内容很多或跨模块复用时再拆独立 Dart 文件。
- 状态、Controller 和生命周期由原有页面或 Logic 持有，提取后的 Widget 通过参数与回调通信。
- UI 改动验证 loading、empty、error、success、retry、长文案、小屏、安全区、键盘和滚动边界。
