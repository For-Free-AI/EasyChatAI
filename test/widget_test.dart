// 冒烟测试：验证数据模型与配置常量工作正常
import 'package:flutter_test/flutter_test.dart';

import 'package:agnes_chat/config/app_config.dart';
import 'package:agnes_chat/models/conversation.dart';
import 'package:agnes_chat/models/message.dart';

void main() {
  test('Agnes 预置配置正确', () {
    expect(AppConfig.agnesBaseUrl, contains('agnes-ai.com'));
    expect(AppConfig.agnesModel, 'agnes-2.5-flash');
    expect(AppConfig.presets.containsKey('Agnes（国际）'), true);
  });

  test('消息模型 JSON 往返', () {
    final msg = ChatMessage(role: 'user', content: '你好');
    final json = msg.toJson();
    final restored = ChatMessage.fromJson(json);
    expect(restored.role, 'user');
    expect(restored.content, '你好');
  });

  test('消息扩展字段（思维链/用量/搜索标记）JSON 往返不丢', () {
    final msg = ChatMessage(
      role: 'assistant',
      content: '答案',
      searched: true,
      promptTokens: 12,
      completionTokens: 34,
      totalTokens: 46,
      reasoning: '思考过程',
      reasoningSupported: true,
      thinkingEnabled: true,
    );
    final restored = ChatMessage.fromJson(msg.toJson());
    expect(restored.searched, true);
    expect(restored.promptTokens, 12);
    expect(restored.completionTokens, 34);
    expect(restored.totalTokens, 46);
    expect(restored.reasoning, '思考过程');
    expect(restored.reasoningSupported, true);
    expect(restored.thinkingEnabled, true);
  });

  test('会话 JSON 往返保留模型/开关/消息', () {
    final conv = Conversation(
      id: 'c1',
      title: '测试会话',
      model: 'deepseek-chat',
      enableThinking: true,
      enableSearch: true,
      namingTriggered: true,
      canRename: true,
      messages: [
        ChatMessage(role: 'user', content: 'hi'),
        ChatMessage(role: 'assistant', content: 'hello'),
      ],
    );
    final restored = Conversation.fromJson(conv.toJson());
    expect(restored.id, 'c1');
    expect(restored.title, '测试会话');
    expect(restored.model, 'deepseek-chat');
    expect(restored.enableThinking, true);
    expect(restored.enableSearch, true);
    expect(restored.namingTriggered, true);
    expect(restored.canRename, true);
    expect(restored.messages.length, 2);
    expect(restored.messages[1].content, 'hello');
  });

  test('会话兼容旧数据：缺失字段用默认值，canRename 按消息数推断', () {
    final restored = Conversation.fromJson({
      'id': 'old',
      'title': '老会话',
      'messages': [
        {'role': 'user', 'content': 'x'},
      ],
    });
    expect(restored.model, '');
    expect(restored.enableThinking, false);
    expect(restored.enableSearch, false);
    expect(restored.canRename, true); // 有消息 → 允许改名
  });
}
