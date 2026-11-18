import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../providers/chat_provider.dart';
import '../services/api_protocol.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

/// 页面：设置页（v1.6.0 重构）
/// - 分组卡片布局：连接提供商 / 联网搜索 / 外观
/// - 双协议支持：预设自动决定协议；自定义提供商可切换 OpenAI/Anthropic 兼容
/// - 模型可拉取列表弹窗选择，也支持手填
/// - 主 Key 与搜索 Key 独立可见性开关；顶部配置状态徽标
class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late TextEditingController _baseUrlCtrl;
  late TextEditingController _apiKeyCtrl;
  late TextEditingController _modelCtrl;
  late TextEditingController _promptCtrl;
  bool _obscureKey = true;
  bool _testing = false;
  String? _testResult;

  // ===== v1.6.0 协议 =====
  late String _protocol; // 'openai' | 'anthropic'
  String? _presetName; // 当前选中的预设；null 或 '自定义' 时协议可自由切换

  // ===== V1.3 联网搜索配置 =====
  late TextEditingController _searchKeyCtrl;
  late TextEditingController _searchUrlCtrl;
  late String _searchProvider;
  bool _obscureSearchKey = true;
  bool _searchChecked = false; // 当前输入是否已检查通过

  // ===== v1.6.0 模型列表拉取 =====
  bool _loadingModels = false;

  @override
  void initState() {
    super.initState();
    final p = context.read<ChatProvider>();
    _baseUrlCtrl = TextEditingController(text: p.baseUrl);
    _apiKeyCtrl = TextEditingController(text: p.apiKey);
    _modelCtrl = TextEditingController(text: p.model);
    _promptCtrl = TextEditingController(text: p.systemPrompt);
    _protocol = p.protocol;

    // 反查当前配置属于哪个预设（用于协议锁展示）
    _presetName = _matchPreset(p.baseUrl, _protocol);

    // 搜索配置：默认第一个（现在为"自定义"）
    _searchProvider = p.searchProvider.isNotEmpty
        ? p.searchProvider
        : AppConfig.searchProviders.first;
    _searchKeyCtrl = TextEditingController(text: p.searchApiKey);
    // 自定义默认留空；DeepSeek 用官方固定地址
    _searchUrlCtrl = TextEditingController(
      text: p.searchBaseUrl.isNotEmpty
          ? p.searchBaseUrl
          : (_searchProvider == 'DeepSeek' ? AppConfig.deepseekSearchUrl : ''),
    );
    _searchChecked = p.searchConfigured;
  }

  /// 根据当前 baseUrl+protocol 反查是否命中某个预设
  String? _matchPreset(String baseUrl, String protocol) {
    for (final entry in AppConfig.presets.entries) {
      if (entry.key == '自定义') continue;
      if (entry.value['baseUrl'] == baseUrl &&
          entry.value['protocol'] == protocol) {
        return entry.key;
      }
    }
    return null;
  }

  @override
  void dispose() {
    _baseUrlCtrl.dispose();
    _apiKeyCtrl.dispose();
    _modelCtrl.dispose();
    _promptCtrl.dispose();
    _searchKeyCtrl.dispose();
    _searchUrlCtrl.dispose();
    super.dispose();
  }

  /// 应用某个预置模板（含协议）
  void _applyPreset(String name) {
    final preset = AppConfig.presets[name]!;
    setState(() {
      _presetName = name;
      _baseUrlCtrl.text = preset['baseUrl']!;
      _modelCtrl.text = preset['model']!;
      _protocol = preset['protocol']!;
      _testResult = null;
    });
  }

  /// 切换协议（仅自定义提供商时可用）
  void _switchProtocol(ApiProtocol p) {
    setState(() {
      _protocol = p.storeValue;
      _presetName = _matchPreset(_baseUrlCtrl.text.trim(), _protocol);
      _testResult = null;
    });
  }

  /// 拉取模型列表并弹出选择弹窗
  Future<void> _pickModel() async {
    if (_loadingModels) return;
    final apiKey = _apiKeyCtrl.text.trim();
    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先填写 API Key')),
      );
      return;
    }
    setState(() => _loadingModels = true);
    final service = ApiService();
    List<String> models;
    String? error;
    try {
      models = await service.fetchModels(
        baseUrl: _baseUrlCtrl.text.trim(),
        apiKey: apiKey,
        protocol: _protocol,
      );
    } catch (e) {
      models = [];
      error = e.toString().replaceAll('Exception: ', '');
    }
    service.dispose();
    if (!mounted) return;
    setState(() => _loadingModels = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('拉取失败：$error')),
      );
      return;
    }
    if (models.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未拉取到可用模型')),
      );
      return;
    }
    _showModelSheet(models);
  }

  /// 模型选择底部弹窗：支持搜索过滤，点选后回填
  void _showModelSheet(List<String> models) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        String filter = '';
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final visible = filter.isEmpty
                ? models
                : models
                    .where((m) =>
                        m.toLowerCase().contains(filter.toLowerCase()))
                    .toList();
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom,
                ),
                child: SizedBox(
                  height: MediaQuery.of(ctx).size.height * 0.65,
                  child: Column(
                    children: [
                      const SizedBox(height: 14),
                      const Text('选择模型',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          decoration: const InputDecoration(
                            hintText: '搜索模型…',
                            prefixIcon: Icon(Icons.search, size: 20),
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (v) => setSheetState(() => filter = v),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: visible.isEmpty
                            ? const Center(child: Text('无匹配模型'))
                            : ListView.builder(
                                itemCount: visible.length,
                                itemBuilder: (ctx, i) {
                                  final m = visible[i];
                                  final selected = _modelCtrl.text.trim() == m;
                                  return ListTile(
                                    dense: true,
                                    leading: Icon(
                                      selected
                                          ? Icons.check_circle
                                          : Icons.circle_outlined,
                                      size: 18,
                                      color: selected
                                          ? AppTheme.primary
                                          : Colors.grey,
                                    ),
                                    title: Text(m, style: const TextStyle(fontSize: 14)),
                                    onTap: () {
                                      setState(() => _modelCtrl.text = m);
                                      Navigator.pop(sheetCtx);
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// 切换搜索提供商：改动后需重新检查
  void _switchSearchProvider(String name) {
    setState(() {
      _searchProvider = name;
      _searchChecked = false;
      context.read<ChatProvider>().clearSearchCheckResult();
      // DeepSeek 用官方固定地址；自定义留空由用户填写
      _searchUrlCtrl.text =
          name == 'DeepSeek' ? AppConfig.deepseekSearchUrl : '';
    });
  }

  /// 搜索输入发生变化 → 作废检查状态
  void _onSearchInputChanged() {
    if (_searchChecked) {
      setState(() {
        _searchChecked = false;
        context.read<ChatProvider>().clearSearchCheckResult();
      });
    }
  }

  /// 检查搜索配置：通过则立即持久化，解锁搜索开关
  Future<void> _checkSearch() async {
    if (_searchKeyCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先填写搜索接口 Key')),
      );
      return;
    }
    final p = context.read<ChatProvider>();
    await p.checkSearchConfig(
      provider: _searchProvider,
      apiKey: _searchKeyCtrl.text.trim(),
      baseUrl: _searchUrlCtrl.text.trim(),
    );
    if (!mounted) return;
    final result = p.searchCheckResult ?? '';
    if (result.startsWith('✅')) {
      // 检查通过：保存配置并标记已通过
      await p.saveSearchConfig(
        provider: _searchProvider,
        apiKey: _searchKeyCtrl.text.trim(),
        baseUrl: _searchProvider == 'DeepSeek'
            ? AppConfig.deepseekSearchUrl
            : _searchUrlCtrl.text.trim(),
        configured: true,
      );
      setState(() => _searchChecked = true);
    } else {
      // 检查失败：清除已通过标记
      await p.saveSearchConfig(
        provider: _searchProvider,
        apiKey: _searchKeyCtrl.text.trim(),
        baseUrl: _searchUrlCtrl.text.trim(),
        configured: false,
      );
      setState(() => _searchChecked = false);
    }
  }

  /// 测试主连接：验证配置是否可用
  Future<void> _testConnection() async {
    if (_apiKeyCtrl.text.trim().isEmpty) {
      setState(() => _testResult = '请先填写 API Key');
      return;
    }
    setState(() {
      _testing = true;
      _testResult = null;
    });
    final service = ApiService();
    final err = await service.testConnection(
      baseUrl: _baseUrlCtrl.text.trim(),
      apiKey: _apiKeyCtrl.text.trim(),
      model: _modelCtrl.text.trim(),
      protocol: _protocol,
    );
    service.dispose();
    if (!mounted) return;
    setState(() {
      _testing = false;
      _testResult = err == null ? '✅ 连接成功，配置可用' : '❌ $err';
    });
  }

  /// 保存配置并返回
  void _save() {
    context.read<ChatProvider>().saveConfig(
          baseUrl: _baseUrlCtrl.text.trim(),
          apiKey: _apiKeyCtrl.text.trim(),
          model: _modelCtrl.text.trim(),
          systemPrompt: _promptCtrl.text.trim(),
          protocol: _protocol,
        );
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('设置已保存')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF252525) : Colors.white;
    final provider = context.read<ChatProvider>();
    final configured = provider.isConfigured;
    final protocolEnum = protocolFromStorage(_protocol);

    return Scaffold(
      appBar: AppBar(
        title: const Text('API 设置'),
        actions: [
          TextButton(onPressed: _save, child: const Text('保存')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ===== v1.6.0：配置状态徽标 =====
          _statusBadge(configured, protocolEnum, isDark),
          const SizedBox(height: 16),

          // ===== 连接提供商 =====
          _sectionCard(
            isDark: isDark,
            color: cardColor,
            title: '连接提供商',
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AppConfig.presets.keys.map((name) {
                  final selected = _presetName == name;
                  return ActionChip(
                    label: Text(name),
                    avatar: selected
                        ? const Icon(Icons.check, size: 16)
                        : null,
                    backgroundColor: selected
                        ? AppTheme.primary.withValues(alpha: 0.15)
                        : null,
                    onPressed: () => _applyPreset(name),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              _buildField(
                'API 地址 (Base URL)',
                _baseUrlCtrl,
                hint: _protocol == 'anthropic'
                    ? AppConfig.anthropicBaseUrl
                    : AppConfig.agnesBaseUrl,
                obscureController: _obscureKey,
                onToggleObscure: () =>
                    setState(() => _obscureKey = !_obscureKey),
              ),
              const SizedBox(height: 14),
              _buildField(
                'API Key',
                _apiKeyCtrl,
                hint: 'sk-...',
                obscure: true,
                obscureController: _obscureKey,
                onToggleObscure: () =>
                    setState(() => _obscureKey = !_obscureKey),
              ),
              const SizedBox(height: 14),
              // v1.6.0：协议展示/选择
              _protocolRow(protocolEnum, isDark),
              const SizedBox(height: 14),
              // v1.6.0：模型手填 + 拉取列表
              _modelRow(isDark),
              const SizedBox(height: 14),
              _buildField(
                '系统提示词（可选）',
                _promptCtrl,
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _testing ? null : _testConnection,
                  icon: _testing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child:
                              CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.network_check),
                  label: Text(_testing ? '测试中…' : '测试连接'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              if (_testResult != null) ...[
                const SizedBox(height: 10),
                _resultCard(_testResult!, isDark),
              ],
            ],
          ),

          const SizedBox(height: 16),

          // ===== 联网搜索 =====
          _sectionCard(
            isDark: isDark,
            color: cardColor,
            title: '联网搜索',
            children: [
              _searchProviderSelector(isDark),
              const SizedBox(height: 14),
              // 选择 DeepSeek 时隐藏搜索接口地址（固定用官方地址）
              if (_searchProvider != 'DeepSeek') ...[
                _buildField(
                  '搜索接口地址',
                  _searchUrlCtrl,
                  hint: 'https://your-search-api/v1/tools/search',
                  onChanged: (_) => _onSearchInputChanged(),
                ),
                const SizedBox(height: 14),
              ],
              _buildField(
                _searchProvider == 'DeepSeek'
                    ? 'DeepSeek API Key（用于搜索）'
                    : '搜索接口 Key',
                _searchKeyCtrl,
                hint: 'sk-...',
                obscure: true,
                obscureController: _obscureSearchKey,
                onToggleObscure: () =>
                    setState(() => _obscureSearchKey = !_obscureSearchKey),
                onChanged: (_) => _onSearchInputChanged(),
              ),
              if (_searchProvider == 'DeepSeek') ...[
                const SizedBox(height: 6),
                Text(
                  '使用 DeepSeek 内置联网搜索，无需填写搜索地址',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
              const SizedBox(height: 16),
              Consumer<ChatProvider>(
                builder: (context, p, _) {
                  final checking = p.checkingSearch;
                  return SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: checking ? null : _checkSearch,
                      icon: checking
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.search_off),
                      label: Text(checking ? '检查中…' : '检查搜索配置'),
                      style: OutlinedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  );
                },
              ),
              Consumer<ChatProvider>(
                builder: (context, p, _) {
                  final result = p.searchCheckResult;
                  if (result == null) {
                    return _searchChecked
                        ? const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Text(
                              '✓ 已启用：输入框下方会出现「搜索：开/关」按钮',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.green),
                            ),
                          )
                        : const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: _resultCard(result, isDark),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ===== 外观 =====
          _sectionCard(
            isDark: isDark,
            color: cardColor,
            title: '外观',
            children: [_themeSelector(isDark)],
          ),

          const SizedBox(height: 20),
          const Center(
            child: Text(
              'EasyChatAI v1.6.0  ·  数据仅保存在本机',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  /// 顶部配置状态徽标：一眼确认当前配置状态
  Widget _statusBadge(bool configured, ApiProtocol protocol, bool isDark) {
    final color = configured ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            configured ? Icons.check_circle : Icons.info_outline,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              configured
                  ? '已配置 · ${protocol.label} · ${context.read<ChatProvider>().model}'
                  : '未配置 API Key · ${protocol.label}',
              style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// 协议行：预设锁定时展示徽标；自定义时展示 SegmentedButton
  Widget _protocolRow(ApiProtocol protocol, bool isDark) {
    final presetLocked = _presetName != null && _presetName != '自定义';
    return Row(
      children: [
        const Text('接口协议', style: TextStyle(fontSize: 13)),
        const SizedBox(width: 12),
        Expanded(
          child: presetLocked
              ? Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${protocol.label}（随预设）',
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.primary),
                      ),
                    ),
                  ],
                )
              : SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'openai',
                      label: Text('OpenAI 兼容', style: TextStyle(fontSize: 12)),
                    ),
                    ButtonSegment(
                      value: 'anthropic',
                      label: Text('Anthropic 兼容', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                  selected: {_protocol},
                  onSelectionChanged: (selection) =>
                      _switchProtocol(protocolFromStorage(selection.first)),
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
        ),
      ],
    );
  }

  /// 模型行：手填 + 拉取列表按钮
  Widget _modelRow(bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildField(
            '模型',
            _modelCtrl,
            hint: '手动填写或点右侧拉取列表',
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 52,
          child: OutlinedButton.icon(
            onPressed: _loadingModels ? null : _pickModel,
            icon: _loadingModels
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.list_alt, size: 18),
            label: const Text('拉取列表', style: TextStyle(fontSize: 12)),
          ),
        ),
      ],
    );
  }

  /// 结果展示卡片：成功绿 / 失败红，错误信息可换行完整展示
  Widget _resultCard(String result, bool isDark) {
    final ok = result.startsWith('✅');
    final color = ok ? Colors.green : Colors.red;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        result,
        style: TextStyle(fontSize: 13, color: color),
      ),
    );
  }

  /// 分组卡片容器
  Widget _sectionCard({
    required bool isDark,
    required Color color,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  /// 搜索提供商分段选择
  Widget _searchProviderSelector(bool isDark) {
    return Row(
      children: [
        const Text('提供商', style: TextStyle(fontSize: 13)),
        const SizedBox(width: 12),
        ...AppConfig.searchProviders.map((name) {
          final selected = _searchProvider == name;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(name),
              selected: selected,
              onSelected: (_) => _switchSearchProvider(name),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller, {
    String? hint,
    bool obscure = false,
    // v1.6.0：每个字段独立的可见性状态与回调
    bool obscureController = true,
    VoidCallback? onToggleObscure,
    int maxLines = 1,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure && obscureController,
      maxLines: maxLines,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        suffixIcon: obscure
            ? IconButton(
                icon: Icon(
                  obscureController
                      ? Icons.visibility_off
                      : Icons.visibility,
                ),
                onPressed: onToggleObscure,
              )
            : null,
      ),
    );
  }

  /// 主题选择：0 跟随系统 / 1 浅色 / 2 深色
  Widget _themeSelector(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Consumer<ChatProvider>(
          builder: (context, p, _) => Row(
            children: [
              _themeChip('跟随系统', 0, p.themeMode),
              const SizedBox(width: 8),
              _themeChip('浅色', 1, p.themeMode),
              const SizedBox(width: 8),
              _themeChip('深色', 2, p.themeMode),
            ],
          ),
        ),
        // v1.5：OLED 纯黑深色模式开关（仅深色模式下可生效）
        Consumer<ChatProvider>(
          builder: (context, p, _) => SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('深色模式使用纯黑背景（OLED 省电）',
                style: TextStyle(fontSize: 14)),
            value: p.oledDark,
            activeColor: AppTheme.primary,
            onChanged: (v) => p.setOledDark(v),
          ),
        ),
      ],
    );
  }

  Widget _themeChip(String label, int mode, int current) {
    return ChoiceChip(
      label: Text(label),
      selected: current == mode,
      onSelected: (_) => context.read<ChatProvider>().setThemeMode(mode),
    );
  }
}
