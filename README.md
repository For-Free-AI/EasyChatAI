# EasyChatAI

一款**轻量级 Android AI 对话客户端**。支持任意 **OpenAI Chat Completions 兼容 API** 与 **Anthropic Messages 兼容 API**，无需注册任何账号——填入你自己的 API 地址和 Key 即可开始对话。所有数据仅保存在本机，不上传、不追踪。

> 当前版本：**v1.6.0** · Flutter **3.44.9** / Dart 3.12 · 仅支持 Android

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

### 阅读与交互
- **Markdown 全渲染**：标题、列表、表格、引用、行内代码
- **代码块语法高亮**：180+ 语言着色、顶部语言标签、右上角一键「复制」按钮，长代码横向滚动
- **气泡内自由选择**：长按 AI 回复或用户消息即可选择复制，支持**气泡内跨段落连续拖选**；另有「选择复制」面板（AI 回复点操作条按钮、用户消息双击气泡），静态大页面里跨段落选择更从容
- **消息操作条**：复制全部、Token 用量、已联网搜索标记
- **滚动规则**：生成内容时视口完全静止，滚动完全由用户驱动；上滑查看历史不被打断，「回到底部」按钮弹性缩放出现

### 界面
- **Material 3 主题**：种子色配色系统、胶囊按钮、大圆角卡片
- **深浅色 / OLED 纯黑**：跟随系统 / 浅色 / 深色三档切换，深色下可开启 OLED 省电纯黑
- **活泼动效**：气泡渐入上浮、思考圆点波浪跳动、发送按钮按压缩放回弹、问候语分层入场
- **DeepSeek 式侧边栏**：对话列表管理、批量勾选删除、长按重命名、普通模式左滑直接删除；主界面左滑即可呼出
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
| Android 构建 | Gradle 8.14 / AGP 8.9.3 / Kotlin 2.1.0 / compileSdk 35 |

## 📁 项目结构

```
lib/
├── main.dart                     # 应用入口、中文本地化、主题切换（含 OLED）
├── config/
│   └── app_config.dart           # 预设 API 配置、默认系统提示词、应用名
├── models/
│   ├── message.dart              # 消息（思维链、token 用量、搜索标记）
│   ├── conversation.dart         # 会话（标题/模型/思考/搜索开关）
│   └── search.dart               # 搜索决策与结果结构
├── providers/
│   └── chat_provider.dart        # 状态中枢：会话管理、发送、流式组装、自动命名
├── services/
│   ├── api_service.dart          # 网络层门面：按协议分发到适配器
│   ├── api_protocol.dart         # 协议枚举与适配器统一接口
│   ├── openai_adapter.dart       # OpenAI Chat Completions 兼容适配器
│   ├── anthropic_adapter.dart    # Anthropic Messages 兼容适配器
│   └── storage_service.dart      # 本地持久化（配置 + 会话）
├── theme/
│   └── app_theme.dart            # Material 3 主题（浅色/深色/OLED 纯黑）
├── pages/
│   ├── chat_page.dart            # 主对话页：列表、空状态、滚动规则、引导弹窗
│   ├── settings_page.dart        # 连接提供商、搜索配置、外观
│   └── conversation_drawer.dart  # 侧边栏：管理/批量删除/重命名/左滑删除
└── widgets/
    ├── message_bubble.dart       # 消息气泡：Markdown、思维链、代码块高亮、操作条
    ├── chat_input.dart           # 输入框：聚焦发光边框、模型/思考/搜索切换
    └── copy_selection_sheet.dart # 选择复制面板
```

---

## 🚀 快速开始

### 环境要求

- Flutter **3.44.9+**（参考[官方安装指引](https://docs.flutter.cn/get-started/install)）
- Android SDK：Platform 35、Build-Tools 35（缺失时 `sdkmanager` 自动补齐）
- JDK **17**
- Android 真机或模拟器

### 构建运行

```bash
# 1. 克隆项目
git clone https://github.com/<你的用户名>/EasyChatAI.git
cd EasyChatAI

# 2. 拉取依赖
flutter pub get

# 3. 真机调试运行
flutter run

# 4. 构建 release APK
flutter build apk --release
# 产物：build/app/outputs/flutter-apk/app-release.apk
```

> `android/local.properties` 为本机路径配置（`flutter.sdk`、`sdk.dir`），由 Flutter 自动生成，**不要提交到仓库**。

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
- **代码块高亮**：`MarkdownElementBuilder` 接管 `pre` 标签，`flutter_highlight` 着色 + 复制按钮，纯 Flutter 组件不影响列表滚动
- **协议适配器模式**：`ProtocolAdapter` 统一接口 + OpenAI/Anthropic 两套实现，`api_service.dart` 门面按配置分发；上层 Provider/页面完全不感知协议差异；新增第三种协议只需再写一个适配器

---

## 🗺 版本历史（摘要）

| 版本 | 主要内容 |
|---|---|
| v1.0 | 流式对话、API 配置、本地历史、Markdown |
| v1.1–v1.2 | 模型切换、思考开关、自动命名、品牌与界面打磨 |
| v1.3 | 联网搜索、Token 用量、复制全部 |
| v1.4 | 思维链展示、中文选择菜单、侧边栏管理、滚动优化 |
| v1.5 | Flutter 3.44.9 升级、Material 3、代码块语法高亮、动效、OLED 模式 |
| v1.5.1 | 选择体验收敛为气泡内跨段落选择（移除跨气泡 SelectionArea） |
| v1.6.0 | **双协议支持（OpenAI + Anthropic 兼容）**、设置页重构（分组卡片、模型列表选择、协议切换、状态徽标） |

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

---

## ⭐最后，能否劳烦您给我一个star以示鼓励
