// v1.8.3：输入框完全重绘后的渲染回归测试
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agnes_chat/widgets/chat_input.dart';

void main() {
  Widget buildInput({
    required TextEditingController controller,
    bool isGenerating = false,
    bool searchAvailable = true,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: ChatInput(
            controller: controller,
            isGenerating: isGenerating,
            onSend: () {},
            onStop: () {},
            isDark: false,
            model: 'agnes-2.5-flash',
            thinking: false,
            onModelTap: () {},
            onThinkingChanged: (_) {},
            configured: true,
            searchAvailable: searchAvailable,
            searching: false,
            onSearchingChanged: (_) {},
          ),
        ),
      ),
    );
  }

  testWidgets('窄屏下输入框渲染无溢出，模型/思考/搜索/发送按钮齐全', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final controller = TextEditingController();
    await tester.pumpWidget(buildInput(controller: controller));

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('agnes-2.5-flash'), findsOneWidget);
    expect(find.text('思考：关'), findsOneWidget);
    expect(find.text('搜索：关'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);

    // 输入一行文字后不应出现渲染溢出
    await tester.enterText(find.byType(TextField), '你好，这是一条较长的测试消息');
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('生成状态下显示停止按钮而非发送按钮', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      buildInput(controller: controller, isGenerating: true),
    );

    expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward_rounded), findsNothing);
  });

  testWidgets('未配置 API 时模型按钮显示引导文案', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatInput(
            controller: controller,
            isGenerating: false,
            onSend: () {},
            onStop: () {},
            isDark: true,
            model: '',
            thinking: true,
            onModelTap: () {},
            onThinkingChanged: (_) {},
            configured: false,
            searchAvailable: false,
            searching: false,
            onSearchingChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('还没有配置模型'), findsOneWidget);
    expect(find.text('思考：开'), findsOneWidget);
    // 搜索未配置通过时不显示搜索按钮
    expect(find.textContaining('搜索：'), findsNothing);
  });
}
