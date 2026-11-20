// v1.7.0 · A1 单元测试
// 覆盖两种协议适配器的请求体构造、SSE 帧解析（正文/思维链/用量）、
// 协议枚举映射、模型列表过滤、通用工具函数。
// 目标：协议层是 v1.6.0 引入、v1.7 前零覆盖的高风险区，用测试锁定行为防止回归。
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:agnes_chat/config/app_config.dart';
import 'package:agnes_chat/models/message.dart';
import 'package:agnes_chat/services/api_protocol.dart';
import 'package:agnes_chat/services/anthropic_adapter.dart';
import 'package:agnes_chat/services/openai_adapter.dart';

void main() {
  group('协议枚举与工具函数', () {
    test('protocolFromStorage：未知值回退 openai，保证旧配置平滑迁移', () {
      expect(protocolFromStorage('anthropic'), ApiProtocol.anthropic);
      expect(protocolFromStorage('openai'), ApiProtocol.openai);
      expect(protocolFromStorage(null), ApiProtocol.openai);
      expect(protocolFromStorage('whatever'), ApiProtocol.openai);
    });

    test('ApiProtocolX 展示名与存储值', () {
      expect(ApiProtocol.openai.label, 'OpenAI 兼容');
      expect(ApiProtocol.anthropic.label, 'Anthropic 兼容');
      expect(ApiProtocol.anthropic.storeValue, 'anthropic');
    });

    test('formatHttpError 提取 error.message 并截断', () {
      expect(
        formatHttpError(401, '{"error":{"message":"Invalid key"}}'),
        'HTTP 401：Invalid key',
      );
      expect(formatHttpError(400, 'plain text'), 'HTTP 400：plain text');
      final long = '{"error":{"message":"${'x' * 300}"}}';
      expect(formatHttpError(500, long).length, lessThanOrEqualTo(200 + 9));
    });

    test('parseModelsJson 过滤非文本模型', () {
      final json = {
        'data': [
          {'id': 'gpt-4o'},
          {'id': 'dall-e-3-image'}, // 含 image 关键词
          {'id': 'whisper-1'},
          {'id': 'text-embedding-3'},
          {'id': 'qwen-video'}, // 含 video 关键词
          {'id': 'deepseek-chat'},
          {'id': 'gpt-4o'}, // 重复
        ],
      };
      expect(parseModelsJson(json), ['gpt-4o', 'deepseek-chat']);
    });

    test('decodeResponseBody 强制 UTF-8，中文不乱码', () {
      final bytes = utf8.encode('你好世界');
      final resp = http.Response.bytes(bytes, 200);
      expect(decodeResponseBody(resp), '你好世界');
    });
  });

  group('OpenAiAdapter', () {
    final adapter = OpenAiAdapter();

    test('headers 使用 Bearer 鉴权', () {
      final h = adapter.headers('sk-123');
      expect(h['Authorization'], 'Bearer sk-123');
      expect(h['Content-Type'], 'application/json');
    });

    test('chatUrl 兼容带/不带 /v1、已是完整端点', () {
      expect(
        adapter.chatUrl('https://api.x.com/v1'),
        'https://api.x.com/v1${AppConfig.chatPath}',
      );
      expect(
        adapter.chatUrl('https://api.x.com/v1/'),
        'https://api.x.com/v1${AppConfig.chatPath}',
      );
      expect(
        adapter.chatUrl('https://api.x.com/v1/chat/completions'),
        'https://api.x.com/v1/chat/completions',
      );
    });

    test('chatBody：system 在 messages 首位，enable_thinking 正确下发', () {
      final body = adapter.chatBody(
        model: 'm1',
        systemPrompt: 'sys',
        history: [
          ChatMessage(role: 'user', content: '你好'),
          ChatMessage(role: 'assistant', content: '在'),
        ],
        enableThinking: true,
        stream: true,
      );
      expect(body['model'], 'm1');
      final messages = body['messages'] as List<dynamic>;
      expect((messages[0] as Map)['role'], 'system');
      expect((messages[0] as Map)['content'], 'sys');
      expect((messages[1] as Map)['content'], '你好');
      expect(body['stream'], true);
      expect((body['chat_template_kwargs'] as Map)['enable_thinking'], true);
    });

    test('withUsageOption / degradeBody：加与降级去掉 stream_options', () {
      final body = adapter.withUsageOption({'model': 'm'});
      expect((body['stream_options'] as Map)['include_usage'], true);
      expect(adapter.degradeBody(body)!.containsKey('stream_options'), false);
      // 没有 stream_options 时无可降级
      expect(adapter.degradeBody({'model': 'm'}), isNull);
    });

    test('extractReplyText 取 choices[0].message.content', () {
      final json =
          jsonDecode('{"choices":[{"message":{"content":"  答案  "}}]}')
              as Map<String, dynamic>;
      expect(adapter.extractReplyText(json), '答案');
    });

    group('handleSseLine', () {
      test('解析正文 delta', () {
        final deltas = <String>[];
        adapter.handleSseLine(
          'data: ${jsonEncode({
            'choices': [
              {
                'delta': {'content': '你'},
              },
            ],
          })}',
          deltas.add,
          null,
        );
        expect(deltas, ['你']);
      });

      test('解析 reasoning_content 思维链，与正文分开', () {
        final deltas = <String>[];
        final reasoning = <String>[];
        adapter.handleSseLine(
          'data: ${jsonEncode({
            'choices': [
              {
                'delta': {'reasoning_content': '思考中'},
              },
            ],
          })}',
          deltas.add,
          null,
          reasoning.add,
        );
        expect(reasoning, ['思考中']);
        expect(deltas, isEmpty);
      });

      test('解析 usage 尾帧（choices 为空但带 usage）', () {
        int? p, c, t;
        adapter.handleSseLine(
          'data: ${jsonEncode({
            'choices': [],
            'usage': {'prompt_tokens': 10, 'completion_tokens': 5, 'total_tokens': 15},
          })}',
          (_) {},
          (a, b, d) {
            p = a;
            c = b;
            t = d;
          },
        );
        expect([p, c, t], [10, 5, 15]);
      });

      test('兼容 input_tokens/output_tokens 命名与缺失 total', () {
        int? p, c, t;
        adapter.handleSseLine(
          'data: ${jsonEncode({
            'choices': [],
            'usage': {'input_tokens': 7, 'output_tokens': 3},
          })}',
          (_) {},
          (a, b, d) {
            p = a;
            c = b;
            t = d;
          },
        );
        expect([p, c, t], [7, 3, 10]);
      });

      test('忽略 [DONE]、心跳、非 data 行、非法 JSON', () {
        final deltas = <String>[];
        for (final line in [
          'data: [DONE]',
          'data: ',
          ': ping',
          'data: {bad json',
          'event: message',
        ]) {
          adapter.handleSseLine(line, deltas.add, null);
        }
        expect(deltas, isEmpty);
      });
    });
  });

  group('AnthropicAdapter', () {
    final adapter = AnthropicAdapter();

    test('headers 使用 x-api-key + anthropic-version', () {
      final h = adapter.headers('sk-ant-1');
      expect(h['x-api-key'], 'sk-ant-1');
      expect(h['anthropic-version'], '2023-06-01');
      expect(h.containsKey('Authorization'), false);
    });

    test('chatUrl 拼接 /v1/messages，兼容已带 /v1', () {
      expect(
        adapter.chatUrl('https://api.anthropic.com'),
        'https://api.anthropic.com/v1/messages',
      );
      expect(
        adapter.chatUrl('https://api.anthropic.com/v1'),
        'https://api.anthropic.com/v1/messages',
      );
      expect(
        adapter.chatUrl('https://api.anthropic.com/v1/messages'),
        'https://api.anthropic.com/v1/messages',
      );
    });

    test('chatBody：system 独立字段，连续同角色消息自动合并', () {
      final body = adapter.chatBody(
        model: 'claude',
        systemPrompt: '你是助手',
        history: [
          ChatMessage(role: 'user', content: '第一句'),
          ChatMessage(role: 'user', content: '第二句'),
          ChatMessage(role: 'assistant', content: '回答'),
        ],
        enableThinking: false,
        stream: true,
      );
      expect(body['system'], '你是助手');
      final messages = body['messages'] as List<dynamic>;
      expect(messages.length, 2); // 两条 user 合并为一条
      expect((messages[0] as Map)['content'], '第一句\n第二句');
      expect(body.containsKey('thinking'), false);
      expect(body['max_tokens'], AppConfig.anthropicMaxTokens);
    });

    test('chatBody：开启思考时 budget 与 max_tokens 正确', () {
      final body = adapter.chatBody(
        model: 'claude',
        systemPrompt: '',
        history: [ChatMessage(role: 'user', content: 'hi')],
        enableThinking: true,
        stream: true,
      );
      final thinking = body['thinking'] as Map<String, dynamic>;
      expect(thinking['type'], 'enabled');
      expect(thinking['budget_tokens'], AppConfig.anthropicThinkingBudget);
      expect(
        body['max_tokens'],
        AppConfig.anthropicMaxTokens + AppConfig.anthropicThinkingBudget,
      );
      expect(body.containsKey('system'), false); // 空 system 不下发
    });

    test('extractReplyText 取 content 数组中 type=text 的块', () {
      final json =
          jsonDecode(
                '{"content":[{"type":"text","text":"你好"},{"type":"text","text":"世界"}]}',
              )
              as Map<String, dynamic>;
      expect(adapter.extractReplyText(json), '你好世界');
    });

    test('parseModels 取 data[].id 且去重', () {
      final models = adapter.parseModels({
        'data': [
          {'id': 'claude-3'},
          {'id': 'claude-3'},
        ],
      });
      expect(models, ['claude-3']);
    });

    group('handleSseLine（事件制）', () {
      test('text_delta 正文 + thinking_delta 思维链分开回调', () {
        final deltas = <String>[];
        final reasoning = <String>[];
        adapter.handleSseLine(
          'data: ${jsonEncode({
            'type': 'content_block_delta',
            'delta': {'type': 'text_delta', 'text': '正文'},
          })}',
          deltas.add,
          null,
          reasoning.add,
        );
        adapter.handleSseLine(
          'data: ${jsonEncode({
            'type': 'content_block_delta',
            'delta': {'type': 'thinking_delta', 'thinking': '推理'},
          })}',
          deltas.add,
          null,
          reasoning.add,
        );
        expect(deltas, ['正文']);
        expect(reasoning, ['推理']);
      });

      test('message_start 的 input + message_delta 的 output 合并为用量', () {
        int? p, c, t;
        adapter.handleSseLine(
          'data: ${jsonEncode({
            'type': 'message_start',
            'message': {
              'usage': {'input_tokens': 20},
            },
          })}',
          (_) {},
          (a, b, d) {
            p = a;
            c = b;
            t = d;
          },
        );
        adapter.handleSseLine(
          'data: ${jsonEncode({
            'type': 'message_delta',
            'usage': {'output_tokens': 8},
          })}',
          (_) {},
          (a, b, d) {
            p = a;
            c = b;
            t = d;
          },
        );
        expect([p, c, t], [20, 8, 28]);
      });

      test('忽略未知事件、非 data 行、非法 JSON', () {
        final deltas = <String>[];
        for (final line in [
          'data: ${jsonEncode({'type': 'message_stop'})}',
          'data: ${jsonEncode({'type': 'content_block_start'})}',
          'event: ping',
          'data: {bad',
        ]) {
          adapter.handleSseLine(line, deltas.add, null);
        }
        expect(deltas, isEmpty);
      });
    });
  });
}
