import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/chat_provider.dart';
import '../services/backup_service.dart';
import '../theme/app_theme.dart';
import 'settings_page.dart';

/// 页面：侧边栏抽屉
/// 顶部新建对话、历史对话列表、底部设置入口
/// V1.4.1（参考 DeepSeek）：
///   - 普通模式：点击切换对话，长按弹出「重命名 / 删除」操作菜单
///   - 管理模式：多选勾选、全选/取消、批量删除
class ConversationDrawer extends StatefulWidget {
  final bool isDark;

  const ConversationDrawer({super.key, required this.isDark});

  @override
  State<ConversationDrawer> createState() => _ConversationDrawerState();
}

class _ConversationDrawerState extends State<ConversationDrawer> {
  /// v1.8：会话搜索关键词
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  bool _searchVisible = false;

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
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () {
                        context.read<ChatProvider>().newConversation();
                        Navigator.pop(context);
                      },
                    ),
                  ),
                  // v1.8：搜索切换按钮
                  IconButton(
                    tooltip: '搜索对话',
                    icon: Icon(
                      _searchVisible ? Icons.search_off : Icons.search,
                      size: 20,
                      color: AppTheme.primary,
                    ),
                    onPressed: () {
                      setState(() {
                        _searchVisible = !_searchVisible;
                        if (!_searchVisible) {
                          _searchCtrl.clear();
                          _searchQuery = '';
                        }
                      });
                    },
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
            // v1.8：搜索框（按标题 + 消息内容本地过滤）
            if (_searchVisible)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: '搜索标题或对话内容…',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    isDense: true,
                    filled: true,
                    fillColor: widget.isDark
                        ? const Color(0xFF2A2A2A)
                        : const Color(0xFFF1F3F8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (v) =>
                      setState(() => _searchQuery = v.trim().toLowerCase()),
                ),
              ),
            const Divider(height: 1),
            Expanded(
              child: Consumer<ChatProvider>(
                builder: (context, provider, _) {
                  // v1.8：按关键词过滤——标题或任意消息内容命中即保留
                  final list = _searchQuery.isEmpty
                      ? provider.conversations
                      : provider.conversations.where((c) {
                          if (c.title.toLowerCase().contains(_searchQuery)) {
                            return true;
                          }
                          return c.messages.any(
                            (m) =>
                                m.content.toLowerCase().contains(_searchQuery),
                          );
                        }).toList();
                  if (list.isEmpty) {
                    return Center(
                      child: Text(
                        _searchQuery.isEmpty ? '暂无历史对话' : '没有匹配的对话',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: list.length,
                    // v1.5：卡片化列表项——圆角卡片、左右留白，选中态高亮
                    itemBuilder: (context, index) {
                      final conv = list[index];
                      final selected = provider.current?.id == conv.id;
                      final checked = _selected.contains(conv.id);
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
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
                            child: const Icon(
                              Icons.delete_outline,
                              color: Colors.white,
                              size: 22,
                            ),
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
                                      onChanged: (_) => _toggleSelect(conv.id),
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
                                  : () => _showActions(
                                      context,
                                      provider,
                                      conv.id,
                                      conv.title,
                                    ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        // v1.8.1：文案与动作统一口径——是否已全选全部会话
                        final all = context
                            .read<ChatProvider>()
                            .conversations
                            .map((c) => c.id)
                            .toList();
                        final allSelected =
                            all.isNotEmpty &&
                            all.every((id) => _selected.contains(id));
                        setState(() {
                          if (allSelected) {
                            _selected.clear();
                          } else {
                            _selected.addAll(all);
                          }
                        });
                      },
                      child: Text(
                        (() {
                          final all = context
                              .read<ChatProvider>()
                              .conversations
                              .map((c) => c.id)
                              .toList();
                          final allSelected =
                              all.isNotEmpty &&
                              all.every((id) => _selected.contains(id));
                          return allSelected ? '取消全选' : '全选';
                        })(),
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
            // v1.8：数据备份入口（导出 JSON / 导入合并）
            ListTile(
              leading: const Icon(Icons.backup_outlined),
              title: const Text('数据备份'),
              subtitle: const Text(
                '导出 / 导入对话（本地 JSON）',
                style: TextStyle(fontSize: 11),
              ),
              onTap: () => _showBackupSheet(context),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('API 设置'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsPage()),
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
    BuildContext context,
    ChatProvider provider,
    String id,
    String title,
  ) {
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
                style: const TextStyle(fontSize: 14, color: Colors.grey),
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
            // v1.8.1：导出此对话——用系统文件管理器让用户自选保存位置
            ListTile(
              leading: const Icon(Icons.ios_share, color: AppTheme.primary),
              title: const Text('导出此对话'),
              onTap: () async {
                Navigator.pop(ctx);
                final safeName = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
                final ok = await provider.exportConversations(
                  fileName: 'EasyChatAI_$safeName.json',
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(ok ? '已导出到所选位置' : '已取消或导出失败')),
                );
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
  void _showRenameDialog(
    BuildContext context,
    ChatProvider provider,
    String id,
    String currentTitle,
  ) {
    final ctrl = TextEditingController(text: currentTitle);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名对话'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 30,
          decoration: const InputDecoration(hintText: '输入新的对话名称'),
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
    BuildContext ctx,
    ChatProvider provider,
    String id,
    String newTitle,
  ) {
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

  /// v1.8：数据备份面板（导出 / 导入）
  void _showBackupSheet(BuildContext context) {
    // v1.8.3 修复：必须在 context 仍有效时就把依赖捕获成局部变量。
    // 原实现在 onTap 里对已 pop 的 context 现场 read<ChatProvider>()，
    // 在失效 context 上读取会抛异常，表现为「点击导出全部/导入没反应」。
    final provider = context.read<ChatProvider>();
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context); // 先关抽屉
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
                '数据备份',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: widget.isDark ? Colors.white : const Color(0xFF1A1A1A),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                '对话仅保存在本机。导出为 JSON 文件后可存到网盘或发给他人；'
                '导入时会按会话 id 去重合并，不会覆盖已有对话。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: widget.isDark ? Colors.white54 : Colors.grey.shade600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.ios_share, color: AppTheme.primary),
              title: const Text('导出全部对话'),
              subtitle: const Text(
                '选择保存位置（本地 JSON）',
                style: TextStyle(fontSize: 11),
              ),
              onTap: () async {
                // v1.8.3：用方法开头捕获的 provider（局部变量），不用已失效的
                // context；先拉起文件选择器再关面板，避免 ActivityResult 丢失。
                final ok = await provider.exportConversations();
                if (ctx.mounted) Navigator.pop(ctx);
                messenger.showSnackBar(
                  SnackBar(content: Text(ok ? '已导出到所选位置' : '已取消或导出失败')),
                );
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.file_upload_outlined,
                color: AppTheme.primary,
              ),
              title: const Text('导入对话'),
              subtitle: const Text(
                '从备份 JSON 文件合并导入',
                style: TextStyle(fontSize: 11),
              ),
              onTap: () async {
                // v1.8.3：同上，用捕获的 provider，先拉选择器再关面板。
                final result = await provider.importConversations();
                if (ctx.mounted) Navigator.pop(ctx);
                if (result.status == ImportStatus.cancelled) return;
                if (result.status == ImportStatus.error) {
                  messenger.showSnackBar(
                    SnackBar(content: Text(result.error ?? '导入失败')),
                  );
                  return;
                }
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      result.added == 0
                          ? '没有新增对话（可能已全部存在）'
                          : '已导入 ${result.added} 条对话',
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
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
