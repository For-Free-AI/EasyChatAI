# EasyChatAI



这是一款**轻量级 Android AI 对话客户端**。支持任意 **OpenAI Chat Completions 兼容 API** 与 **Anthropic Messages 兼容 API**，无需注册任何账号——填入你自己的 API 地址和 Key 即可开始对话。所有数据仅保存在本机，不上传、不追踪。

> 当前版本：**v1.8.4** · Flutter **3.44.9** / Dart 3.12 · 仅支持 Android

---


## 📱 兼容性

### 系统与设备
| 项目 | 要求 |
|---|---|
| 操作系统 | Android **7.1（API 24）及以上**（`minSdk 24`） |
| 最高版本 | Android 16（`targetSdk 36`） |
| 屏幕 | 手机 / 平板自适应，支持深浅色与 OLED 纯黑 |
| 网络 | 需联网访问你配置的 API 服务；**无需 Root、无需 Google Play 服务** |


---


| 安装包 | 适用架构 | 体积 | 说明 |
|---|---|---|---|
| `EasyChatAI_arm64.apk` | `arm64-v8a` | 约 21MB | **推荐**，2017 年后的绝大多数手机 / 平板 |
| `EasyChatAI_arm32.apk` | `armeabi-v7a`（32 位） | 约 19MB | 兼容版，仅用于较老的低端 32 位设备 |

> 不确定的话**先装 arm64**，绝大多数设备都是 64 位；若提示「应用未安装 / 解析包错误」再换 arm32。两个包功能完全相同，只是适配的 CPU 不同。x86 / x86_64（模拟器、少数 Intel 平板）未打包，如需可用源码自行构建。

### API 服务端兼容性
- **OpenAI Chat Completions 兼容**：OpenAI、DeepSeek、Agnes 及绝大多数第三方中转
- **Anthropic Messages 兼容**：Anthropic 官方及其兼容端点
- 自定义服务只需在设置页选择对应协议 + 填 Base URL / Key，无需改代码

---

## ✨ 功能特性

### 对话核心
- **双协议支持**：OpenAI Chat Completions 兼容 + Anthropic Messages 兼容（x-api-key 鉴权、system 独立字段、事件制流式解析、扩展 thinking 映射），一套界面通吃两大生态
- **流式对话**：SSE 逐字输出，带打字机闪烁光标动画
- **任意 API 兼容**：内置 Agnes / DeepSeek / OpenAI / Anthropic 预设，也支持完全自定义（Base URL + API Key + 协议 + 模型）
- **模型自动拉取**：填入 API 后一键拉取 `/models` 列表，弹窗搜索过滤点选，也支持手填
- **深度思考（思维链）**：OpenAI 格式走 `enable_thinking` + `reasoning_content`；Anthropic 格式走 `thinking.budget_tokens` + `thinking_delta` 事件；流式思维链可展开/收起
- **联网搜索**：可配置独立搜索 API（DeepSeek Search 或自定义），由模型自动判断是否需要搜索（双协议下均可用）
- **自动命名对话**：首轮对话后自动生成标题（独立非流式请求，中文无乱码，双协议下均可用）
- **Token 用量统计**：每条回复显示 prompt / completion / total tokens（双协议各自从对应帧提取）
- **角色预设**（v1.8）：内置通用 / 翻译 / 编程 / 写作 / 简洁五种人设，设置页「角色预设 →」入口点开弹窗切换系统提示词，也支持自定义（全局生效）；v1.8.1 起收进弹窗，不再平铺占屏

### 阅读与交互
- **Markdown 全渲染**：标题、列表、表格、引用、行内代码
- **代码块语法高亮**：180+ 语言着色、顶部语言标签、右上角一键「复制」按钮，长代码横向滚动
- **气泡内自由选择**：长按 AI 回复或用户消息即可选择复制，支持**气泡内跨段落连续拖选**；选择手柄热区从 22dp 放大到 34dp、选中高亮用主题主色，更好拖、看得清（v1.7 精修）；长按菜单新增「在大面板中选择」入口
- **选择复制面板**：静态大页面 + 连续可选文本，跨段落拖选从容；点面板外部即取消选择。入口：AI 回复操作条按钮 / 用户消息双击 / 长按菜单「在大面板中选择」
- **消息操作条**：复制全部、Token 用量、已联网搜索标记
- **滚动规则**：生成内容时视口完全静止，滚动完全由用户驱动；上滑查看历史不被打断，「回到底部」按钮弹性缩放出现

