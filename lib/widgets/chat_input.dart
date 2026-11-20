import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 组件层：底部输入区（v1.8.3 完全重绘）
/// 一个干净的单容器结构：输入框 + 内嵌发送按钮（天然对齐）+ 选项行。
/// 对外接口与历史版本完全一致，功能（模型/思考/搜索/发送/停止/配置引导）不变。
class ChatInput extends StatefulWidget {
  final TextEditingController controller;
  final bool isGenerating;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final bool isDark;

  final String model;
  final bool thinking;
  final VoidCallback onModelTap;
  final ValueChanged<bool> onThinkingChanged;

  /// 是否已配置 API：未配置时模型按钮显示引导文案
  final bool configured;

  /// 搜索配置是否已检查通过（通过后才显示搜索按钮）
  final bool searchAvailable;

  /// 当前会话搜索开关
  final bool searching;
  final ValueChanged<bool> onSearchingChanged;

  const ChatInput({
    super.key,
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
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
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
    final bg = isDark ? AppTheme.darkCard(AppTheme.oledDark) : Colors.white;
    final fieldBg = isDark
        ? AppTheme.darkFieldBg(AppTheme.oledDark)
        : const Color(0xFFF4F5F9);
    final lineColor = isDark
        ? const Color(0xFF333333)
        : const Color(0xFFEEEEEE);
    final borderColor = focused
        ? AppTheme.primary.withValues(alpha: 0.55)
        : (isDark
              ? AppTheme.darkBorder(AppTheme.oledDark)
              : const Color(0xFFE7EAF2));
    final iconColor = isDark
        ? const Color(0xFFA8AEC0)
        : const Color(0xFF5A6072);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: lineColor, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 输入容器：圆角 18（较原先减弱），发送按钮内嵌其中、底部对齐
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
              decoration: BoxDecoration(
                color: fieldBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: borderColor,
                  width: focused ? 1.4 : 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
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
                        // 自定义容器已画边框，彻底关闭 TextField 各状态边框
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        hintText: '给 AI 发消息…',
                        hintStyle: TextStyle(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.38)
                              : Colors.grey.shade500,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 1),
                    child: widget.isGenerating ? _stopButton() : _sendButton(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // 选项行：模型 / 思考 / 搜索 —— 始终强制同一排，不换行
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 模型按钮占据剩余空间并可收缩，模型名过长时省略号截断
                Flexible(fit: FlexFit.loose, child: _modelButton(iconColor)),
                const SizedBox(width: 8),
                _thinkingButton(iconColor),
                if (widget.searchAvailable) ...[
                  const SizedBox(width: 8),
                  _searchButton(iconColor),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 统一的选项胶囊底样式
  BoxDecoration _chipDecoration({
    required bool active,
    required Color activeColor,
  }) {
    return BoxDecoration(
      color: active
          ? activeColor.withValues(alpha: 0.12)
          : (isDark
                ? AppTheme.darkFieldBg(AppTheme.oledDark)
                : const Color(0xFFF1F3F8)),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: active
            ? activeColor
            : (isDark
                  ? AppTheme.darkBorder(AppTheme.oledDark)
                  : const Color(0xFFE7EAF2)),
        width: active ? 1.4 : 1,
      ),
    );
  }

  /// 模型选择按钮
  Widget _modelButton(Color iconColor) {
    return GestureDetector(
      onTap: widget.onModelTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: _chipDecoration(
          active: false,
          activeColor: AppTheme.primary,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.tune, size: 14, color: AppTheme.primary),
            const SizedBox(width: 5),
            Flexible(
              fit: FlexFit.loose,
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
            Icon(Icons.arrow_drop_down, size: 16, color: iconColor),
          ],
        ),
      ),
    );
  }

  /// 思考开关：开=高亮，关=普通描边
  Widget _thinkingButton(Color iconColor) {
    final active = widget.thinking;
    return GestureDetector(
      onTap: () => widget.onThinkingChanged(!active),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: _chipDecoration(
          active: active,
          activeColor: AppTheme.primary,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.psychology_outlined,
              size: 14,
              color: active ? AppTheme.primary : iconColor,
            ),
            const SizedBox(width: 5),
            Text(
              active ? '思考：开' : '思考：关',
              style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                color: active ? AppTheme.primary : iconColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 搜索开关：样式对齐思考开关
  Widget _searchButton(Color iconColor) {
    final active = widget.searching;
    const activeColor = Colors.teal;
    return GestureDetector(
      onTap: () => widget.onSearchingChanged(!active),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: _chipDecoration(active: active, activeColor: activeColor),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.travel_explore,
              size: 14,
              color: active ? activeColor : iconColor,
            ),
            const SizedBox(width: 5),
            Text(
              active ? '搜索：开' : '搜索：关',
              style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                color: active ? activeColor : iconColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 圆角方块发送按钮：内嵌在输入框右侧，与输入框风格一致
  Widget _sendButton() {
    return SizedBox(
      width: 40,
      height: 40,
      child: Material(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(13),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onSend,
          child: const Icon(
            Icons.arrow_upward_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }

  /// 圆角方块停止按钮
  Widget _stopButton() {
    return SizedBox(
      width: 40,
      height: 40,
      child: Material(
        color: isDark ? Colors.white : const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(13),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onStop,
          child: Icon(
            Icons.stop_rounded,
            color: isDark ? Colors.black : Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}
