# Kelivo PRD

本文档记录已实现的产品需求，供后续迭代参考。

构建：
fvm flutter run --release -d iPhoneID
fvm flutter build macos --release
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

## 11. 模型元数据自动同步（models.dev）

- 通过 [models.dev](https://models.dev) 公开 API（`https://models.dev/api.json`）自动获取模型元数据，写入 `modelOverrides`
- 同步字段：`contextLength`（上下文长度）、`maxOutputTokens`（最大输出）、`abilities`（`tool`、`reasoning`）、`input`（`image` 等）
- 支持单模型手动拉取（模型选择弹窗）和批量拉取（供应商详情页）
- 已有的手动覆盖配置不被自动同步覆盖，采用合并策略（`toFullOverrideMap`）
- `ModelInfo` 携带 `contextLength` 字段，由 `ModelOverrideResolver.applyModelOverride` 从 `contextLength` 写入
- **模型列表上下文大小徽章**：所有模型列表（移动端 `ModelTagWrap`、桌面端 `ModelCapsulesRow`）在能力徽章左侧显示上下文大小徽章（K/M 格式），按大小分段配色：
  - `< 32K`：橙色
  - `32K–200K`：主题 Primary 蓝
  - `200K–1M`：青绿色
  - `≥ 1M`：绿色

---

## 12. 发送前自动 Token 裁剪

- 发送/重发消息前，基于模型的 `orContextLength` 自动裁剪历史消息，防止 API 报"输入过长"错误
- **裁剪分两阶段**，turn 完整性在两阶段均受保护（`_advanceToUserMessage` 确保裁剪后首条消息始终是 user 角色，不留悬空的 assistant/tool 消息）：
  - **Phase 1（条数）**：按助手设置的 `contextMessageSize` 保留最新 N 条，超出的从头部删除
  - **Phase 2（Token 预算）**：从最新消息向前累加估算 token，找到恰好超出预算的切点，一次性删除切点之前的所有消息；预留 2048 token 给补全输出
- **Token 估算**：`⌈chars / 2⌉ + 4`，相比英文惯用的 `chars/4` 更保守，适配中文/混合内容场景；不依赖外部 tokenizer
- **单一来源**：`MessageBuilderService.applyContextLimit` 是唯一裁剪入口，通过 `__srcId` 临时注解将 apiMessage 映射回 `ChatMessage.id`，返回 `firstVisibleMessageId`，由调用链逐级传递至 UI
- 无 `orContextLength` 时跳过 Phase 2，行为与原来一致

---

## 13. 上下文裁剪分割线

- 每次发送/重发后，若发生 Phase 2 token 裁剪，消息列表中在 AI 可见范围的第一条消息前插入红色分割线，标注「以上消息 AI 不可见」
- 分割线位置与实际发送给 API 的消息范围严格一致（同一计算来源）
- 切换会话或新建话题时分割线自动清除
- 分割线水平边距与消息气泡一致

---

## 14. 两步回到顶部

- 消息列表右侧快捷按钮「回到顶部」（双箭头上）的行为：
  - **第一次点击**（存在上下文裁剪分割线时）：滚动到分割线位置，让用户看到 AI 可见范围的起点
  - **第二次点击**：滚动到消息列表绝对顶部
- 用户手动滚动、切换会话后，状态重置，下次点击重新从分割线开始

---

## 15. 桌面端聊天消息选中文字可拖拽滚动

- 在聊天消息列表中拖拽选中文字时，靠近列表上下边缘会自动触发滚动
- 修复原因：原有 `SelectionArea` 分散在各消息子项内部，Flutter 的自动滚动机制无法跨越边界生效
- 实现：将单个 `SelectionArea` 提升至整个消息列表（`MessageListView`）的外层，移除原有的 4 处消息级 `SelectionArea`
- 消息级右键菜单（翻译、复制、编辑等）不受影响；Cmd+C 文本复制快捷键仍有效

---

## 16. 桌面端失焦时 streaming 持续渲染

- 修复：在 macOS 上切换到其他应用后，LLM 输出刷新和 loading 动画停止的问题
- 根因：macOS 切换应用时，Flutter 发出 `inactive → hidden` 生命周期序列，`hidden` 导致 `SchedulerBinding.framesEnabled = false`，所有帧调度（包括 `ValueNotifier` 刷新和 `AnimationController`）冻结
- 修复方式：在 `_HomePageState.didChangeAppLifecycleState` 中，当检测到 `hidden` + 桌面平台 + 窗口仅失焦（非最小化/隐藏）时，通过 `Future.microtask` 重新调用 `handleAppLifecycleStateChanged(inactive)`，将帧调度恢复为启用状态
- `DesktopWindowController` 新增 `isWindowBlurred` 追踪，用于区分"失焦但可见"与"真正隐藏"

---

## 17. macOS 启动图标更新

- 图标替换为以原始 Logo SVG（rsshub-color.svg）为主体、白色背景、Logo 居中占 80% 面积的方案
- 替换全部 7 个尺寸：16 / 32 / 64 / 128 / 256 / 512 / 1024px

---

## 18. 流式请求报错展示优化

- **Toast**：报错时固定显示"请求失败，请查看报错信息"，不再将原始错误字符串拼入 toast
- **消息气泡**：报错不再写入消息 content，改为独立的 `errorText` 字段存储原始错误
- **错误 UI**：在 assistant 消息气泡内，以与"深度思考"一致的折叠 UI 展示错误：
  - 收起态：淡红色背景，显示"请求失败：{错误首行}"，可点击展开
  - 展开态：显示完整原始错误原文
- 若流中断前已生成部分内容，部分内容正常显示，错误 UI 附在其后
- `ChatMessage` 模型新增 `@HiveField(20) String? errorText` 字段（向后兼容，旧消息该字段为 null）

---

## 19. 输入栏上下文用量圆环

- 输入栏底部右侧，发送按钮左侧，显示一个 18px 圆形进度环
- 仅在当前模型存在 `orContextLength` 时显示，且必须有已完成的 AI 消息（有真实 `promptTokens` 数据）才显示，否则隐藏
- **进度计算**：取最后一条已完成 AI 消息的 `promptTokens`（API 上报的真实输入 token 数）除以 `orContextLength`，完全准确，不依赖任何估算
- **三段配色**：< 70% 使用低透明度前景色；70–90% 橙色；≥ 90% 错误红色
- **Tooltip**：显示「已用 XK / YM」格式（如 `128K / 1M`）
- 移动端与平板/桌面端均显示，不进入 overflow 菜单

---

## 20. Token 计数千分符

- 消息列表右下角的 token 计数显示增加千分符（如 `206,673`）
- 实现：在 ARB 模板（`app_en.arb`）的 `@tokenDetailTotalTokens` 占位符 `count` 上添加 `"format": "decimalPattern"`，由 `flutter gen-l10n` 生成 `NumberFormat.decimalPattern` 格式化逻辑
- 其余三个 ARB 文件无需额外 `@` 元数据，格式化由模板驱动

---

## 21. 宽屏布局模式

- 设置项：「宽屏布局」，可在移动端「显示」设置页和桌面端「显示」设置面板中切换，持久化至 SharedPreferences（key: `display_widescreen_mode_v1`）
- 开启后，聊天消息列表与输入栏的最大宽度从 860px 扩展至 1290px（860 × 1.5）
- 常量定义在 `ChatLayoutConstants.maxWidescreenWidth = maxContentWidth * 1.5`
- 关闭侧边栏时两侧留白明显减少；侧边栏展开时因可用宽度受限，效果自然缩减
- 默认关闭，不影响存量用户布局

---

## 22. 联网搜索内容提取（Exa）

- Exa 搜索服务使用 `highlights` 模式替代 `text` 模式：`contents.highlights: { query, maxCharacters: 1500 }`
- `highlights` 由 Exa 模型从页面中提取与 query 最相关的段落，相比直接截取正文前 N 字符质量更高
- 响应中 `highlights` 字段为字符串数组，拼接后写入 `SearchResultItem.text`
- `query` 参数传入搜索词，引导 Exa 提取更精准的相关段落

---

## 23. 流式响应全程 Loading 指示

- assistant 消息气泡在 `isStreaming = true` 期间，始终在内容末尾显示三点 Loading 指示器
- 覆盖所有阶段：等待首个 token、工具调用中、思考（reasoning）中、思考结束等待正文、正文流式输出中
- `isStreaming` 变为 false（正常结束、用户停止、异常中断）后指示器自动消失

---

## 24. 默认助手提示词与示例助手移除

- 移除「示例助手」，首次启动只创建「默认助手」
- 默认助手从空提示词升级为包含以下内容的实质性提示词（通过 ARB key `assistantProviderDefaultAssistantSystemPrompt` 管理，含占位符）：
  - 设备上下文：当前时间、设备语言、时区、设备型号、系统版本
  - 回答格式要求：使用 Markdown，避免文字墙，先给结论
  - 主动搜索策略：时效性内容、文档引用、覆盖不足时无需等待用户提示自动搜索
  - 语言规则：默认使用设备语言，除非用户明确指定

---

## 25. 助手编辑页提示词「恢复默认」按钮

- 系统提示词输入框右下角增加「恢复默认」文字按钮
- 点击后将输入框内容替换为默认提示词（同 `assistantProviderDefaultAssistantSystemPrompt`）并立即保存
- 桌面端：鼠标悬停时显示 `click` 指针，hover/press 透明度动画；移动端：触摸 press 透明度动画

---

## 27. 模型目录匹配弹窗优化

- 弹窗文案去除 OpenRouter 相关描述，改为通用表述：「选择模型」/ 「未能自动匹配此模型，请手动选择模型以获取模型信息」
- 搜索输入框改为**子序列（subsequence）模糊匹配**：将查询词和模型 ID 均 normalize（转小写、去除 `/`、`-`、`.`），检查查询词的每个字符是否按序出现在 ID 中
  - 例：输入 `openminimax2` 可命中 `opencode-go/minimax-m2.5`
  - 支持：片段记忆、缩写、跳过分隔符；不支持：拼写错误、词序颠倒

---

## 26. 显示搜索引用开关

- 设置 → 显示 新增「显示搜索引用」开关（默认开启），持久化至 SharedPreferences（key: `display_show_search_citations_v1`）
- 关闭后：
  - 消息内嵌 `[citation](index:id)` 徽章不渲染（`MarkdownWithCodeHighlight` 的 `showCitations` 参数控制）
  - 消息底部来源汇总卡片（`_SourcesSummaryCard`）不显示
- 搜索工具本身的执行和结果不受影响，LLM 仍会输出引用标记（仅渲染层抑制）
