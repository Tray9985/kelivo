# Kelivo PRD

本文档记录已实现的产品需求，供后续迭代参考。

---

## 1. 供应商列表精简

- 内置供应商只保留 **OpenRouter**，其余内置供应商全部移除
- 存量用户已配置的非 OpenRouter 供应商数据不受影响（仍可正常使用）

---

## 2. 添加供应商时支持自定义 Request Header

- 添加供应商的表单中提供自定义请求 Header 的输入区域
- 支持添加多条 Header，每条包含 Header 名称和 Header 值
- 支持删除已添加的 Header 条目
- 自定义 Header 随供应商配置一起保存

---

## 3. 自定义 Header 对所有 API 请求生效

- 供应商级别的自定义 Request Header 必须附加到该供应商的**所有** API 请求上
- 包括但不限于：聊天请求、模型列表拉取、连通性测试

---

## 4. 供应商编辑页支持查看和编辑自定义 Header

- 通过供应商设置按钮进入编辑弹窗后，能够查看该供应商已保存的自定义 Header
- 支持在编辑弹窗中新增、修改、删除自定义 Header
- 修改后自动保存

---

## 5. 模型选择弹窗去除列表滚动动画

- 聊天界面点击模型切换，弹出模型列表时，列表直接定位到当前已选模型，无滚动动画
- 弹窗打开时不出现列表从顶部滚动到目标位置的动画效果

---

## 6. 话题自动命名优化

- 标题生成时强制关闭思考模式，避免模型输出 `<think>` 内容污染标题
- 即使模型意外输出思考标签，生成的标题中需自动剥离 `<think>` / `<thought>` 块
- 标题生成只使用**第一条用户消息**作为上下文，不包含 AI 回复内容
- 标题 prompt 要求：使用用户所在语言、纯文本输出、不含 markdown 或标点、不超过 10 个词、只输出标题本身

---

## 7. Markdown 引用块直角

- 聊天消息中的 Markdown blockquote 渲染为直角（移除圆角）

---

## 8. 桌面端助手选择入口（Topbar 胶囊）

- 桌面端 Topbar 显示当前助手胶囊，替代原有模型胶囊
- 胶囊内容：助手名称（当「使用新助手头像样式」设置开启时，同时显示助手头像）
- 点击胶囊弹出助手切换 Sheet，选中后立即切换当前助手
- 「使用新助手头像样式」为用户可配置的显示设置项

---

## 9. 桌面端话题侧边栏布局

- 话题侧边栏支持左侧和右侧两种位置，由「话题面板位置」设置项控制
- **话题在左侧时**：左侧 sidebar 显示话题列表，AppBar 左端显示侧边栏切换图标；快捷键 `Cmd+]`（Win/Linux：`Ctrl+]`）切换左侧 sidebar 的显示/隐藏
- **话题在右侧时**：左侧 sidebar 和切换图标均隐藏；右侧 sidebar 显示话题列表，AppBar 右端显示右侧 sidebar 切换图标；快捷键 `Cmd+]`（Win/Linux：`Ctrl+]`）切换右侧 sidebar 的显示/隐藏
- 两种布局下，sidebar 均只显示话题内容，不显示助手列表

---

## 10. 桌面端快捷键

- `Cmd+]`（Win/Linux：`Ctrl+]`）：切换话题面板（根据当前话题位置切换对应侧的 sidebar）
- `Cmd+N`（Win/Linux：`Ctrl+N`）：新建话题
- `Cmd+,`（Win/Linux：`Ctrl+,`）：打开设置
- 已移除：助手面板切换快捷键（助手切换已移至 Topbar 胶囊）

---

## 11. OpenRouter 模型元数据自动同步

- 通过 OpenRouter 公开 API 自动获取模型元数据，写入 `modelOverrides`
- 同步字段：`orContextLength`（上下文长度）、`abilities`（`tools`、`reasoning`）、`inputModalities`（`image` 等）
- 支持单模型手动拉取（模型选择弹窗）和批量拉取（供应商详情页）
- 已有的手动覆盖配置不被自动同步覆盖，采用合并策略（`toFullOverrideMap`）
- OpenRouter 模型选择弹窗显示上下文长度（K/M 格式）和能力胶囊（工具调用、推理）

---

## 12. 发送前自动 Token 裁剪

- 发送消息前根据模型的 `orContextLength` 自动裁剪历史消息
- 裁剪分两阶段：Phase 1 按条数限制，Phase 2 按 token 预算裁剪（预留 2048 token 给补全）
- Token 估算公式：`⌈chars / 4⌉ + 4`，保守估算，不依赖外部 tokenizer
- 无 `orContextLength` 时跳过 Phase 2，行为与原来一致

---

## 13. 桌面端聊天消息选中文字可拖拽滚动

- 在聊天消息列表中拖拽选中文字时，靠近列表上下边缘会自动触发滚动
- 修复原因：原有 `SelectionArea` 分散在各消息子项内部，Flutter 的自动滚动机制无法跨越边界生效
- 实现：将单个 `SelectionArea` 提升至整个消息列表（`MessageListView`）的外层，移除原有的 4 处消息级 `SelectionArea`
- 消息级右键菜单（翻译、复制、编辑等）不受影响；Cmd+C 文本复制快捷键仍有效

---

## 14. 桌面端失焦时 streaming 持续渲染

- 修复：在 macOS 上切换到其他应用后，LLM 输出刷新和 loading 动画停止的问题
- 根因：macOS 切换应用时，Flutter 发出 `inactive → hidden` 生命周期序列，`hidden` 导致 `SchedulerBinding.framesEnabled = false`，所有帧调度（包括 `ValueNotifier` 刷新和 `AnimationController`）冻结
- 修复方式：在 `_HomePageState.didChangeAppLifecycleState` 中，当检测到 `hidden` + 桌面平台 + 窗口仅失焦（非最小化/隐藏）时，通过 `Future.microtask` 重新调用 `handleAppLifecycleStateChanged(inactive)`，将帧调度恢复为启用状态
- `DesktopWindowController` 新增 `isWindowBlurred` 追踪，用于区分"失焦但可见"与"真正隐藏"
