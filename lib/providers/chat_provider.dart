import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import '../services/api_service.dart';
import '../services/backup_service.dart';
import '../services/storage_service.dart';

/// 状态管理层：全局状态中心
/// V1.1：按会话记录模型/思考、首轮后自动命名、模型列表加载
/// V1.3：联网搜索配置、会话级搜索开关、判断→搜索→注入→流式、token 用量
class ChatProvider with ChangeNotifier {
  late StorageService _storage;
  final ApiService _api = ApiService();

  List<Conversation> _conversations = [];
  String? _currentId;
  bool _isGenerating = false;
  String? _error;
  int _themeMode = 0;

  // 当前 API 账户可用的模型列表（自动拉取）
  List<String> _availableModels = [];
  bool _loadingModels = false;

  // ===== V1.3 联网搜索配置 =====
  String _searchProvider = '';
  String _searchApiKey = '';
  String _searchBaseUrl = '';
  bool _searchConfigured = false;
  bool _checkingSearch = false;
  String? _searchCheckResult;

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _storage = await StorageService.init();
    _conversations = _storage.loadConversations();
    _themeMode = _storage.themeMode;
    _oledDark = _storage.oledDark;
    // V1.3 读取搜索配置
    _searchProvider = _storage.searchProvider;
    _searchApiKey = _storage.searchApiKey;
    _searchBaseUrl = _storage.searchBaseUrl;
    _searchConfigured = _storage.searchConfigured;
    // 确保始终至少有一个会话，否则切换模型/思考/搜索时 current 为 null 会失效
    if (_conversations.isEmpty) {
      _conversations.add(_createConversation());
    }
    _initialized = true;
    if (apiKey.isNotEmpty) {
      await loadModels(silent: true);
      // 修复历史版本遗留的乱码标题
      _repairGarbledTitles();
    }
    notifyListeners();
  }

  /// 检测并修复旧版本保存的乱码标题（UTF-8 被 Latin-1 误解码）
  void _repairGarbledTitles() {
    for (final conv in _conversations) {
      if (conv.messages.isEmpty || !_looksGarbled(conv.title)) continue;
      final firstRound = conv.messages
          .where((m) => m.role == 'user' || m.role == 'assistant')
          .take(2)
          .toList();
      _api
          .generateTitle(
            baseUrl: baseUrl,
            apiKey: apiKey,
            model: conv.model.isNotEmpty ? conv.model : model,
            firstRound: firstRound,
            protocol: protocol,
          )
          .then((title) {
            if (title != null && title.isNotEmpty) {
              conv.title = title;
              conv.canRename = true;
              _persist();
              notifyListeners();
            }
          });
    }
  }

  bool _looksGarbled(String s) {
    if (s.isEmpty) return false;
    if (RegExp(r'[\u4e00-\u9fff\u3040-\u30ff\uac00-\ud7af]').hasMatch(s)) {
      return false;
    }
    final garbled = RegExp(r'[\u00c0-\u00ff]').allMatches(s).length;
    return garbled >= 2;
  }

  // ===== Getter =====
  List<Conversation> get conversations => _conversations;
  bool get isGenerating => _isGenerating;
  String? get error => _error;
  int get themeMode => _themeMode;
  List<String> get availableModels => _availableModels;
  bool get loadingModels => _loadingModels;
  bool get isConfigured => apiKey.isNotEmpty;

  // 联网搜索配置
  String get searchProvider => _searchProvider;
  String get searchApiKey => _searchApiKey;
  String get searchBaseUrl => _searchBaseUrl;
  bool get searchConfigured => _searchConfigured;
  bool get checkingSearch => _checkingSearch;
  String? get searchCheckResult => _searchCheckResult;

  /// 搜索开关是否可用：配置检查通过 + 已配置主 API
  bool get searchAvailable => _searchConfigured && isConfigured;

  // 当前会话（找不到则取第一个）
  Conversation? get current {
    if (_conversations.isEmpty) return null;
    final id = _currentId;
    if (id != null) {
      for (final c in _conversations) {
        if (c.id == id) return c;
      }
    }
    return _conversations.first;
  }

  // ===== API 全局配置代理 =====
  String get baseUrl =>
      _initialized ? _storage.baseUrl : AppConfig.agnesBaseUrl;
  String get apiKey => _initialized ? _storage.apiKey : '';
  String get model => _initialized ? _storage.model : AppConfig.agnesModel;
  String get systemPrompt =>
      _initialized ? _storage.systemPrompt : AppConfig.defaultSystemPrompt;

  /// v1.6.0：API 协议（'openai' | 'anthropic'），旧配置默认 openai
  String get protocol => _initialized ? _storage.protocol : 'openai';

  // ===== 当前会话的模型 / 思考 / 搜索开关（按会话，回退全局）=====
  String get currentModel {
    final c = current;
    if (c != null && c.model.isNotEmpty) return c.model;
    return model;
  }

  bool get currentThinking => current?.enableThinking ?? false;

  /// V1.3：当前会话的搜索开关（仅当搜索配置可用时有意义）
  bool get currentSearching =>
      (current?.enableSearch ?? false) && searchAvailable;

  /// 创建新会话。
  /// [inheritFrom] 不为空时，继承其「模型 / 思考开关 / 搜索开关」，
  /// 用于「新建对话」时保持上一次对话的设置（V1.4.2）。
  /// 为空时回退全局默认值，用于首次初始化、删除到空等没有"上一次对话"的场景。
  Conversation _createConversation({Conversation? inheritFrom}) {
    final src = inheritFrom;
    return Conversation(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: '新对话',
      // 上一次对话若已选模型则沿用，否则回退全局默认模型
      model: (src != null && src.model.isNotEmpty) ? src.model : model,
      enableThinking: src?.enableThinking ?? false,
      enableSearch: src?.enableSearch ?? false,
    );
  }

  Conversation _ensureCurrent() {
    final c = current;
    if (c != null) return c;
    final conv = _createConversation();
    _conversations.insert(0, conv);
    _currentId = conv.id;
    return conv;
  }

  /// 设置当前会话使用的模型
  void setConversationModel(String newModel) {
    final c = _ensureCurrent();
    c.model = newModel;
    _persist();
    notifyListeners();
  }

  /// 切换当前会话的思考开关
  void setThinking(bool enabled) {
    final c = _ensureCurrent();
    c.enableThinking = enabled;
    _persist();
    notifyListeners();
  }

  /// V1.3：切换当前会话的联网搜索开关
  void setSearching(bool enabled) {
    if (enabled && !searchAvailable) return; // 配置检查未通过不允许开启
    final c = _ensureCurrent();
    c.enableSearch = enabled;
    _persist();
    notifyListeners();
  }

  Future<void> saveConfig({
    required String baseUrl,
    required String apiKey,
    required String model,
    required String systemPrompt,
    required String protocol,
  }) async {
    await _storage.saveConfig(
      baseUrl: baseUrl,
      apiKey: apiKey,
      model: model,
      systemPrompt: systemPrompt,
      protocol: protocol,
    );
    final c = current;
    if (c != null && c.messages.isEmpty) {
      c.model = model;
    }
    await loadModels(silent: true);
    notifyListeners();
  }

  /// V1.3：保存联网搜索配置（是否通过由检查决定）
  Future<void> saveSearchConfig({
    required String provider,
    required String apiKey,
    required String baseUrl,
    required bool configured,
  }) async {
    _searchProvider = provider;
    _searchApiKey = apiKey;
    _searchBaseUrl = baseUrl;
    _searchConfigured = configured;
    await _storage.saveSearchConfig(
      provider: provider,
      apiKey: apiKey,
      baseUrl: baseUrl,
      configured: configured,
    );
    notifyListeners();
  }

  /// V1.3：检查搜索配置是否可用（写入结果供设置页展示）
  Future<void> checkSearchConfig({
    required String provider,
    required String apiKey,
    required String baseUrl,
  }) async {
    _checkingSearch = true;
    _searchCheckResult = null;
    notifyListeners();
    final resolvedUrl = provider == 'DeepSeek'
        ? AppConfig.deepseekSearchUrl
        : baseUrl;
    final err = await _api.checkSearchConfig(
      searchUrl: resolvedUrl,
      apiKey: apiKey,
    );
    _checkingSearch = false;
    if (err == null) {
      _searchCheckResult = '✅ 搜索配置可用';
    } else {
      _searchCheckResult = '❌ $err';
    }
    notifyListeners();
  }

  void clearSearchCheckResult() {
    _searchCheckResult = null;
    notifyListeners();
  }

  Future<void> setThemeMode(int mode) async {
    _themeMode = mode;
    await _storage.saveThemeMode(mode);
    notifyListeners();
  }

  // ===== v1.5：OLED 纯黑深色模式 =====
  bool _oledDark = false;

  bool get oledDark => _oledDark;

  Future<void> setOledDark(bool value) async {
    _oledDark = value;
    await _storage.saveOledDark(value);
    notifyListeners();
  }

  Future<void> loadModels({bool silent = false}) async {
    if (apiKey.isEmpty) {
      _availableModels = List<String>.from(AppConfig.agnesModels);
      notifyListeners();
      return;
    }
    _loadingModels = true;
    notifyListeners();
    try {
      final list = await _api.fetchModels(
        baseUrl: baseUrl,
        apiKey: apiKey,
        protocol: protocol,
      );
      _availableModels = list.isNotEmpty
          ? list
          : List<String>.from(AppConfig.agnesModels);
    } catch (_) {
      _availableModels = List<String>.from(AppConfig.agnesModels);
      if (!silent) {
        _error = '模型列表拉取失败，已显示预置模型';
      }
    }
    _loadingModels = false;
    notifyListeners();
  }

  // ===== 会话管理 =====
  void selectConversation(String id) {
    _currentId = id;
    _error = null;
    notifyListeners();
  }

  String newConversation() {
    if (_isGenerating) return _currentId ?? '';
    final cur = current;
    if (cur != null && cur.messages.isEmpty) {
      _currentId = cur.id;
      notifyListeners();
      return cur.id;
    }
    // V1.4.2：新建对话时继承当前（上一次）对话的模型/思考/搜索开关
    final conv = _createConversation(inheritFrom: cur);
    _conversations.insert(0, conv);
    _currentId = conv.id;
    _persist();
    notifyListeners();
    return conv.id;
  }

  void deleteConversation(String id) {
    _conversations.removeWhere((c) => c.id == id);
    if (_currentId == id) _currentId = null;
    if (_conversations.isEmpty) {
      final conv = _createConversation();
      _conversations.add(conv);
      _currentId = conv.id;
    }
    _persist();
    notifyListeners();
  }

  void renameConversation(String id, String newTitle) {
    final t = newTitle.trim();
    if (t.isEmpty) return;
    for (final c in _conversations) {
      if (c.id == id && c.canRename) {
        c.title = t.length > 30 ? t.substring(0, 30) : t;
        _persist();
        notifyListeners();
        return;
      }
    }
  }

  /// V1.4.1：侧边栏重命名——不受 canRename 限制（任意对话都可改）
  /// 手动改名后同时解锁后续改名，并抑制自动命名覆盖
  void renameConversationAny(String id, String newTitle) {
    final t = newTitle.trim();
    if (t.isEmpty) return;
    for (final c in _conversations) {
      if (c.id == id) {
        c.title = t.length > 30 ? t.substring(0, 30) : t;
        c.canRename = true;
        c.namingTriggered = true; // 用户已手动命名，阻止后台自动命名覆盖
        _persist();
        notifyListeners();
        return;
      }
    }
  }

  /// V1.4.1：批量删除对话；若删掉当前会话则自动切到剩余第一个
  void deleteConversations(List<String> ids) {
    if (ids.isEmpty) return;
    _conversations.removeWhere((c) => ids.contains(c.id));
    if (_currentId == null || ids.contains(_currentId)) {
      _currentId = _conversations.isNotEmpty ? _conversations.first.id : null;
    }
    if (_conversations.isEmpty) {
      _conversations.add(_createConversation());
      _currentId = _conversations.first.id;
    }
    _persist();
    notifyListeners();
  }

  /// v1.8.1：把会话导出到用户自选位置（系统文件管理器）。
  /// [fileName] 用于单条对话导出时指定文件名；返回是否保存成功。
  Future<bool> exportConversations({String? fileName}) async {
    try {
      final path = await BackupService.saveConversations(
        _conversations,
        fileName: fileName,
      );
      return path != null;
    } catch (_) {
      return false;
    }
  }

  /// v1.8.1：从文件导入会话，按 id 去重合并。
  /// 返回 ImportResult，区分取消 / 格式错误 / 成功，便于 UI 给出明确提示。
  Future<ImportResult> importConversations() async {
    final result = await BackupService.pickAndDecode();
    if (result.status != ImportStatus.success) return result;
    final decoded = result.conversations;
    final before = _conversations.length;
    _conversations = BackupService.merge(_conversations, decoded);
    final added = _conversations.length - before;
    if (_currentId == null && _conversations.isNotEmpty) {
      _currentId = _conversations.first.id;
    }
    _persist();
    notifyListeners();
    return ImportResult.success(decoded, added: added);
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// 发送消息：判断是否需要搜索 →（需要则搜索并注入上下文）→ 流式对话
  Future<void> sendMessage(String text) async {
    final content = text.trim();
    if (content.isEmpty || _isGenerating) return;

    final Conversation conv = _ensureCurrent();
    final isFirstRound = !conv.messages.any((m) => m.role == 'user');

    conv.messages.add(ChatMessage(role: 'user', content: content));
    _error = null;
    _isGenerating = true;

    // V1.4：记录发送瞬间的思考开关快照（发送中用户切换不影响本轮）
    final assistantMessage = ChatMessage(
      role: 'assistant',
      content: '',
      thinkingEnabled: conv.enableThinking,
    );
    conv.messages.add(assistantMessage);

    final history = conv.messages
        .sublist(0, conv.messages.length - 1)
        .map((m) => ChatMessage(role: m.role, content: m.content))
        .toList();

    notifyListeners();

    // ===== V1.3 联网搜索流程：判断 → 搜索 → 注入上下文 =====
    var effectiveSystemPrompt = systemPrompt;
    var searched = false;
    if (currentSearching) {
      try {
        // 1) 让模型判断是否需要联网搜索
        final decision = await _api.judgeSearch(
          baseUrl: baseUrl,
          apiKey: apiKey,
          model: currentModel,
          userQuestion: content,
          protocol: protocol,
        );
        // 2) 需要则调用搜索接口
        if (decision.needSearch && decision.query.isNotEmpty) {
          final resolvedUrl = _searchProvider == 'DeepSeek'
              ? AppConfig.deepseekSearchUrl
              : _searchBaseUrl;
          final results = await _api.webSearch(
            searchUrl: resolvedUrl,
            apiKey: _searchApiKey,
            query: decision.query,
          );
          // 3) 把搜索结果注入 system 上下文
          final ctx = _api.formatSearchContext(results);
          if (ctx.isNotEmpty) {
            effectiveSystemPrompt = '$systemPrompt\n\n$ctx';
            searched = true;
          }
        }
      } catch (_) {
        // 搜索任何环节失败都静默降级为直接对话，不阻断用户
        searched = false;
      }
    }
    assistantMessage.searched = searched;

    // ===== V1.4：思维链处理 =====
    // 只要本轮收到任意思考文本即判定为「形态一：可展开」（对应规划 1.A）
    void feedReasoning(String r) {
      if (r.isEmpty) return;
      assistantMessage.reasoning += r;
      assistantMessage.reasoningSupported = true;
    }

    // 正文里内嵌 <think>...</think> 的状态机（跨分块累积），兼容非主流服务
    var inInlineThink = false;
    void feedContent(String delta) {
      var rest = delta;
      while (rest.isNotEmpty) {
        if (inInlineThink) {
          final end = rest.indexOf('</think>');
          if (end >= 0) {
            if (end > 0) feedReasoning(rest.substring(0, end));
            inInlineThink = false;
            rest = rest.substring(end + '</think>'.length);
          } else {
            feedReasoning(rest);
            rest = '';
          }
        } else {
          final start = rest.indexOf('<think>');
          if (start >= 0) {
            if (start > 0) assistantMessage.content += rest.substring(0, start);
            inInlineThink = true;
            rest = rest.substring(start + '<think>'.length);
          } else {
            assistantMessage.content += rest;
            rest = '';
          }
        }
      }
    }

    // ===== 流式对话（含用量、思维链回调）=====
    _api.streamChat(
      baseUrl: baseUrl,
      apiKey: apiKey,
      model: currentModel,
      systemPrompt: effectiveSystemPrompt,
      history: history,
      enableThinking: conv.enableThinking,
      onDelta: (delta) {
        feedContent(delta);
        notifyListeners();
      },
      onReasoning: (r) {
        feedReasoning(r);
        notifyListeners();
      },
      onDone: () {
        _isGenerating = false;
        _persist();
        notifyListeners();
        // 首轮回答完成后，后台静默自动命名（仅一次）
        if (isFirstRound && !conv.namingTriggered) {
          _autoNameConversation(conv);
        }
      },
      onError: (err) {
        _isGenerating = false;
        if (assistantMessage.content.isEmpty) {
          conv.messages.remove(assistantMessage);
        }
        _error = err;
        _persist();
        notifyListeners();
      },
      onUsage: (prompt, completion, total) {
        // 用量块在最后到达，写入本条 assistant 消息供末尾展示
        assistantMessage.promptTokens = prompt;
        assistantMessage.completionTokens = completion;
        assistantMessage.totalTokens = total;
        notifyListeners();
      },
      protocol: protocol,
    );
  }

  /// 后台自动命名：仅新对话首轮回答后触发一次，用户无感知
  Future<void> _autoNameConversation(Conversation conv) async {
    if (conv.namingTriggered) return;
    conv.namingTriggered = true;
    _persist();

    final firstRound = conv.messages
        .where((m) => m.role == 'user' || m.role == 'assistant')
        .take(2)
        .toList();
    final title = await _api.generateTitle(
      baseUrl: baseUrl,
      apiKey: apiKey,
      model: currentModel,
      firstRound: firstRound,
      protocol: protocol,
    );
    if (title != null && title.isNotEmpty) {
      conv.title = title;
    } else {
      final firstUser = firstRound.firstWhere(
        (m) => m.role == 'user',
        orElse: () => ChatMessage(role: '', content: ''),
      );
      final fallback = firstUser.content.trim();
      if (fallback.isNotEmpty) {
        conv.title = fallback.length > 12
            ? '${fallback.substring(0, 12)}…'
            : fallback;
      }
    }
    conv.canRename = true;
    _persist();
    notifyListeners();
  }

  void stopGenerating() {
    _api.cancel();
    _isGenerating = false;
    _persist();
    notifyListeners();
  }

  void _persist() {
    if (_initialized) _storage.saveConversations(_conversations);
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }
}
