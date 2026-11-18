import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'config/app_config.dart';
import 'providers/chat_provider.dart';
import 'theme/app_theme.dart';
import 'pages/chat_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 初始化全局状态（读取本地 API 配置与历史对话）
  final provider = ChatProvider();
  await provider.init();
  runApp(
    ChangeNotifierProvider.value(
      value: provider,
      child: const AgnesApp(),
    ),
  );
}

/// 应用根组件：根据保存的主题模式切换浅色/深色/跟随系统
class AgnesApp extends StatelessWidget {
  const AgnesApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeMode = context.select<ChatProvider, int>((p) => p.themeMode);
    final oledDark = context.select<ChatProvider, bool>((p) => p.oledDark);
    // v1.5：同步全局静态开关，供输入区等组件读取
    AppTheme.oledDark = oledDark;
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(oled: oledDark),
      themeMode: _toThemeMode(themeMode),
      // V1.4.1：中文本地化——长按/选中文本弹出的"全选/复制/粘贴"菜单显示中文
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const ChatPage(),
    );
  }

  ThemeMode _toThemeMode(int mode) {
    switch (mode) {
      case 1:
        return ThemeMode.light;
      case 2:
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}
