import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/message.dart';
import '../models/search.dart';
import 'anthropic_adapter.dart';
import 'api_protocol.dart';
import 'openai_adapter.dart';

/// 网络层门面（v1.6.0：按协议分发到 OpenAI 兼容 / Anthropic 兼容适配器）
/// 对外接口与 v1.5.1 一致，仅各方法新增 [protocol] 参数。
/// 联网搜索为独立 HTTP 接口，与协议无关。
class ApiService {
  /// 主对话请求客户端（受"停止生成"控制）
  http.Client? _client;
  bool _cancelled = false;

  /// 取消当前主对话请求（"停止生成"按钮触发）
  void cancel() {
    _cancelled = true;
    _client?.close();
  }

  /// 按协议创建适配器
  ProtocolAdapter _adapterOf(String protocol) =>
      protocolFromStorage(protocol) == ApiProtocol.anthropic
      ? AnthropicAdapter()
      : OpenAiAdapter();

  /// 测试连接：发送一条极简消息，验证 API 配置是否可用
  /// 返回 null 表示成功，否则返回错误信息
  Future<String?> testConnection({
    required String baseUrl,
    required String apiKey,
    required String model,
    required String protocol,
  }) async {
    final adapter = _adapterOf(protocol);
    try {
      final response = await http
          .post(
            Uri.parse(adapter.chatUrl(baseUrl)),
            headers: adapter.headers(apiKey),
            body: jsonEncode(
              adapter.simpleBody(
                model: model,
                system: '',
                user: 'hi',
                maxTokens: 5,
              ),
            ),
          )
          .timeout(const Duration(seconds: 25));

      if (response.statusCode == 200) return null;
      return formatHttpError(response.statusCode, decodeResponseBody(response));
    } catch (e) {
      return '连接失败：$e';
    }
  }

  /// 拉取当前 API 账户可用的模型列表；失败时抛出错误由上层回退
  Future<List<String>> fetchModels({
    required String baseUrl,
    required String apiKey,
    required String protocol,
  }) async {
    final adapter = _adapterOf(protocol);
    final response = await http
        .get(
          Uri.parse(adapter.modelsUrl(baseUrl)),
          headers: adapter.headers(apiKey),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw formatHttpError(response.statusCode, decodeResponseBody(response));
    }
    final json =
        jsonDecode(decodeResponseBody(response)) as Map<String, dynamic>;
    return adapter.parseModels(json);
  }

