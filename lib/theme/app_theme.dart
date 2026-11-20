import 'package:flutter/material.dart';

/// UI 主题 v1.8.2：在 v1.8.1 基础上做保守美化——
/// 布局与结构不变，统一圆角规范、输入框观感、卡片阴影与列表按压态。
/// 主色调仍为 DeepSeek 蓝。
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
  static Color darkCard(bool oled) =>
      oled ? const Color(0xFF121212) : const Color(0xFF252525);

  /// v1.8.2：浅色卡片描边（比 outline 更柔和）
  static const Color _lightCardBorder = Color(0xFFE9ECF5);

  /// v1.8.2：浅色输入框底色
  static const Color _lightFieldBg = Color(0xFFF6F7FB);

  /// v1.8.2：深色输入框底色（OLED 下更深一档）
  static Color darkFieldBg(bool oled) =>
      oled ? const Color(0xFF1A1A1A) : const Color(0xFF2B2B2B);

  /// v1.8.2：深色卡片/控件描边
  static Color darkBorder(bool oled) => oled
      ? Colors.white.withValues(alpha: 0.10)
      : Colors.white.withValues(alpha: 0.08);

  /// v1.8.2：统一圆角规范
  static const double radiusCard = 16;
  static const double radiusPanel = 24;
  static const double radiusField = 14;

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme.copyWith(primary: primary),
      scaffoldBackgroundColor: Colors.white,
      // v1.7.0 B1：文本选择醒目配色（选区高亮 / 手柄 / 光标统一主色）
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: primary,
        selectionColor: primary.withValues(alpha: 0.28),
        selectionHandleColor: primary,
      ),
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
      // v1.8.2：卡片统一为描边式 + 大圆角，弱化投影
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: const BorderSide(color: _lightCardBorder),
        ),
        margin: EdgeInsets.zero,
      ),
      // v1.8.2：输入框统一底色 + 圆角描边
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _lightFieldBg,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusField),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusField),
          borderSide: const BorderSide(color: _lightCardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusField),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
      ),
      // v1.8.2：列表项圆角按压态
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        iconColor: const Color(0xFF5A6072),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
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
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: const BorderSide(color: _lightCardBorder),
        backgroundColor: _lightFieldBg,
        selectedColor: primary.withValues(alpha: 0.14),
        showCheckmark: false,
        labelStyle: const TextStyle(
          color: Color(0xFF1A1A1A),
          fontWeight: FontWeight.w500,
        ),
      ),
      // 对话框与底部面板：统一 24 圆角
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusPanel),
        ),
        backgroundColor: Colors.white,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(radiusPanel),
          ),
        ),
        backgroundColor: Colors.white,
      ),
      // v1.8.2：浮动圆角 SnackBar、柔和分割线
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusField),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: _lightCardBorder,
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: primary),
    );
  }

  static ThemeData dark({bool oled = false}) {
    final bg = darkScaffold(oled);
    final card = darkCard(oled);
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme.copyWith(primary: primary, surface: bg),
      scaffoldBackgroundColor: bg,
      // v1.7.0 B1：深色下选择配色（高亮稍提亮以便看清）
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: primary,
        selectionColor: primary.withValues(alpha: 0.38),
        selectionHandleColor: primary,
      ),
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
      // v1.8.2：深色卡片描边式统一
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: BorderSide(color: darkBorder(oled)),
        ),
        margin: EdgeInsets.zero,
      ),
      // v1.8.2：深色输入框统一
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkFieldBg(oled),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.38)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusField),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusField),
          borderSide: BorderSide(color: darkBorder(oled)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusField),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        iconColor: const Color(0xFFA8AEC0),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
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
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide(color: darkBorder(oled)),
        backgroundColor: darkFieldBg(oled),
        selectedColor: primary.withValues(alpha: 0.22),
        showCheckmark: false,
        labelStyle: const TextStyle(
          color: Color(0xFFECECEC),
          fontWeight: FontWeight.w500,
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusPanel),
        ),
        backgroundColor: card,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(radiusPanel),
          ),
        ),
        backgroundColor: card,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusField),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: darkBorder(oled),
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: primary),
    );
  }
}