### 界面
- **Material 3 主题**：种子色配色系统、胶囊按钮、大圆角卡片
- **深浅色 / OLED 纯黑**：跟随系统 / 浅色 / 深色三档切换，深色下可开启 OLED 省电纯黑
- **活泼动效**：气泡渐入上浮、思考圆点波浪跳动、发送按钮按压缩放回弹、问候语分层入场
- **DeepSeek 式侧边栏**：对话列表管理、批量勾选删除、长按重命名、普通模式左滑直接删除；主界面左滑即可呼出
- **会话搜索**（v1.8）：侧边栏搜索框，按标题或消息内容本地实时过滤
- **数据备份**（v1.8.1 优化）：导出时用系统文件管理器自选保存位置（支持单条对话导出——长按对话 →「导出此对话」，或导出全部）；导入放宽文件类型并区分取消/格式错误，按会话 id 去重合并，不覆盖已有对话。全程本地，不上传服务器
- **中文本地化**：文本选择菜单（全选/复制/粘贴）等系统级文案全中文

---

## 🛠 技术栈

| 层面 | 技术 |
|---|---|
| 框架 | Flutter 3.44.9（Impeller 渲染引擎） |
| 语言 | Dart 3.12 |
| 状态管理 | Provider 6.x |
| 网络 | http 1.x（SSE 流式解析，UTF-8 强制解码防中文乱码；协议适配器模式） |
| 本地存储 | shared_preferences（JSON 序列化会话） |
| Markdown | flutter_markdown 0.7.x + markdown 7.x |
| 语法高亮 | flutter_highlight（highlight.js 移植） |
| 数据备份 | file_picker（v1.8.1：系统文件管理器选保存位置 + 文件导入） |
| Android 构建 | Gradle 8.14 / AGP 8.11.1 / Kotlin 2.2.20 / compileSdk 36（v1.8 升级，告警清零） |



### 使用前配置

安装后首次打开会引导你进入「连接提供商」：

1. 选择预设（Agnes / DeepSeek / OpenAI / Anthropic）或「自定义」
2. 填入 **API 地址（Base URL）** 与 **API Key**
3. 「自定义」时在 SegmentedButton 里选择接口协议（OpenAI 兼容 / Anthropic 兼容）；预设则自动决定协议
4. 点「拉取列表」选择模型，或直接手填
5. 连接检查通过后即可对话
6. （可选）在「联网搜索配置」中填入搜索 API，即可启用联网搜索

所有配置与对话历史仅保存在手机本地（`shared_preferences`），卸载即清除。

---

## 🧩 核心实现说明（给贡献者）

- **SSE 流式解析**：`api_service.dart` 按行解析 `data:` 帧，逐字回调；`<think>` 标签跨块用状态机处理，思维链与正文分别写入消息模型
- **中文乱码防护**：所有响应体强制 `utf8.decode(response.bodyBytes)`，避免 ISO-8859-1 解码导致标题乱码
- **思考开关**：通过 `chat_template_kwargs.enable_thinking` 下发；服务端返回 400 时自动去掉该字段重试，兼容不支持思考参数的服务
- **自动命名**：独立的非流式请求生成标题，不污染主对话上下文
- **usage 统计**：`stream_options.include_usage`，从最后一帧 SSE 提取
- **滚动规则**：滚动通知区分"用户手势"与"程序滚动"，生成时视口完全静止
- **代码块高亮**：`MarkdownElementBuilder` 接管 `pre` 标签，`flutter_highlight` 着色 + 复制按钮，纯 Flutter 组件不影响列表滚动。注意 flutter_markdown 0.7.x 的坑：给块级标签注册构建器后，其内部文本会路由到 `builders[tag].visitText`（基类默认返回 null），导致内部状态残留并在解析结束时触发 `_inlines.isEmpty` 断言——因此代码卡片必须在 `visitText` 中渲染（v1.8.2 修复，此前含代码块的回复会崩溃），回归测试见 `test/markdown_regress_test.dart`
- **协议适配器模式**：`ProtocolAdapter` 统一接口 + OpenAI/Anthropic 两套实现，`api_service.dart` 门面按配置分发；上层 Provider/页面完全不感知协议差异；新增第三种协议只需再写一个适配器
- **放大手柄**（v1.7）：`BigHandleTextSelectionControls` 继承 Material 默认控件，仅放大尺寸到 34dp，`selectionControls` 分别传给气泡 SelectionArea / SelectableText / 选择面板；配色由主题 `TextSelectionThemeData` 统一注入
- **测试覆盖**（v1.7→v1.8.4）：`test/protocol_test.dart` 覆盖两种协议的请求体、SSE 正文/思维链/用量解析、模型过滤；`test/widget_test.dart` 覆盖消息/会话 JSON 往返、旧数据兼容与界面渲染；`test/backup_test.dart` 覆盖备份编解码与按 id 去重合并；`test/markdown_regress_test.dart` 覆盖代码块渲染回归（v1.8.2）；`test/chat_input_test.dart` 覆盖输入框重绘后的渲染（v1.8.3）；`test/prompt_presets_test.dart` 覆盖快捷提示词随机抽取（v1.8.4），共 50 项
- **数据备份**（v1.8.1）：`backup_service.dart` 的 `encode/decode/merge` 为纯函数（易测）；导出用 `FilePicker.saveFile(bytes:)` 走系统文件管理器（Android SAF / ACTION_CREATE_DOCUMENT）让用户自选位置，导入用 `FileType.any` + bytes 读取（绕开 content:// 路径问题），并用 `ImportResult` 区分取消/格式错误/成功；merge 按会话 id 去重，导入不覆盖已有对话
- **构建链**（v1.8）：compileSdk/AGP/Kotlin 三步分别升级、逐步构建验证；`gradle.properties` 堆提到 3G 并关闭 Jetifier（避免 Kotlin 2.2.20 编译期 JetifyTransform OOM）；Maven 走阿里云镜像 + 60s 超时

