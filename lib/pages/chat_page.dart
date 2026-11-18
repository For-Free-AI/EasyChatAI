import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../providers/chat_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/chat_input.dart';
import '../widgets/message_bubble.dart';
import 'conversation_drawer.dart';
import 'settings_page.dart';

/// 页面：聊天主页
/// 顶部标题栏（命名后可点击改名）+ 消息列表 + 底部输入区
class ChatPage extends StatefulWidget {
  const ChatPage({Key? key}) : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  // 用于手势呼出侧边栏
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  double? _dragStartX;
  // 未配置引导弹窗：本次进入仅提示一次
  bool _configHintShown = false;

  // ===== V1.4.5：粘底滚动控制 =====
  /// 用户是否处于"跟随底部"状态。上滑离开底部会置 false，程序自动滚动不再打断；
  /// 用户主动滑回底部或点击「回到底部」按钮后恢复 true。
  bool _stickToBottom = true;
  /// 距底部多少像素内算"在底部"（容忍轻微上滑）
  static const double _bottomThreshold = 80;
  /// 上一次的会话 id，用于检测切换会话时恢复粘底
  String? _lastConvId;

  @override
  void initState() {
    super.initState();
    // 首帧渲染后判断：未配置 API 则弹出圆角引导弹窗
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ChatProvider>();
      if (!provider.isConfigured && !_configHintShown) {
        _configHintShown = true;
        _showConfigHintDialog(context);
      }
    });
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// 未配置 API 时的圆角引导弹窗
  void _showConfigHintDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        contentPadding:
            const EdgeInsets.fromLTRB(24, 26, 24, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.link_off, color: AppTheme.primary, size: 28),
            ),
            const SizedBox(height: 18),
            const Text(
              '还没有配置模型，只需要一个 API 即可开始',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            const Text(
              '请在设置中填入你的 API 地址与密钥',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        actions: [
          // 自定义按钮布局：稍后靠左(30%)，转到设置约占 70% 宽度
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('稍后'),
                  ),
                ),
              ),
              Expanded(
                flex: 7,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SettingsPage(),
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('转到设置→'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _send() {
    final text = _inputCtrl.text;
    if (text.trim().isEmpty) return;
    _inputCtrl.clear();
    // 用户主动发消息 → 恢复跟随并回到底部（这是明确的"我要看最新"意图）
    _stickToBottom = true;
    context.read<ChatProvider>().sendMessage(text);
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  /// 平滑滚到底部（仅在明确意图时调用：发送消息 / 切换会话 / 点回到底部按钮）。
  /// 生成过程中绝不调用——视口保持不动，滚动由用户驱动（V1.4.7）。
  void _scrollToBottom() {
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    // 已经贴底就不重复动画
    if (pos.extentAfter <= 4) return;
    _scrollCtrl.animateTo(
      pos.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  /// 用户手动滚动时更新粘底状态：
  /// - 手指拖动（dragDetails != null）或惯性滚动（UserScrollNotification）才算"用户主动"；
  /// - 程序 animateTo 触发的滚动不算，避免自己把自己判断成"离开底部"。
  bool _onScrollNotification(ScrollNotification notification) {
    final isUserDrag =
        notification is ScrollUpdateNotification &&
        notification.dragDetails != null;
    final isUserFling = notification is UserScrollNotification;
    if (isUserDrag || isUserFling) {
      _updateStickByPosition();
    }
    return false;
  }

  void _updateStickByPosition() {
    if (!_scrollCtrl.hasClients) return;
    final atBottom = _scrollCtrl.position.extentAfter <= _bottomThreshold;
    if (_stickToBottom != atBottom && mounted) {
      setState(() => _stickToBottom = atBottom);
    }
  }

  /// 点击「回到底部」：恢复跟随并滚动
  void _backToBottom() {
    setState(() => _stickToBottom = true);
    _scrollToBottom();
  }

  /// 「回到底部」悬浮按钮：上滑查看历史时出现在右下角
  Widget _backToBottomButton(bool isDark) {
    return Material(
      color: isDark ? const Color(0xFF2E2E2E) : Colors.white,
      shape: CircleBorder(
        side: BorderSide(
          color: isDark ? Colors.white24 : Colors.grey.shade300,
          width: 1,
        ),
      ),
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _backToBottom,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 22,
            color: AppTheme.primary,
          ),
        ),
      ),
    );
  }

  /// 弹出底部模型选择列表
  void _showModelSheet(BuildContext context, ChatProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final models = provider.availableModels;
    final currentModel = provider.currentModel;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF252525) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                children: [
                  const Text('选择模型',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  if (provider.loadingModels)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 18),
                      tooltip: '刷新模型列表',
                      onPressed: () => provider.loadModels(silent: false),
                    ),
                ],
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: models.length,
                itemBuilder: (_, index) {
                  final m = models[index];
                  final selected = m == currentModel;
                  return ListTile(
                    leading: Icon(
                      selected ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: selected ? AppTheme.primary : Colors.grey,
                      size: 20,
                    ),
                    title: Text(
                      m,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            selected ? FontWeight.bold : FontWeight.normal,
                        color: selected
                            ? AppTheme.primary
                            : (isDark ? Colors.white70 : const Color(0xFF333333)),
                      ),
                    ),
                    onTap: () {
                      provider.setConversationModel(m);
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// 点击顶部标题改名（仅在 canRename 时可用）
  void _showRenameDialog(BuildContext context, ChatProvider provider) {
    final conv = provider.current;
    if (conv == null || !conv.canRename) return;
    final controller = TextEditingController(text: conv.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名对话'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 30,
          decoration: const InputDecoration(
            hintText: '输入新标题',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              provider.renameConversation(conv.id, controller.text);
              Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Consumer<ChatProvider>(
      builder: (context, provider, _) {
        final conv = provider.current;
        final messages = conv?.messages ?? [];

        // V1.4.7：仅在切换会话时滚到底看最新消息（一次性）。
        // 生成内容时视口完全静止——滚动完全由用户驱动，绝不自动粘底。
        final convId = conv?.id;
        if (convId != _lastConvId) {
          _lastConvId = convId;
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _scrollToBottom());
        }

        return Scaffold(
          key: _scaffoldKey,
          appBar: AppBar(
            // V1.1：命名后可点击标题改名
            title: GestureDetector(
              onTap: () => _showRenameDialog(context, provider),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      conv?.title ?? AppConfig.appName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (conv != null && conv.canRename) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.edit, size: 14, color: Colors.grey),
                  ],
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.add_comment_outlined),
                tooltip: '新建对话',
                onPressed: () => provider.newConversation(),
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'API 设置',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SettingsPage(),
                    ),
                  );
                },
              ),
            ],
          ),
          drawer: ConversationDrawer(isDark: isDark),
          // V1.3.1：从左边缘向右滑动呼出侧边栏（水平手势不与列表垂直滚动冲突）
          body: GestureDetector(
            onHorizontalDragStart: (d) => _dragStartX = d.globalPosition.dx,
            onHorizontalDragEnd: (d) {
              final start = _dragStartX;
              _dragStartX = null;
              if (start == null) return;
              final velocity = d.primaryVelocity ?? 0;
              final screenWidth = MediaQuery.of(context).size.width;
              // 起点在左侧 35% 且向右滑动 → 打开抽屉
              if (start < screenWidth * 0.35 && velocity > 200) {
                _scaffoldKey.currentState?.openDrawer();
              }
            },
            child: Column(
            children: [
              if (provider.error != null)
                Container(
                  width: double.infinity,
                  color: Colors.red.shade50,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          provider.error!,
                          style: TextStyle(
                              fontSize: 12, color: Colors.red.shade700),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: provider.clearError,
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: Stack(
                  children: [
                    NotificationListener<ScrollNotification>(
                      onNotification: _onScrollNotification,
                      child: messages.isEmpty
                          ? _emptyState(provider)
                          // v1.5.1：不使用跨气泡 SelectionArea（用户不需要跨气泡
                          // 选择），每条气泡内部独立选择（selectable 渲染即可
                          // 支持气泡内跨段落连续拖选）
                          : ListView.builder(
                              controller: _scrollCtrl,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              itemCount: messages.length,
                              itemBuilder: (context, index) {
                                return MessageBubble(
                                  message: messages[index],
                                  isDark: isDark,
                                  // 最后一条且正在生成时隐藏操作条，避免流式过程中闪烁
                                  isGenerating: provider.isGenerating &&
                                      index == messages.length - 1 &&
                                      messages[index].role == 'assistant',
                                );
                              },
                            ),
                    ),
                    // V1.4.5：用户上滑离开底部时显示「回到底部」悬浮按钮
                    // v1.5：出现/消失带缩放+淡入淡出动效
                    if (messages.isNotEmpty)
                      Positioned(
                        right: 16,
                        bottom: 14,
                        child: AnimatedScale(
                          scale: _stickToBottom ? 0 : 1,
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutBack,
                          child: AnimatedOpacity(
                            opacity: _stickToBottom ? 0 : 1,
                            duration: const Duration(milliseconds: 180),
                            child: IgnorePointer(
                              ignoring: _stickToBottom,
                              child: _backToBottomButton(isDark),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              ChatInput(
                controller: _inputCtrl,
                isGenerating: provider.isGenerating,
                onSend: _send,
                onStop: provider.stopGenerating,
                isDark: isDark,
                model: provider.currentModel,
                thinking: provider.currentThinking,
                configured: provider.isConfigured,
                onModelTap: () => _showModelSheet(context, provider),
                onThinkingChanged: (v) => provider.setThinking(v),
                // V1.3 搜索开关
                searchAvailable: provider.searchAvailable,
                searching: provider.currentSearching,
                onSearchingChanged: (v) => provider.setSearching(v),
              ),
            ],
            ),
          ),
        );
      },
    );
  }

  /// 首页空状态：Logo + 欢迎语 + 快捷提问（v1.5：分层渐入上浮动效）
  Widget _emptyState(ChatProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 50),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _entrance(delay: 0, child: _logo()),
              const SizedBox(height: 22),
              _entrance(
                delay: 120,
                child: Text(
                  '一鲸落，万物生',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _entrance(
                delay: 200,
                child: Text(
                  provider.isConfigured
                      ? '当前模型：${provider.currentModel}'
                      : '还没有配置模型',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ),
              const SizedBox(height: 32),
              _entrance(delay: 300, child: _promptCard('✨', '帮我写一段产品介绍', provider)),
              const SizedBox(height: 10),
              _entrance(delay: 380, child: _promptCard('💻', '解释这段代码的作用', provider)),
              const SizedBox(height: 10),
              _entrance(delay: 460, child: _promptCard('🌍', '用中文介绍一个有趣的知识', provider)),
            ],
          ),
        ),
      ),
    );
  }

  /// 应用图标：上传的 logo，边长翻倍(176) + 轻微圆角 + 描边
  Widget _logo() {
    return Container(
      width: 176,
      height: 176,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(40),
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: 0.5),
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.12),
            blurRadius: 24,
            spreadRadius: 3,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(37),
        child: Image.asset(
          'assets/app_icon.png',
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  /// 入场动效：延迟 delay 毫秒后，从下方 18px、透明渐入
  Widget _entrance({required int delay, required Widget child}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 420 + delay),
      curve: Interval(
        delay / (420.0 + delay),
        1,
        curve: Curves.easeOutCubic,
      ),
      builder: (context, t, _) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 18),
            child: child,
          ),
        );
      },
    );
  }

  Widget _promptCard(String emoji, String text, ChatProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: double.infinity,
      child: InkWell(
        onTap: () {
          _inputCtrl.text = text;
          _send();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF6F7FB),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 12),
              Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : const Color(0xFF333333),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
