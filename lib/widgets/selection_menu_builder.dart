import 'package:flutter/material.dart';

import 'copy_selection_sheet.dart';

/// v1.7.0 · B1 选择体验精修
///
/// 在系统长按选择菜单（全选/复制/粘贴）基础上，追加一项「在大面板中选择」：
/// 点它弹出全屏静止面板，用放大手柄 + 大字距精确拖选，解决气泡内
/// "文字选不准、手柄难拖"的痛点。原生复制/全选行为完整保留。
class SelectionMenuBuilder {
  /// 给 SelectableRegion（SelectionArea）用的菜单构建器。
  static Widget build(
    BuildContext context,
    SelectableRegionState state, {
    required String fullText,
    required bool isDark,
  }) {
    final items = List<ContextMenuButtonItem>.from(
      state.contextMenuButtonItems,
    );
    items.add(
      ContextMenuButtonItem(
        type: ContextMenuButtonType.custom,
        label: '在大面板中选择',
        onPressed: () {
          // 先关闭选择菜单，再弹面板
          state.hideToolbar();
          CopySelectionSheet.show(context, text: fullText, isDark: isDark);
        },
      ),
    );
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: state.contextMenuAnchors,
      buttonItems: items,
    );
  }

  /// 给单个 SelectableText（用户气泡）用的菜单构建器。
  /// EditableTextState 与 SelectableRegionState 接口不同，这里单独适配。
  static Widget buildEditable(
    BuildContext context,
    EditableTextState state, {
    required String fullText,
    required bool isDark,
  }) {
    final items = List<ContextMenuButtonItem>.from(
      state.contextMenuButtonItems,
    );
    items.add(
      ContextMenuButtonItem(
        type: ContextMenuButtonType.custom,
        label: '在大面板中选择',
        onPressed: () {
          state.hideToolbar();
          CopySelectionSheet.show(context, text: fullText, isDark: isDark);
        },
      ),
    );
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: state.contextMenuAnchors,
      buttonItems: items,
    );
  }
}
