import 'package:agnes_chat/models/message.dart';
import 'package:agnes_chat/widgets/message_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 回归测试：flutter_markdown 0.7.x 在自定义 pre 构建器下，若代码卡片
/// 在 visitElementAfter 中渲染（visitText 返回 null），会残留内部状态，
/// 含代码块的回复解析结束时触发 _inlines.isEmpty 断言崩溃。
/// 修复后代码卡片在 visitText 中渲染。
void main() {
  Future<void> pumpBubble(WidgetTester tester, bool dark) async {
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      MaterialApp(
        theme: dark ? ThemeData.dark() : ThemeData.light(),
        home: Scaffold(
          body: ListView(
            children: [
              MessageBubble(
                message: ChatMessage(
                  role: 'assistant',
                  content:
                      '实现如下：\n\n'
                      '```dart\nfinal provider = context.read<ChatProvider>();\n```\n\n'
                      '调用后即可读取状态。\n',
                  thinkingEnabled: true,
                ),
                isDark: dark,
                isGenerating: false,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('含代码块的回复在浅色模式正常渲染', (tester) async {
    await pumpBubble(tester, false);
    expect(find.text('DART'), findsOneWidget);
    expect(find.text('调用后即可读取状态。'), findsOneWidget);
    expect(find.text('复制'), findsOneWidget);
  });

  testWidgets('含代码块的回复在深色模式正常渲染', (tester) async {
    await pumpBubble(tester, true);
    expect(find.text('DART'), findsOneWidget);
  });
}
