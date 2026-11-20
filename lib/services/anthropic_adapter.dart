import 'dart:convert';

import '../config/app_config.dart';
import '../models/message.dart';
import 'api_protocol.dart';

/// v1.6.0：Anthropic Messages 兼容协议适配器
/// https://docs.anthropic.com/en/api/messages
/// 差异要点：
/// - 鉴权：x-api-key + anthropic-version（非 Bearer）
/// - 系统提示词独立 system 字段
/// - max_tokens 必填；开思考时必须大于 thinking.budget_tokens
/// - 流式为事件制：message_start(usage.input) / content_block_delta(text|thinking)
///   / message_delta(usage.output) / message_stop
class AnthropicAdapter extends ProtocolAdapter {
  /// message_start 帧带来的 input_tokens，在 message_delta 时合并输出
  int _inputTokens = 0;

  @override
  Map<String, String> headers(String apiKey) => {
    'Content-Type': 'application/json',
    'x-api-key': apiKey,
    'anthropic-version': '2023-06-01',
  };

  /// 拼接 Messages 端点：兼容用户填入带/不带 /v1 的情况
  @override
  String chatUrl(String baseUrl) {
    var url = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (url.endsWith('/messages')) return url;
    if (url.endsWith('/v1')) return '$url/messages';
    return '$url/v1/messages';
  }

  /// 主对话请求体。history 只含 user/assistant（system 独立传递）；
  /// 连续同角色消息自动合并，满足 Anthropic 的交替要求。
  @override
  Map<String, dynamic> chatBody({
    required String model,
    required String systemPrompt,
    required List<ChatMessage> history,
    required bool enableThinking,
    required bool stream,
  }) {
    final messages = <Map<String, dynamic>>[];
    for (final m in history) {
      final role = m.role == 'assistant' ? 'assistant' : 'user';
      if (messages.isNotEmpty && (messages.last['role'] as String) == role) {
        // 合并连续同角色内容，避免 400
        messages.last['content'] = '${messages.last['content']}\n${m.content}';
      } else {
        messages.add({'role': role, 'content': m.content});
      }
    }
    final body = <String, dynamic>{
      'model': model,
      'max_tokens': AppConfig.anthropicMaxTokens,
      'messages': messages,
      'stream': stream,
    };
    if (systemPrompt.trim().isNotEmpty) {
      body['system'] = systemPrompt;
    }
    if (enableThinking) {
      // 扩展思考：budget 必须小于 max_tokens
      body['thinking'] = {
        'type': 'enabled',
        'budget_tokens': AppConfig.anthropicThinkingBudget,
      };
      body['max_tokens'] =
          AppConfig.anthropicMaxTokens + AppConfig.anthropicThinkingBudget;
    }
    return body;
  }

  /// Anthropic 流式天然带 usage，无需额外选项
  @override
  Map<String, dynamic> withUsageOption(Map<String, dynamic> body) => body;

  /// Anthropic 无需 400 降级重试
  @override
  Map<String, dynamic>? degradeBody(Map<String, dynamic> body) => null;

  /// 非流式简单请求体（自动命名 / 搜索判断 / 测试连接）
  @override
  Map<String, dynamic> simpleBody({
    required String model,
    required String system,
    required String user,
    int maxTokens = 100,
    double temperature = 0.3,
  }) {
    final body = <String, dynamic>{
      'model': model,
      'max_tokens': maxTokens,
      'messages': [
        {'role': 'user', 'content': user},
      ],
      'stream': false,
    };
    if (system.trim().isNotEmpty) {
      body['system'] = system;
    }
    return body;
  }

  /// 从非流式响应 JSON 提取回复文本（content 数组中 type=text 的块）
  @override
  String extractReplyText(Map<String, dynamic> json) {
    final content = json['content'];
    if (content is String) return content.trim();
    if (content is List) {
      final sb = StringBuffer();
      for (final block in content) {
        if (block is Map<String, dynamic> && block['type'] == 'text') {
          final t = block['text'];
          if (t is String) sb.write(t);
        }
      }
      return sb.toString().trim();
    }
    return '';
  }

  @override
  String modelsUrl(String baseUrl) {
    var url = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (url.endsWith('/v1')) return '$url/models';
    return '$url/v1/models';
  }

  @override
  List<String> parseModels(Map<String, dynamic> json) {
    // Anthropic 官方 /models 只返回文本对话模型，无需过滤
    final data = json['data'] as List<dynamic>? ?? [];
    final models = <String>[];
    for (final item in data) {
      if (item is! Map<String, dynamic>) continue;
      final id = item['id'] as String?;
      if (id == null || id.isEmpty) continue;
      if (!models.contains(id)) models.add(id);
    }
    return models;
  }

  /// 解析单行 SSE 数据（事件制协议，按 json.type 分发）
  @override
  void handleSseLine(
    String line,
    void Function(String) onDelta,
    void Function(int prompt, int completion, int total)? onUsage, [
    void Function(String)? onReasoning,
  ]) {
    if (!line.startsWith('data:')) return;
    final data = line.substring(5).trim();
    if (data.isEmpty) return;
    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      switch (json['type']) {
        case 'message_start':
          // 输入 token 在流开始时给出
          final usage = json['message']?['usage'];
          if (usage is Map<String, dynamic>) {
            final input = usage['input_tokens'];
            if (input is num) _inputTokens = input.toInt();
          }
          break;
        case 'content_block_delta':
          final delta = json['delta'];
          if (delta is! Map<String, dynamic>) break;
          final type = delta['type'];
          if (type == 'thinking_delta') {
            final thinking = delta['thinking'];
            if (thinking is String && thinking.isNotEmpty) {
              onReasoning?.call(thinking);
            }
          } else if (type == 'text_delta') {
            final text = delta['text'];
            if (text is String && text.isNotEmpty) onDelta(text);
          }
          break;
        case 'message_delta':
          // 输出 token 在流结束时给出，与 message_start 的 input 合并
          final usage = json['usage'];
          if (usage is Map<String, dynamic> && onUsage != null) {
            final output = usage['output_tokens'];
            if (output is num) {
              final out = output.toInt();
              onUsage(_inputTokens, out, _inputTokens + out);
            }
          }
          break;
        default:
          break;
      }
    } catch (_) {
      // 忽略无法解析的块
    }
  }
}
