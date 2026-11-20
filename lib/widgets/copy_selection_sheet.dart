import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'selection_controls.dart';

/// V1.4.7：选择复制面板
///
/// 背景：消息列表里每条消息是独立的 SelectableText，导致
/// 「不能跨段选择、点击列表空白不取消选择」，且列表滚动与选择手势互相干扰。
/// 本面板把单条消息放进一个静止的大页面：整条消息是一个连续可选文本，
/// 支持跨段落连续拖选，点面板外部关闭即视为"取消选择"。
///
/// 入口：AI 消息操作条「选择复制」按钮 / 用户消息双击气泡。
class CopySelectionSheet {
  /// 弹出选择复制面板
  static void show(
    BuildContext context, {
    required String text,
    required bool isDark,
    String title = '选择复制',
  }) {
    if (text.trim().isEmpty) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF252525) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => _CopySheetBody(text: text, isDark: isDark, title: title),
    );
  }
}

class _CopySheetBody extends StatelessWidget {
  final String text;
  final bool isDark;
  final String title;

  const _CopySheetBody({
    required this.text,
    required this.isDark,
    required this.title,
  });

  void _copyAll(BuildContext context) {
    Clipboard.setData(ClipboardData(text: text));
    // 用 root messenger：面板已 pop 后也能正常提示
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制全文'), duration: Duration(seconds: 1)),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 拖动条
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // 标题行 + 复制全文
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 10, 4),
              child: Row(
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _copyAll(context),
                    icon: Icon(
                      Icons.copy_all_outlined,
                      size: 15,
                      color: AppTheme.primary,
                    ),
                    label: const Text(
                      '复制全文',
                      style: TextStyle(fontSize: 13, color: AppTheme.primary),
                    ),
                  ),
                ],
              ),
            ),
            // 操作提示
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
              child: Text(
                '长按文字开始选择 · 拖动手柄扩展选区 · 可跨段落连续选择',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white38 : Colors.grey.shade500,
                ),
              ),
            ),
            Divider(
              height: 1,
              color: isDark ? Colors.white12 : Colors.grey.shade200,
            ),
            // 全文内容：单个连续可选文本（跨段选择的关键）
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
                child: SelectableText(
                  text,
                  // v1.7.0 B1：面板是精确选择主战场，手柄热区放大到 34dp
                  selectionControls: BigHandleTextSelectionControls(),
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.65,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
