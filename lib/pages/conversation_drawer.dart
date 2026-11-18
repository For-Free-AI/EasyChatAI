import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/chat_provider.dart';
import '../theme/app_theme.dart';
import 'settings_page.dart';

/// 页面：侧边栏抽屉
/// 顶部新建对话、历史对话列表、底部设置入口
/// V1.4.1（参考 DeepSeek）：
///   - 普通模式：点击切换对话，长按弹出「重命名 / 删除」操作菜单
///   - 管理模式：多选勾选、全选/取消、批量删除
class ConversationDrawer extends StatefulWidget {
  final bool isDark;

  const ConversationDrawer({Key? key, required this.isDark}) : super(key: key);

  @override
  State<ConversationDrawer> createState() => _ConversationDrawerState();
}

class _ConversationDrawerState extends State<ConversationDrawer> {
  /// 是否处于批量管理模式
  bool _managing = false;

  /// 批量模式下已选中的对话 id
  final Set<String> _selected = <String>{};

  void _toggleSelect(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  void _enterManage() {
    setState(() {
      _managing = true;
      _selected.clear();
    });
  }

  void _exitManage() {
    setState(() {
      _managing = false;
      _selected.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // 顶部安全区留白，整体下移
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: ListTile(
                      leading: const Icon(Icons.add_comment, size: 28),
                      title: const Text(
                        '新建对话',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      onTap: () {
                        context.read<ChatProvider>().newConversation();
                        Navigator.pop(context);
                      },
                    ),
                  ),
                  // 管理 / 完成 切换按钮
                  TextButton(
                    onPressed: () => _managing ? _exitManage() : _enterManage(),
                    child: Text(
                      _managing ? '完成' : '管理',
                      style: TextStyle(
                        fontSize: 14,
                        color: _managing ? Colors.teal : AppTheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Consumer<ChatProvider>(
                builder: (context, provider, _) {
                  if (provider.conversations.isEmpty) {
                    return const Center(
                      child: Text('暂无历史对话',
                          style: TextStyle(color: Colors.grey)),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: provider.conversations.length,
                    // v1.5：卡片化列表项——圆角卡片、左右留白，选中态高亮
                    itemBuilder: (context, index) {
                      final conv = provider.conversations[index];
                      final selected = provider.current?.id == conv.id;
                      final checked = _selected.contains(conv.id);
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        child: Dismissible(
                          // v1.5：普通模式下左滑直接删除单条对话
                          key: ValueKey('conv-${conv.id}'),
                          direction: _managing
                              ? DismissDirection.none
                              : DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 16),
                            decoration: BoxDecoration(
                              color: Colors.red.shade400,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.delete_outline,
                                color: Colors.white, size: 22),
                          ),
                          onDismissed: (_) =>
                              provider.deleteConversation(conv.id),
                          child: Container(
                            decoration: BoxDecoration(
                              color: selected && !_managing
                                  ? (widget.isDark
                                      ? const Color(0xFF2A2A2A)
                                      : const Color(0xFFEEF1FF))
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              leading: _managing
                                  ? Checkbox(
                                      value: checked,
                                      activeColor: AppTheme.primary,
                                      onChanged: (_) =>
                                          _toggleSelect(conv.id),
                                    )
                                  : Icon(
                                      Icons.chat_bubble_outline,
                                      size: 18,
                                      color: selected ? AppTheme.primary : null,
                                    ),
                              title: Text(
                                conv.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 14),
                              ),
                              onTap: () {
                                if (_managing) {
                                  _toggleSelect(conv.id);
                                } else {
                                  provider.selectConversation(conv.id);
                                  Navigator.pop(context);
                                }
                              },
                              onLongPress: _managing
                                  ? null
                                  : () => _showActions(context, provider,
                                      conv.id, conv.title),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            // 管理模式下底部批量操作栏
            if (_managing) ...[
              const Divider(height: 1),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        final all = context
                            .read<ChatProvider>()
                            .conversations
                            .map((c) => c.id)
                            .toList();
                        setState(() {
                          final alreadyAll = _selected.length == all.length;
                          _selected.clear();
                          if (!alreadyAll) _selected.addAll(all);
                        });
                      },
                      child: Text(
                        _selected.isEmpty ? '全选' : '取消全选',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: _selected.isEmpty
                          ? null
                          : () => _confirmBatchDelete(context),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: Text(
                        _selected.isEmpty
                            ? '删除所选'
                            : '删除所选 (${_selected.length})',
                        style: const TextStyle(fontSize: 14),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red.shade400,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('API 设置'),
              onTap: () {
                Navigator.pop(context);
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
      ),
    );
  }

  /// 长按单条对话：弹出操作菜单（重命名 / 删除）
  void _showActions(
      BuildContext context, ChatProvider provider, String id, String title) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 14, color: Colors.grey),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('重命名'),
              onTap: () {
                Navigator.pop(ctx);
                _showRenameDialog(context, provider, id, title);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('删除', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(context, provider, id);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 重命名对话框
  void _showRenameDialog(BuildContext context, ChatProvider provider,
      String id, String currentTitle) {
    final ctrl = TextEditingController(text: currentTitle);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名对话'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 30,
          decoration: const InputDecoration(
            hintText: '输入新的对话名称',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _doRename(ctx, provider, id, ctrl.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => _doRename(ctx, provider, id, ctrl.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _doRename(
      BuildContext ctx, ChatProvider provider, String id, String newTitle) {
    if (newTitle.trim().isEmpty) return;
    provider.renameConversationAny(id, newTitle);
    Navigator.pop(ctx);
  }

  /// 删除单条确认
  void _confirmDelete(BuildContext context, ChatProvider provider, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除对话'),
        content: const Text('确定删除这条对话吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              provider.deleteConversation(id);
              Navigator.pop(ctx);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// 批量删除确认
  void _confirmBatchDelete(BuildContext context) {
    final count = _selected.length;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('批量删除'),
        content: Text('确定删除选中的 $count 条对话吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              context.read<ChatProvider>().deleteConversations(
                    List<String>.from(_selected),
                  );
              Navigator.pop(ctx);
              _exitManage();
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