  /// 后台自动命名：根据首轮对话内容生成简短标题（非流式，独立客户端）
  Future<String?> generateTitle({
    required String baseUrl,
    required String apiKey,
    required String model,
    required List<ChatMessage> firstRound,
    required String protocol,
  }) async {
    final adapter = _adapterOf(protocol);
    final client = http.Client();
    try {
      final context = firstRound
          .take(2)
          .map((m) {
            return '${m.role}: ${m.content}';
          })
          .join('\n');
      final response = await client
          .post(
            Uri.parse(adapter.chatUrl(baseUrl)),
            headers: adapter.headers(apiKey),
            body: jsonEncode(
              adapter.simpleBody(
                model: model,
                system: AppConfig.titlePrompt,
                user: context,
                maxTokens: 100,
              ),
            ),
          )
          .timeout(const Duration(seconds: 25));
      if (response.statusCode != 200) return null;
      final json =
          jsonDecode(decodeResponseBody(response)) as Map<String, dynamic>;
      var title = adapter.extractReplyText(json);
      // 剥离内嵌 think 标签（部分服务在正文里带思维链）
      final thinkEnd = title.lastIndexOf('</think>');
      if (thinkEnd != -1) {
        title = title.substring(thinkEnd + '</think>'.length).trim();
      }
      final trimChars = <String>[
        ' ',
        '\t',
        '\r',
        '\n',
        '"',
        "'",
        '`',
        '，',
        '。',
        '！',
        '？',
        '、',
        ':',
        '：',
      ];
      while (title.isNotEmpty && trimChars.contains(title[0])) {
        title = title.substring(1);
      }
      while (title.isNotEmpty && trimChars.contains(title[title.length - 1])) {
        title = title.substring(0, title.length - 1);
      }
      if (title.isEmpty) return null;
      if (title.length > 16) title = title.substring(0, 16);
      return title;
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  // ==================== V1.3 联网搜索 ====================

  /// 判断是否需要联网搜索：让当前对话模型输出 {"need":bool,"query":string}
  /// 用独立客户端，失败时安全降级为"不搜索"（不阻断对话）
  Future<SearchDecision> judgeSearch({
    required String baseUrl,
    required String apiKey,
    required String model,
    required String userQuestion,
    required String protocol,
  }) async {
    final adapter = _adapterOf(protocol);
    final client = http.Client();
    try {
      final response = await client
          .post(
            Uri.parse(adapter.chatUrl(baseUrl)),
            headers: adapter.headers(apiKey),
            body: jsonEncode(
              adapter.simpleBody(
                model: model,
                system: AppConfig.searchJudgePrompt,
                user: userQuestion,
                maxTokens: 120,
                temperature: 0,
              ),
            ),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        return SearchDecision(needSearch: false, query: userQuestion);
      }
      final json =
          jsonDecode(decodeResponseBody(response)) as Map<String, dynamic>;
      var text = adapter.extractReplyText(json);
      // 剥离 think 标签
      final thinkEnd = text.lastIndexOf('</think>');
      if (thinkEnd != -1) {
        text = text.substring(thinkEnd + '</think>'.length).trim();
      }
      // 提取 JSON 主体（兼容 ```json 包裹或前后有说明文字）
      final start = text.indexOf('{');
      final end = text.lastIndexOf('}');
      if (start != -1 && end > start) {
        final candidate = text.substring(start, end + 1);
        final obj = jsonDecode(candidate) as Map<String, dynamic>;
        bool need = false;
        final rawNeed = obj['need'] ?? obj['need_search'] ?? obj['needSearch'];
        if (rawNeed is bool) {
          need = rawNeed;
        } else if (rawNeed is String) {
          final lower = rawNeed.toLowerCase();
          need = lower.contains('true') || rawNeed.contains('需要');
        } else if (rawNeed is num) {
          need = rawNeed == 1;
        }
        String query =
            (obj['query'] ?? obj['keyword'] ?? obj['search_query'] ?? '')
                .toString()
                .trim();
        if (query.isEmpty) query = userQuestion;
        return SearchDecision(needSearch: need, query: query);
      }
    } catch (_) {
      // 解析失败安全降级
    } finally {
      client.close();
    }
    return SearchDecision(needSearch: false, query: userQuestion);
  }

  /// 执行联网搜索：POST 搜索接口，兼容 DeepSeek Search API 与自建服务
  /// 约定返回 results[].title/url/snippet（也兼容 summary/content/description）
  Future<List<SearchResult>> webSearch({
    required String searchUrl,
    required String apiKey,
    required String query,
    int count = 5,
  }) async {
    final client = http.Client();
    try {
      var url = searchUrl.trim().replaceAll(RegExp(r'/+$'), '');
      if (url.isEmpty) url = AppConfig.deepseekSearchUrl;
      final response = await client
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode({
              'query': query,
              'count': count,
              'need_content': true,
            }),
          )
          .timeout(const Duration(seconds: 25));
      if (response.statusCode != 200) {
        throw formatHttpError(
          response.statusCode,
          decodeResponseBody(response),
        );
      }
      final json =
          jsonDecode(decodeResponseBody(response)) as Map<String, dynamic>;
      final rawList = json['results'] ?? json['data'] ?? [];
      final list = rawList is List<dynamic> ? rawList : <dynamic>[];
      final results = <SearchResult>[];
      for (final item in list) {
        if (item is! Map<String, dynamic>) continue;
        final title = (item['title'] ?? '').toString().trim();
        final urlStr = (item['url'] ?? item['link'] ?? '').toString().trim();
        final snippet =
            (item['snippet'] ??
                    item['summary'] ??
                    item['content'] ??
                    item['description'] ??
                    '')
                .toString()
                .trim();
        if (title.isEmpty && snippet.isEmpty) continue;
        results.add(SearchResult(title: title, url: urlStr, snippet: snippet));
        if (results.length >= count) break;
      }
      return results;
    } finally {
      client.close();
    }
  }

  /// 检查搜索配置是否可用：发一次真实搜索请求，返回 null 表示成功
  Future<String?> checkSearchConfig({
    required String searchUrl,
    required String apiKey,
  }) async {
    try {
      await webSearch(
        searchUrl: searchUrl,
        apiKey: apiKey,
        query: '今天',
        count: 1,
      ).timeout(const Duration(seconds: 30));
      return null;
    } catch (e) {
      return e.toString().replaceAll('Exception: ', '');
    }
  }

  /// 把搜索结果格式化为可注入 system 的文本
  String formatSearchContext(List<SearchResult> results) {
    if (results.isEmpty) return '';
    final buffer = StringBuffer(
      '以下是联网搜索到的实时信息，请优先参考这些信息回答用户问题'
      '（注意甄别真伪，并在合适时说明信息来源）：\n',
    );
    for (var i = 0; i < results.length; i++) {
      final r = results[i];
      buffer.writeln('[${i + 1}] ${r.title}');
      if (r.url.isNotEmpty) buffer.writeln('    链接：${r.url}');
      if (r.snippet.isNotEmpty) buffer.writeln('    摘要：${r.snippet}');
    }
    return buffer.toString();
  }

  /// 流式对话：逐块返回 AI 生成的内容（按协议分发到对应适配器）
  /// [protocol] 为 'openai' 或 'anthropic'（存储值）
  void streamChat({
    required String baseUrl,
    required String apiKey,
    required String model,
    required String systemPrompt,
    required List<ChatMessage> history,
    bool enableThinking = false,
    required void Function(String delta) onDelta,
    required void Function() onDone,
    required void Function(String error) onError,
    void Function(int prompt, int completion, int total)? onUsage,
    void Function(String reasoning)? onReasoning,
    required String protocol,
  }) {
    _cancelled = false;
    _client = http.Client();
    final adapter = _adapterOf(protocol);

    // 基础请求体（协议适配器负责字段差异：system 位置、鉴权、thinking 映射等）
    final baseBody = adapter.chatBody(
      model: model,
      systemPrompt: systemPrompt,
      history: history,
      enableThinking: enableThinking,
      stream: true,
    );
    final withUsage = adapter.withUsageOption(baseBody);

    // 局部函数：发起一次流式请求；若服务端返回 400 且存在降级体（如去掉
    // stream_options），自动降级重试，保证主对话可用
    void start(Map<String, dynamic> body, {bool allowFallback = true}) {
      final request = http.Request('POST', Uri.parse(adapter.chatUrl(baseUrl)))
        ..headers.addAll(adapter.headers(apiKey))
        ..body = jsonEncode(body);

      _client!
          .send(request)
          .then((response) {
            if (allowFallback && response.statusCode == 400) {
              final degraded = adapter.degradeBody(body);
              if (degraded != null) {
                response.stream
                    .drain<void>()
                    .then((_) {
                      if (!_cancelled) start(degraded, allowFallback: false);
                    })
                    .catchError((_) {
                      if (!_cancelled) start(degraded, allowFallback: false);
                    });
                return;
              }
            }
            if (response.statusCode != 200) {
              response.stream.bytesToString().then((body) {
                if (!_cancelled) {
                  onError(formatHttpError(response.statusCode, body));
                }
              });
              return;
            }
            final lineStream = response.stream
                .transform(utf8.decoder)
                .transform(const LineSplitter());
            lineStream.listen(
              (line) {
                if (_cancelled) return;
                adapter.handleSseLine(line, onDelta, onUsage, onReasoning);
              },
              onDone: () {
                if (!_cancelled) onDone();
              },
              onError: (e) {
                if (!_cancelled) onError('流式读取失败：$e');
              },
            );
          })
          .catchError((e) {
            if (!_cancelled) onError('请求失败：$e');
          });
    }

    start(withUsage);
  }

  void dispose() {
    _client?.close();
  }
}
