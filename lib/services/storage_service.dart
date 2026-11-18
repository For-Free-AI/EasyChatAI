import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../models/conversation.dart';

/// 本地存储层：保存 API 配置与历史对话（使用 shared_preferences）
/// 所有数据以 JSON 字符串形式存在本机，不上传任何服务器
class StorageService {
  static const _keyBaseUrl = 'base_url';
  static const _keyApiKey = 'api_key';
  static const _keyModel = 'model';
  static const _keySystemPrompt = 'system_prompt';
  // v1.6.0：API 协议（openai | anthropic），旧配置无此键时回退 openai
  static const _keyProtocol = 'api_protocol';
  static const _keyConversations = 'conversations';
  static const _keyTheme = 'theme_mode'; // 0跟随系统 1浅色 2深色

  // ===== V1.3 联网搜索配置 =====
  static const _keySearchProvider = 'search_provider';
  static const _keySearchApiKey = 'search_api_key';
  static const _keySearchBaseUrl = 'search_base_url';
  static const _keySearchConfigured = 'search_configured';

  final SharedPreferences _prefs;
  StorageService(this._prefs);

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  // ===== API 配置读写，首次使用默认填入 Agnes =====
  String get baseUrl =>
      _prefs.getString(_keyBaseUrl) ?? AppConfig.agnesBaseUrl;
  String get apiKey => _prefs.getString(_keyApiKey) ?? '';
  String get model => _prefs.getString(_keyModel) ?? AppConfig.agnesModel;
  // v1.6.0：API 协议，旧用户无记录时默认 openai（行为与旧版一致）
  String get protocol => _prefs.getString(_keyProtocol) ?? 'openai';
  String get systemPrompt {
    final saved = _prefs.getString(_keySystemPrompt);
    if (saved == null || saved.isEmpty) return AppConfig.defaultSystemPrompt;
    // V1.4.3：从未改过、仍是旧默认文案的存量用户，平滑升级到新默认提示词；
    // 用户自定义过的内容原样保留，不被覆盖。
    if (saved.trim() == AppConfig.legacyDefaultSystemPrompt) {
      return AppConfig.defaultSystemPrompt;
    }
    return saved;
  }

  Future<void> saveConfig({
    required String baseUrl,
    required String apiKey,
    required String model,
    required String systemPrompt,
    required String protocol,
  }) async {
    await _prefs.setString(_keyBaseUrl, baseUrl);
    await _prefs.setString(_keyApiKey, apiKey);
    await _prefs.setString(_keyModel, model);
    await _prefs.setString(_keySystemPrompt, systemPrompt);
    await _prefs.setString(_keyProtocol, protocol);
  }

  // ===== 联网搜索配置读写 =====
  String get searchProvider => _prefs.getString(_keySearchProvider) ?? '';
  String get searchApiKey => _prefs.getString(_keySearchApiKey) ?? '';
  String get searchBaseUrl => _prefs.getString(_keySearchBaseUrl) ?? '';
  bool get searchConfigured => _prefs.getBool(_keySearchConfigured) ?? false;

  Future<void> saveSearchConfig({
    required String provider,
    required String apiKey,
    required String baseUrl,
    required bool configured,
  }) async {
    await _prefs.setString(_keySearchProvider, provider);
    await _prefs.setString(_keySearchApiKey, apiKey);
    await _prefs.setString(_keySearchBaseUrl, baseUrl);
    await _prefs.setBool(_keySearchConfigured, configured);
  }

  // ===== 历史对话读写 =====
  List<Conversation> loadConversations() {
    final raw = _prefs.getString(_keyConversations);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => Conversation.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveConversations(List<Conversation> conversations) async {
    final raw = jsonEncode(conversations.map((c) => c.toJson()).toList());
    await _prefs.setString(_keyConversations, raw);
  }

  // ===== 主题模式读写 =====
  int get themeMode => _prefs.getInt(_keyTheme) ?? 0;
  Future<void> saveThemeMode(int mode) => _prefs.setInt(_keyTheme, mode);

  // v1.5：OLED 纯黑深色模式
  static const _keyOledDark = 'oled_dark';
  bool get oledDark => _prefs.getBool(_keyOledDark) ?? false;
  Future<void> saveOledDark(bool value) => _prefs.setBool(_keyOledDark, value);
}
