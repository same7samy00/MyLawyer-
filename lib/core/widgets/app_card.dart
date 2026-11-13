import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'app_pressable.dart';

/// رسام الحدود المتقطعة المنحنية (Dashed Rounded Rectangle)
/// يوفر حدوداً رفيعة وهادئة وغير بارزة بأسلوب Minimal UI العصري
class DashedRRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dash;
  final double gap;
  final double borderRadius;

  const DashedRRectPainter({
    this.color = AppColors.dashedBorder,
    this.strokeWidth = 1.0,
    this.dash = 5.0,
    this.gap = 3.5,
    this.borderRadius = 7.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        strokeWidth / 2,
        strokeWidth / 2,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
      Radius.circular(borderRadius),
    );

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      double distance = 0.0;
      while (distance < metric.length) {
        final length = (distance + dash > metric.length) ? metric.length - distance : dash;
        final extractPath = metric.extractPath(distance, distance + length);
        canvas.drawPath(extractPath, paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant DashedRRectPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dash != dash ||
        oldDelegate.gap != gap ||
        oldDelegate.borderRadius != borderRadius;
  }
}

/// كارت موحد بأسلوب Minimal UI:
/// - يدعم الحدود المتقطعة (Dashed Border) الهادئة والرفيعة
/// - خلفية بيضاء نقية أو شفافة دون ظلال ثقيلة
/// - حواف مستديرة ناعمة ومتناسقة
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final Border? border;
  final bool isDashed;
  final double borderRadius;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16.0),
    this.margin,
    this.backgroundColor,
    this.border,
    this.isDashed = true, // مفعل افتراضياً للحدود المتقطعة الهادئة
    this.borderRadius = 7.0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBgColor = backgroundColor ?? Colors.white;

    Widget cardContent;

    if (isDashed && border == null) {
      cardContent = Container(
        margin: margin,
        child: CustomPaint(
          foregroundPainter: DashedRRectPainter(
            color: AppColors.dashedBorder,
            strokeWidth: 0.9,
            dash: 5.0,
            gap: 3.5,
            borderRadius: borderRadius,
          ),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: effectiveBgColor,
              borderRadius: BorderRadius.circular(borderRadius),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.025),
                  blurRadius: 8.0,
                  spreadRadius: 0,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: child,
          ),
        ),
      );
    } else {
      cardContent = Container(
        margin: margin,
        padding: padding,
        decoration: BoxDecoration(
          color: effectiveBgColor,
          borderRadius: BorderRadius.circular(borderRadius),
          border: border ?? Border.all(color: AppColors.cardBorder, width: 1.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.025),
              blurRadius: 8.0,
              spreadRadius: 0,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: child,
      );
    }

    if (onTap != null) {
      return AppPressable(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: cardContent,
        ),
      );
    }

    return cardContent;
  }
}

/// فاصل خطي متقطع (Dashed Divider) ناعم وأنيق للمحتوى
class DashedDivider extends StatelessWidget {
  final double height;
  final Color color;
  final double dash;
  final double gap;
  final double strokeWidth;

  const DashedDivider({
    super.key,
    this.height = 1.0,
    this.color = AppColors.dashedBorder,
    this.dash = 5.0,
    this.gap = 3.5,
    this.strokeWidth = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CustomPaint(
        size: Size(double.infinity, height),
        painter: _DashedLinePainter(
          color: color,
          dash: dash,
          gap: gap,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  final double dash;
  final double gap;
  final double strokeWidth;

  const _DashedLinePainter({
    required this.color,
    required this.dash,
    required this.gap,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, size.height / 2), Offset(startX + dash, size.height / 2), paint);
      startX += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) => false;
}
