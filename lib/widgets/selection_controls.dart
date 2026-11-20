import 'package:flutter/material.dart';

/// v1.7.0 · B1 选择体验精修
///
/// 继承 Material 默认手柄控件，只做两件事：
/// 1. 放大手柄「命中热区」——默认仅 22dp，手指很难精准按住；放大到 34dp 显著好拖。
/// 2. 醒目配色——手柄/选区高亮用主题主色，选中状态一眼可见。
///
/// 通过 main.dart 的 DefaultSelectionStyle.selectionControls 全局注入，
/// 对 SelectableText / MarkdownBody(selectable) 全部生效，无需逐处设置。
class BigHandleTextSelectionControls extends MaterialTextSelectionControls {
  /// 放大后的手柄尺寸（默认 22）。热区与绘制同尺寸，拖动更容易命中。
  static const double kBigHandleSize = 34.0;

  @override
  Size getHandleSize(double textLineHeight) =>
      const Size(kBigHandleSize, kBigHandleSize);

  @override
  Widget buildHandle(
    BuildContext context,
    TextSelectionHandleType type,
    double textHeight, [
    VoidCallback? onTap,
  ]) {
    final ThemeData theme = Theme.of(context);
    final Color handleColor =
        TextSelectionTheme.of(context).selectionHandleColor ??
        theme.colorScheme.primary;

    // 与 Material 默认同款「洋葱头」形状，但用放大尺寸绘制。
    final Widget handle = SizedBox.square(
      dimension: kBigHandleSize,
      child: CustomPaint(
        painter: _BigHandlePainter(color: handleColor),
        // translucent：扩大命中范围，手指落在手柄边缘也能拖动
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.translucent,
        ),
      ),
    );

    // 保持与 Material 一致的朝向：left 指向右上 / right 指向左上 / collapsed 指向正上
    return switch (type) {
      TextSelectionHandleType.left => Transform.rotate(
        angle: 3.14159265 / 2.0,
        child: handle,
      ),
      TextSelectionHandleType.right => handle,
      TextSelectionHandleType.collapsed => Transform.rotate(
        angle: 3.14159265 / 4.0,
        child: handle,
      ),
    };
  }

  @override
  Offset getHandleAnchor(TextSelectionHandleType type, double textLineHeight) {
    return switch (type) {
      TextSelectionHandleType.collapsed => const Offset(kBigHandleSize / 2, -4),
      TextSelectionHandleType.left => const Offset(kBigHandleSize, 0),
      TextSelectionHandleType.right => Offset.zero,
    };
  }
}

/// 放大版手柄绘制器：一个圆 + 左上象限矩形，合成水滴/洋葱头形状。
/// 逻辑与 Material _TextSelectionHandlePainter 一致，仅尺寸由外部 size 决定。
class _BigHandlePainter extends CustomPainter {
  _BigHandlePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final double radius = size.width / 2.0;
    final circle = Rect.fromCircle(
      center: Offset(radius, radius),
      radius: radius,
    );
    final point = Rect.fromLTWH(0.0, 0.0, radius, radius);
    final path = Path()
      ..addOval(circle)
      ..addRect(point);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_BigHandlePainter oldPainter) => color != oldPainter.color;
}
