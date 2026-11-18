import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/atom-one-light.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:highlight/languages/all.dart' show allLanguages;
import 'package:markdown/markdown.dart' as md;

import '../models/message.dart';
import '../theme/app_theme.dart';
import 'copy_selection_sheet.dart';

/// 组件层：单条消息气泡
/// 用户消息靠右灰色气泡；AI 消息靠左，支持 Markdown/代码高亮渲染
/// V1.3：AI 回复末尾追加「已联网搜索」标记 + token 用量条 + 复制全部
/// V1.4：AI 回复上方追加思维链区块（形态一可展开/收起 / 形态二仅状态提示）
class MessageBubble extends StatefulWidget {
  final ChatMessage message;
  final bool isDark;
  /// 是否正在生成（生成中隐藏操作条，完成后显示；并驱动思考区展开/收起）
  final bool isGenerating;

  const MessageBubble({
    Key? key,
    required this.message,
    required this.isDark,
    this.isGenerating = false,
  }) : super(key: key);

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble>
    with AutomaticKeepAliveClientMixin {
  /// V1.4.4：保活已渲染的消息，避免 ListView 滚动时 WebView 被反复销毁重建
  /// （重建会重新加载 HTML、高度跳变、丢失滚动位置）
  @override
  bool get wantKeepAlive => true;

  /// 思维链展开状态。null = 尚未手动操作，跟随 isGenerating（生成时展开）
  bool? _expandedOverride;

  /// 记录上一次的生成状态，用于「完成瞬间自动收起」仅触发一次
  late bool _prevGenerating;

  @override
  void initState() {
    super.initState();
    _prevGenerating = widget.isGenerating;
  }

  @override
  void didUpdateWidget(covariant MessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 2.C：生成中展开、完成后收起。生成结束那一刻把展开态重置为收起，
    // 之后用户仍可手动再次展开。
    if (_prevGenerating && !widget.isGenerating) {
      _expandedOverride = false;
    }
    _prevGenerating = widget.isGenerating;
  }

  bool get _isUser => widget.message.role == 'user';

  /// 是否展示思维链区块：仅助手消息且本轮开了思考
  bool get _showReasoning =>
      !_isUser && widget.message.thinkingEnabled;

  /// 形态一：收到了可读思考文本 → 可展开/收起
  bool get _hasReadableReasoning =>
      widget.message.reasoning.trim().isNotEmpty;

  bool get _expanded =>
      _expandedOverride ?? widget.isGenerating; // 生成时默认展开

  void _copyAll(BuildContext context) {
    Clipboard.setData(ClipboardData(text: widget.message.content));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已复制全部内容'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  /// V1.4.7：打开选择复制面板（跨段连续选择）
  void _openCopySheet(BuildContext context) {
    CopySelectionSheet.show(
      context,
      text: widget.message.content,
      isDark: widget.isDark,
    );
  }

  /// Markdown 渲染（v1.5.1：selectable:true——单条气泡内独立选择，
  /// 支持气泡内跨段落连续拖选；代码块由自定义 builder 接管，带语法高亮与「复制」按钮）
  Widget _markdownBody() {
    return MarkdownBody(
      data: widget.message.content,
      selectable: true,
      builders: {'pre': _CodeBlockBuilder(isDark: widget.isDark)},
      styleSheet: MarkdownStyleSheet(
        p: TextStyle(
          fontSize: 15,
          height: 1.6,
          color: widget.isDark ? Colors.white : const Color(0xFF1A1A1A),
        ),
        code: TextStyle(
          fontSize: 13,
          backgroundColor: widget.isDark
              ? const Color(0xFF2A2A2A)
              : const Color(0xFFF2F2F2),
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin 要求
    if (_isUser) {
      // v1.5.1：用户气泡——SelectableText 独立选择（气泡内跨段选择），
      // 双击仍打开选择复制面板
      return Align(
        alignment: Alignment.centerRight,
        child: GestureDetector(
          onDoubleTap: () => _openCopySheet(context),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.82,
            ),
            decoration: BoxDecoration(
              color: widget.isDark
                  ? const Color(0xFF2E2E2E)
                  : const Color(0xFFF1F3F8),
              borderRadius: BorderRadius.circular(16),
            ),
            child: SelectableText(
              widget.message.content,
              style: TextStyle(
                fontSize: 15,
                color: widget.isDark ? Colors.white : const Color(0xFF1A1A1A),
                height: 1.5,
              ),
            ),
          ),
        ),
      );
    }

    // AI 回复：左侧头像 +（V1.4 思维链）+ Markdown 正文（+ V1.3 操作条）
    // v1.5：新气泡加入渐入 + 上浮动效（首次构建时播放一次）
    return Align(
      alignment: Alignment.centerLeft,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        builder: (context, t, child) {
          return Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(0, (1 - t) * 16),
              child: child,
            ),
          );
        },
        child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.primary,
              child: const Text(
                'AI',
                style: TextStyle(
                  color: Colors.white,
                  // V1.4.3：头像文案由「A」改为「AI」，两字符略缩小以适配圆形
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // V1.4：思维链区块（若本轮开了思考）
                  if (_showReasoning) ...[
                    _reasoningBlock(),
                    const SizedBox(height: 6),
                  ],
                  widget.message.content.isEmpty
                      ? _thinkingDots()
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _markdownBody(),
                            // v1.5：生成中在正文末尾显示闪烁光标
                            if (widget.isGenerating) const _BlinkingCursor(),
                          ],
                        ),
                  // V1.3：本轮操作条（生成中或有内容时才显示）
                  if (!widget.isGenerating &&
                      widget.message.content.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _actionBar(context),
                  ],
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  /// V1.4 思维链区块：形态一可展开/收起；形态二仅状态提示不可点
  Widget _reasoningBlock() {
    if (_hasReadableReasoning) {
      // 形态一：有可读思考文本 → 可展开/收起
      return Container(
        decoration: BoxDecoration(
          color: widget.isDark
              ? const Color(0xFF1E1E1E)
              : const Color(0xFFF4F5F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: widget.isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.grey.shade200,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () =>
                  setState(() => _expandedOverride = !_expanded),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.psychology_outlined,
                        size: 15, color: AppTheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      widget.isGenerating ? '正在思考…' : '已深度思考',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: widget.isDark
                            ? Colors.white70
                            : Colors.grey.shade700,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: widget.isDark ? Colors.white54 : Colors.grey,
                    ),
                  ],
                ),
              ),
            ),
            if (_expanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                // v1.5.1：思考文本可独立选择（气泡内跨段选择）
                child: SelectableText(
                  widget.message.reasoning.trim(),
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.55,
                    color: widget.isDark
                        ? Colors.white54
                        : Colors.grey.shade600,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    // 形态二：开了思考但无可读文本 → 仅状态提示，不可展开/收起
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: widget.isDark
            ? const Color(0xFF1E1E1E)
            : const Color(0xFFF4F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: widget.isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.psychology_outlined, size: 15, color: AppTheme.primary),
          const SizedBox(width: 6),
          Text(
            widget.isGenerating ? '正在思考…' : '已完成思考',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: widget.isDark ? Colors.white70 : Colors.grey.shade700,
            ),
          ),
          if (widget.isGenerating) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 末尾操作条：已联网搜索标记 / token 用量 / 复制全部
  Widget _actionBar(BuildContext context) {
    final showUsage = widget.message.totalTokens != null;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color: widget.isDark
            ? const Color(0xFF262626)
            : const Color(0xFFF7F8FC),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.message.searched)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.public, size: 13, color: Colors.teal),
                      SizedBox(width: 3),
                      Text(
                        '已联网搜索',
                        style: TextStyle(fontSize: 11, color: Colors.teal),
                      ),
                    ],
                  ),
                ),
              if (showUsage)
                Text(
                  '输入 ${widget.message.promptTokens} · 输出 ${widget.message.completionTokens} · 共 ${widget.message.totalTokens} tokens',
                  style: TextStyle(
                    fontSize: 11,
                    color: widget.isDark
                        ? Colors.white54
                        : Colors.grey.shade600,
                  ),
                )
              else
                Text(
                  '用量不可用',
                  style: TextStyle(
                    fontSize: 11,
                    color: widget.isDark
                        ? Colors.white38
                        : Colors.grey.shade400,
                  ),
                ),
            ],
          ),
          InkWell(
            onTap: () => _openCopySheet(context),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.select_all,
                      size: 13, color: AppTheme.primary),
                  const SizedBox(width: 3),
                  const Text(
                    '选择复制',
                    style: TextStyle(fontSize: 11, color: AppTheme.primary),
                  ),
                ],
              ),
            ),
          ),
          InkWell(
            onTap: () => _copyAll(context),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.copy_all_outlined,
                      size: 13, color: AppTheme.primary),
                  const SizedBox(width: 3),
                  const Text(
                    '复制全部',
                    style: TextStyle(fontSize: 11, color: AppTheme.primary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 生成中的三个跳动圆点（v1.5：循环缩放跳动动画）
  Widget _thinkingDots() {
    return const Padding(
      padding: EdgeInsets.only(top: 4),
      child: SizedBox(
        width: 44,
        height: 20,
        child: _JumpingDots(),
      ),
    );
  }
}

/// 三个循环跳动的小圆点
class _JumpingDots extends StatefulWidget {
  const _JumpingDots();

  @override
  State<_JumpingDots> createState() => _JumpingDotsState();
}

class _JumpingDotsState extends State<_JumpingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Row(
          children: List.generate(3, (i) {
            // 三个圆点相位错开，形成波浪式跳动
            final t = (_ctrl.value - i * 0.18) % 1.0;
            final scale = 1.0 - 0.35 * _bounce(t);
            return Container(
              margin: const EdgeInsets.only(right: 5),
              width: 7,
              height: 7,
              alignment: Alignment.center,
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  /// 简易弹跳曲线：0→1→0 的平滑峰形
  double _bounce(double t) {
    final x = t.clamp(0.0, 1.0);
    return (1 - (2 * x - 1).abs()) * (1 - (2 * x - 1).abs());
  }
}

/// v1.5：代码块自定义渲染——语法高亮 + 顶部语言标签 + 右上角「复制」按钮。
/// 纯 Flutter 组件，不影响列表滚动；代码本身通过按钮一键复制。
class _CodeBlockBuilder extends MarkdownElementBuilder {
  final bool isDark;
  _CodeBlockBuilder({required this.isDark});

  /// 从 <pre><code class="language-xxx"> 提取语言名
  String? _language(md.Element element) {
    final children = element.children;
    if (children == null || children.isEmpty) return null;
    final first = children.first;
    if (first is md.Element) {
      final cls = first.attributes['class'] ?? '';
      if (cls.startsWith('language-')) {
        final lang = cls.substring(9).trim();
        // 仅当 highlight 库支持该语言才启用高亮，否则按纯文本
        return allLanguages.containsKey(lang) ? lang : null;
      }
    }
    return null;
  }

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final code = element.textContent.trimRight();
    final lang = _language(element);
    final theme = isDark ? atomOneDarkTheme : atomOneLightTheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF282C34) : const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 顶部条：语言标签 + 复制按钮
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade200,
            child: Row(
              children: [
                Text(
                  (lang ?? 'text').toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 0.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                  ),
                ),
                const Spacer(),
                _CopyCodeButton(code: code, isDark: isDark),
              ],
            ),
          ),
          // 代码正文：水平滚动 + 语法高亮
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: HighlightView(
              code,
              language: lang ?? 'plaintext',
              theme: theme,
              padding: EdgeInsets.zero,
              textStyle: const TextStyle(
                fontSize: 13,
                height: 1.5,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 代码块「复制」按钮：点击写剪贴板，短暂显示「已复制」反馈
class _CopyCodeButton extends StatefulWidget {
  final String code;
  final bool isDark;
  const _CopyCodeButton({required this.code, required this.isDark});

  @override
  State<_CopyCodeButton> createState() => _CopyCodeButtonState();
}

class _CopyCodeButtonState extends State<_CopyCodeButton> {
  bool _copied = false;

  void _copy() {
    Clipboard.setData(ClipboardData(text: widget.code));
    setState(() => _copied = true);
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _copy,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: widget.isDark ? const Color(0xFF3A3F4A) : const Color(0xFFEEF1F8),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: widget.isDark ? Colors.white24 : Colors.grey.shade300,
          ),
        ),
        child: Text(
          _copied ? '已复制' : '复制',
          style: const TextStyle(
            fontSize: 11,
            color: AppTheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// v1.5：生成中正文末尾的闪烁光标（DeepSeek 同款「▍」）
class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor();

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.15, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          '▍',
          style: TextStyle(
            fontSize: 16,
            height: 1.0,
            color: AppTheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
