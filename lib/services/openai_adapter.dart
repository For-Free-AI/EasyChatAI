import 'dart:convert';

import '../config/app_config.dart';
import '../models/message.dart';
import 'api_protocol.dart';

/// v1.6.0：OpenAI Chat Completions 兼容协议适配器
/// 承载 v1.5.1 及之前版本的全部线上行为，迁移后逻辑保持零变化。
class OpenAiAdapter extends ProtocolAdapter {
  @override
  Map<String, String> headers(String apiKey) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $apiKey',
  };

  /// 拼接完整聊天地址，兼容用户填入带/不带 /v1 的情况
  @override
  String chatUrl(String baseUrl) {
    var url = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (url.endsWith('/chat/completions')) return url;
    return url + AppConfig.chatPath;
  }

  /// 主对话请求体
  @override
  Map<String, dynamic> chatBody({
    required String model,
    required String systemPrompt,
    required List<ChatMessage> history,
    required bool enableThinking,
    required bool stream,
  }) {
    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': systemPrompt},
      ...history.map((m) => {'role': m.role, 'content': m.content}),
    ];
    final body = <String, dynamic>{
      'model': model,
      'messages': messages,
      'stream': stream,
    };
    if (enableThinking) {
      body['chat_template_kwargs'] = {'enable_thinking': true};
    }
    return body;
  }

  /// 附带 usage 选项的请求体（多数 OpenAI 兼容服务支持）
  @override
  Map<String, dynamic> withUsageOption(Map<String, dynamic> body) {
    return Map<String, dynamic>.from(body)
      ..['stream_options'] = {'include_usage': true};
  }

  /// 服务端不认识 stream_options 返回 400 时，去掉该字段重试；无可降级项返回 null
  @override
  Map<String, dynamic>? degradeBody(Map<String, dynamic> body) {
    if (!body.containsKey('stream_options')) return null;
    final degraded = Map<String, dynamic>.from(body)..remove('stream_options');
    return degraded;
  }

  /// 非流式简单请求体（自动命名 / 搜索判断 / 测试连接）
  @override
  Map<String, dynamic> simpleBody({
    required String model,
    required String system,
    required String user,
    int maxTokens = 100,
    double temperature = 0.3,
  }) {
    final messages = <Map<String, dynamic>>[];
    if (system.trim().isNotEmpty) {
      messages.add({'role': 'system', 'content': system});
    }
    messages.add({'role': 'user', 'content': user});
    return {
      'model': model,
      'messages': messages,
      'stream': false,
      'max_tokens': maxTokens,
      'temperature': temperature,
      // 关闭思考，避免标题/判断输出被思维链占用
      'chat_template_kwargs': {'enable_thinking': false},
    };
  }

  /// 从非流式响应 JSON 提取回复文本
  @override
  String extractReplyText(Map<String, dynamic> json) {
    final choices = json['choices'] as List<dynamic>? ?? [];
    if (choices.isEmpty) return '';
    final msg =
        (choices[0] as Map<String, dynamic>)['message']
            as Map<String, dynamic>?;
    return (msg?['content'] as String? ?? '').trim();
  }

  @override
  String modelsUrl(String baseUrl) {
    final root = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    return '$root/models';
  }

  @override
  List<String> parseModels(Map<String, dynamic> json) => parseModelsJson(json);

  /// 解析单行 SSE 数据（含用量块与思考内容字段的兼容处理）
  @override
  void handleSseLine(
    String line,
    void Function(String) onDelta,
    void Function(int prompt, int completion, int total)? onUsage, [
    void Function(String)? onReasoning,
  ]) {
    if (!line.startsWith('data:')) return;
    final data = line.substring(5).trim();
    if (data.isEmpty || data == '[DONE]') return;
    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      // 用量块：choices 为空但顶层带 usage
      final usage = _extractUsage(json);
      if (usage != null && onUsage != null) {
        onUsage(usage['prompt']!, usage['completion']!, usage['total']!);
      }
      final choices = json['choices'] as List<dynamic>? ?? [];
      if (choices.isEmpty) return;
      final delta =
          (choices[0] as Map<String, dynamic>)['delta']
              as Map<String, dynamic>?;
      if (delta == null) return;

      // 思维链字段解析（与正文分开回调）
      final reasoning = _extractReasoning(delta);
      if (reasoning.isNotEmpty && onReasoning != null) {
        onReasoning(reasoning);
      }

      // 正文 content 原样回调：内嵌 <think> 标签由 Provider 层状态机统一处理
      final content = delta['content'] as String? ?? '';
      if (content.isNotEmpty) onDelta(content);
    } catch (_) {
      // 忽略无法解析的块（如心跳包）
    }
  }

  /// 从 delta 中提取思考文本，兼容多种字段命名与结构
  String _extractReasoning(Map<String, dynamic> delta) {
    // 1) 最常见：reasoning_content（字符串）
    final rc = delta['reasoning_content'];
    if (rc is String && rc.isNotEmpty) return rc;

    // 2) reasoning（字符串）
    final r = delta['reasoning'];
    if (r is String && r.isNotEmpty) return r;

    // 3) reasoning_details：可能是字符串，或 [{text:...}, {reasoning:...}] 数组
    final rd = delta['reasoning_details'];
    if (rd is String && rd.isNotEmpty) return rd;
    if (rd is List) {
      final sb = StringBuffer();
      for (final item in rd) {
        if (item is Map<String, dynamic>) {
          final t = item['text'] ?? item['reasoning'] ?? item['content'];
          if (t is String && t.isNotEmpty) sb.write(t);
        }
      }
      return sb.toString();
    }
    return '';
  }

  /// 从响应 JSON 中提取 token 用量，兼容 prompt_tokens 与 input_tokens 两种命名
  Map<String, int>? _extractUsage(Map<String, dynamic> json) {
    final usage = json['usage'];
    if (usage is! Map<String, dynamic>) return null;
    final p = usage['prompt_tokens'] ?? usage['input_tokens'];
    final c = usage['completion_tokens'] ?? usage['output_tokens'];
    if (p is! num || c is! num) return null;
    final t = usage['total_tokens'];
    final total = t is num ? t.toInt() : p.toInt() + c.toInt();
    return {'prompt': p.toInt(), 'completion': c.toInt(), 'total': total};
  }
}
