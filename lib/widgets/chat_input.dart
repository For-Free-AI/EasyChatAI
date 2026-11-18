import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 组件层：底部输入区
/// V1.1 新增：输入框下方的「模型选择」与「思考开关」一行
/// v1.5 UI：输入框聚焦发光边框、圆角加大、发送/停止按钮按压缩放动效
class ChatInput extends StatefulWidget {
  final TextEditingController controller;
  final bool isGenerating;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final bool isDark;

  // 当前会话模型 / 思考开关
  final String model;
  final bool thinking;
  final VoidCallback onModelTap;
  final ValueChanged<bool> onThinkingChanged;
  /// 是否已配置 API：未配置时模型按钮显示引导文案
  final bool configured;

  // V1.3 联网搜索开关
  /// 搜索配置是否已检查通过（通过后才显示搜索按钮）
  final bool searchAvailable;
  /// 当前会话搜索开关
  final bool searching;
  final ValueChanged<bool> onSearchingChanged;

  const ChatInput({
    Key? key,
    required this.controller,
    required this.isGenerating,
    required this.onSend,
    required this.onStop,
    required this.isDark,
    required this.model,
    required this.thinking,
    required this.onModelTap,
    required this.onThinkingChanged,
    this.configured = true,
    this.searchAvailable = false,
    this.searching = false,
    required this.onSearchingChanged,
  }) : super(key: key);

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  /// 输入框焦点：聚焦时容器显示柔和发光边框
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  bool get isDark => widget.isDark;

  @override
  Widget build(BuildContext context) {
    final focused = _focus.hasFocus;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.darkCard(AppTheme.oledDark)
            : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF333333) : const Color(0xFFEEEEEE),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 第一行：输入框 + 发送/停止
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF2A2A2A)
                          : const Color(0xFFF4F5F9),
                      borderRadius: BorderRadius.circular(24),
                      // 聚焦发光：柔和蓝色光晕
                      border: Border.all(
                        color: focused
                            ? AppTheme.primary.withValues(alpha: 0.55)
                            : Colors.transparent,
                        width: 1.2,
                      ),
                      boxShadow: focused
                          ? [
                              BoxShadow(
                                color: AppTheme.primary.withValues(alpha: 0.18),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: TextField(
                      controller: widget.controller,
                      focusNode: _focus,
                      maxLines: 5,
                      minLines: 1,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: '给 AI 发消息…',
                        hintStyle: TextStyle(
                          color: isDark ? Colors.grey : Colors.grey.shade500,
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                widget.isGenerating ? _stopButton() : _sendButton(),
              ],
            ),
            const SizedBox(height: 8),
            // 第二行：模型选择 + 思考开关 + 搜索开关（参考 WorkBuddy 布局）
            Row(
              children: [
                _modelButton(),
                const SizedBox(width: 10),
                _thinkingButton(),
                // V1.3：搜索配置检查通过后才显示
                if (widget.searchAvailable) ...[
                  const SizedBox(width: 10),
                  _searchButton(),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 模型选择按钮
  Widget _modelButton() {
    return GestureDetector(
      onTap: widget.onModelTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF1F3F8),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tune, size: 14, color: AppTheme.primary),
            const SizedBox(width: 5),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: Text(
                widget.configured ? widget.model : '还没有配置模型',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : const Color(0xFF444444),
                ),
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.arrow_drop_down,
              size: 16,
              color: isDark ? Colors.white70 : const Color(0xFF666666),
            ),
          ],
        ),
      ),
    );
  }

  /// 思考开关：开=高亮底色+加粗边框；关=普通描边
  Widget _thinkingButton() {
    return GestureDetector(
      onTap: () => widget.onThinkingChanged(!widget.thinking),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: widget.thinking
              ? AppTheme.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: widget.thinking ? AppTheme.primary : Colors.grey.shade400,
            width: widget.thinking ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.psychology_outlined,
              size: 14,
              color: widget.thinking
                  ? AppTheme.primary
                  : (isDark ? Colors.white60 : Colors.grey.shade600),
            ),
            const SizedBox(width: 5),
            Text(
              widget.thinking ? '思考：开' : '思考：关',
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                    widget.thinking ? FontWeight.bold : FontWeight.normal,
                color: widget.thinking
                    ? AppTheme.primary
                    : (isDark ? Colors.white60 : Colors.grey.shade600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// V1.3 搜索开关：开=高亮底色+加粗边框；关=普通描边（样式对齐思考开关）
  Widget _searchButton() {
    return GestureDetector(
      onTap: () => widget.onSearchingChanged(!widget.searching),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: widget.searching
              ? Colors.teal.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: widget.searching ? Colors.teal : Colors.grey.shade400,
            width: widget.searching ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.travel_explore,
              size: 14,
              color: widget.searching
                  ? Colors.teal
                  : (isDark ? Colors.white60 : Colors.grey.shade600),
            ),
            const SizedBox(width: 5),
            Text(
              widget.searching ? '搜索：开' : '搜索：关',
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                    widget.searching ? FontWeight.bold : FontWeight.normal,
                color: widget.searching
                    ? Colors.teal
                    : (isDark ? Colors.white60 : Colors.grey.shade600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 圆形发送/停止按钮：按压缩放动效（活泼明显）
  Widget _circleButton({
    required VoidCallback onTap,
    required Widget child,
    required Color color,
  }) {
    return _PressableScale(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Center(child: child),
      ),
    );
  }

  Widget _sendButton() {
    return _circleButton(
      onTap: widget.onSend,
      color: AppTheme.primary,
      child: const Icon(Icons.arrow_upward, color: Colors.white, size: 22),
    );
  }

  Widget _stopButton() {
    return _circleButton(
      onTap: widget.onStop,
      color: isDark ? Colors.white : const Color(0xFF1A1A1A),
      child: Icon(
        Icons.stop,
        color: isDark ? Colors.black : Colors.white,
        size: 20,
      ),
    );
  }
}

/// 按压缩放组件：按下缩到 0.85，松开弹回（带弹性曲线）
class _PressableScale extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;

  const _PressableScale({required this.onTap, required this.child});

  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.85 : 1.0,
        duration: const Duration(milliseconds: 130),
        curve: _pressed ? Curves.easeOut : Curves.elasticOut,
        child: widget.child,
      ),
    );
  }
}
