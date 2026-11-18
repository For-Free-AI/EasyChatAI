import 'package:flutter/material.dart';

/// UI 主题 v1.5：Material 3 现代化风格（DeepSeek 蓝为种子色）
class AppTheme {
  // 主色调（DeepSeek 蓝）
  static const Color primary = Color(0xFF4D6BFE);

  /// OLED 纯黑深色模式开关（由设置页控制，main.dart 同步到 dark(oled:)）
  static bool oledDark = false;

  static const Color _darkBg = Color(0xFF1E1E1E);
  static const Color _oledBg = Color(0xFF000000);

  /// 深色模式大背景色（跟随 OLED 开关）
  static Color darkScaffold(bool oled) => oled ? _oledBg : _darkBg;

  /// 深色模式输入区/卡片背景色
  static Color darkCard(bool oled) => oled ? const Color(0xFF121212) : const Color(0xFF252525);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme.copyWith(primary: primary),
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF1A1A1A),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Color(0xFF1A1A1A)),
        titleTextStyle: TextStyle(
          color: Color(0xFF1A1A1A),
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      // 按钮：胶囊形大圆角
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary),
          shape: const StadiumBorder(),
        ),
      ),
      // 对话框与底部面板：大圆角
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        backgroundColor: Colors.white,
      ),
    );
  }

  static ThemeData dark({bool oled = false}) {
    final bg = darkScaffold(oled);
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme.copyWith(primary: primary, surface: bg),
      scaffoldBackgroundColor: bg,
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: const Color(0xFFECECEC),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Color(0xFFECECEC)),
        titleTextStyle: const TextStyle(
          color: Color(0xFFECECEC),
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary),
          shape: const StadiumBorder(),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: darkCard(oled),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        backgroundColor: darkCard(oled),
      ),
    );
  }
}