---

## 🗺 版本历史（摘要）

| 版本 | 主要内容 |
|---|---|
| v1.0 | 流式对话、API 配置、本地历史、Markdown |
| v1.1–v1.2 | 模型切换、思考开关、自动命名、品牌与界面打磨 |
| v1.3 | 联网搜索、Token 用量、复制全部 |
| v1.4 | 思维链展示、中文选择菜单、侧边栏管理、滚动优化 |
| v1.5 | Flutter 3.44.9 升级、Material 3、代码块语法高亮、动效、OLED 模式 |
| v1.6.0 | **双协议支持（OpenAI + Anthropic 兼容）**、设置页重构（分组卡片、模型列表选择、协议切换、状态徽标） |
| v1.7.0 | **选择体验精修**（手柄热区 22→34dp、主题色高亮、长按菜单加「大面板选择」入口）+ **补齐单元测试**（协议 SSE 解析、模型/会话 JSON 往返，29 项全通过） |
| v1.8.0 | **构建链升级**（AGP 8.11.1 / Kotlin 2.2.20 / compileSdk 36，告警清零）+ **角色预设 + 会话搜索 + 数据导出/导入**，测试增至 35 项 |
| v1.8.1 | 设置页精简（移除状态徽标与模型行、角色预设改弹窗入口）；修复批量管理「全选/取消全选」逻辑；数据备份优化（导出自选保存位置 + 单条导出、导入修复并明确提示），测试增至 39 项 |
| v1.8.2 | **保守美化**（布局不动：卡片描边式统一圆角、输入框浅底圆角、列表按压态、Chip 规范、面板 24dp 圆角、SnackBar 浮动）；**修复含代码块回复渲染崩溃**（flutter_markdown visitText 缺陷）；修复聊天输入框双边框重叠；修复导入对话拉不起文件管理器（选择器先弹、面板后关 + file_picker 混淆保护 + 导入格式分级校验）；`flutter analyze` 清零，测试增至 42 项 |
| v1.8.3 | **对话输入框完全重绘**（单容器 + 内嵌圆角发送按钮、圆角 24→18dp、选项胶囊化支持窄屏换行）；**修复「导出全部/导入对话」点击无反应**（失效 context 上 read provider 抛异常）；新增输入框渲染回归测试，`flutter analyze` 0 问题，测试增至 45 项 |
| v1.8.4 | **模型栏三按钮强制同一排**（模型名过长省略、不再换行）；**快捷提示词扩充至 20 条并按会话随机展示 3 条**（同会话内稳定）；新增提示词抽取测试，测试增至 50 项 |

---


## 🤝 贡献

欢迎 Issue 与 PR！提交前请确保：

```bash
flutter analyze              # 0 error
flutter build apk --release  # 构建通过
```

## 📄 许可证

本项目基于 [MIT License](LICENSE) 开源。

## ⚠️ 免责声明

- 本项目仅提供客户端能力，**不内置、不提供、不代售任何 AI 服务或 API Key**，请使用你自己合法获得的 API 服务
- 使用本项目产生的对话内容、费用、数据安全由使用者自行负责
- 本项目与 DeepSeek、OpenAI、Agnes 等任何服务提供商无 affiliation
