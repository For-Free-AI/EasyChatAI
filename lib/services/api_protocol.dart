import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/message.dart';

/// v1.6.0：API 协议抽象
/// 支持两种 wire 协议：OpenAI Chat Completions 兼容 与 Anthropic Messages 兼容。
/// 上层（Provider/页面）只面向 ApiProtocol 与统一回调，不感知具体协议差异。
enum ApiProtocol { openai, anthropic }

/// 从存储值恢复协议（未知值一律回退 openai，保证旧配置平滑迁移）
ApiProtocol protocolFromStorage(String? value) =>
    value == 'anthropic' ? ApiProtocol.anthropic : ApiProtocol.openai;

extension ApiProtocolX on ApiProtocol {
  /// 设置页展示用名称
  String get label => this == ApiProtocol.openai ? 'OpenAI 兼容' : 'Anthropic 兼容';

  /// 本地持久化用值
  String get storeValue => this == ApiProtocol.openai ? 'openai' : 'anthropic';
}

/// 强制按 UTF-8 解码响应体，避免中文被 ISO-8859-1 误解码成乱码
String decodeResponseBody(http.Response response) {
  try {
    return utf8.decode(response.bodyBytes);
  } catch (_) {
    return response.body;
  }
}

/// 统一的 HTTP 错误格式化：尽量提取 JSON 中的 error.message
String formatHttpError(int code, String body) {
  String detail = body;
  try {
    final json = jsonDecode(body) as Map<String, dynamic>;
    final error = json['error'];
    if (error is Map<String, dynamic>) {
      detail = error['message'] as String? ?? body;
    } else if (error is String) {
      detail = error;
    }
  } catch (_) {}
  if (detail.length > 200) detail = detail.substring(0, 200);
  return 'HTTP $code：$detail';
}

/// 解析模型列表 JSON（OpenAI 与 Anthropic 的 /models 响应结构一致：data[].id）
/// 自动过滤图片/视频/音频/嵌入等非文本模型
List<String> parseModelsJson(Map<String, dynamic> json) {
  final data = json['data'] as List<dynamic>? ?? [];
  final models = <String>[];
  for (final item in data) {
    if (item is! Map<String, dynamic>) continue;
    final id = item['id'] as String?;
    if (id == null || id.isEmpty) continue;
    final lower = id.toLowerCase();
    if (lower.contains('image') ||
        lower.contains('video') ||
        lower.contains('audio') ||
        lower.contains('tts') ||
        lower.contains('whisper') ||
        lower.contains('embedding') ||
        lower.contains('rerank')) {
      continue;
    }
    if (!models.contains(id)) models.add(id);
  }
  return models;
}

/// 协议适配器统一接口：两种协议对上层暴露完全一致的能力
abstract class ProtocolAdapter {
  /// 请求头（含鉴权差异：Bearer vs x-api-key）
  Map<String, String> headers(String apiKey);

  /// 主对话端点完整地址
  String chatUrl(String baseUrl);

  /// 主对话请求体（含 system 位置、thinking 映射、max_tokens 差异）
  Map<String, dynamic> chatBody({
    required String model,
    required String systemPrompt,
    required List<ChatMessage> history,
    required bool enableThinking,
    required bool stream,
  });

  /// 附带 usage 选项的请求体（不支持的协议原样返回）
  Map<String, dynamic> withUsageOption(Map<String, dynamic> body);

  /// 400 时返回降级请求体；无降级项返回 null
  Map<String, dynamic>? degradeBody(Map<String, dynamic> body);

  /// 非流式简单请求体（自动命名 / 搜索判断 / 测试连接）
  Map<String, dynamic> simpleBody({
    required String model,
    required String system,
    required String user,
    int maxTokens = 100,
    double temperature = 0.3,
  });

  /// 从非流式响应 JSON 提取回复文本
  String extractReplyText(Map<String, dynamic> json);

  /// 模型列表端点
  String modelsUrl(String baseUrl);

  /// 解析模型列表
  List<String> parseModels(Map<String, dynamic> json);

  /// 解析单行 SSE 数据，分发正文 / 思维链 / 用量回调
  void handleSseLine(
    String line,
    void Function(String) onDelta,
    void Function(int prompt, int completion, int total)? onUsage, [
    void Function(String)? onReasoning,
  ]);
}
