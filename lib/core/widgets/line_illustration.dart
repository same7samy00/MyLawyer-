import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// رسمة التطبيق الموحدة: خط من حافة الشاشة للحافة التانية، وكارت صغير في النص فيه أيقونة
class LineIllustration extends StatelessWidget {
  final IconData icon;
  final double height;

  const LineIllustration({super.key, required this.icon, this.height = 96});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          const Positioned.fill(child: EdgeLine()),
          IllustrationBadge(icon: icon, size: height * 0.62),
        ],
      ),
    );
  }
}

/// الكارت المائل لوحده، للأماكن الضيقة زي صفوف القوائم والبانرات
class IllustrationBadge extends StatelessWidget {
  final IconData icon;
  final double size;

  const IllustrationBadge({super.key, required this.icon, this.size = 56});

  @override
  Widget build(BuildContext context) {
    final card = BorderRadius.circular(size * 0.2);
    return SizedBox(
      width: size * 1.25,
      height: size * 1.15,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: 10 * math.pi / 180,
            child: Container(
              width: size * 0.84,
              height: size,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: card,
                border: Border.all(color: AppColors.dark, width: 1.2),
              ),
            ),
          ),
          Transform.rotate(
            angle: -8 * math.pi / 180,
            child: Container(
              width: size * 1.1,
              height: size * 0.76,
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: card),
              child: Icon(icon, color: Colors.white, size: size * 0.42),
            ),
          ),
        ],
      ),
    );
  }
}

/// الخط لوحده، وبيتمد لعرض الشاشة كله مهما كان هامش المكان اللي هو فيه
class EdgeLine extends StatelessWidget {
  const EdgeLine({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: OverflowBox(
        minWidth: MediaQuery.sizeOf(context).width,
        maxWidth: MediaQuery.sizeOf(context).width,
        child: const SizedBox.expand(child: CustomPaint(painter: _EdgeLinePainter())),
      ),
    );
  }
}

class _EdgeLinePainter extends CustomPainter {
  const _EdgeLinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    double x(double value) => value / 360 * size.width;
    double y(double value) => value / 100 * size.height;

    final line = Path()
      ..moveTo(0, y(62))
      ..cubicTo(x(30), y(92), x(62), y(96), x(84), y(78))
      ..cubicTo(x(104), y(62), x(96), y(40), x(82), y(46))
      ..cubicTo(x(68), y(52), x(78), y(84), x(116), y(88))
      ..cubicTo(x(166), y(93), x(212), y(96), x(250), y(78))
      ..cubicTo(x(288), y(60), x(322), y(66), x(360), y(94));
    canvas.drawPath(
      line,
      Paint()
        ..color = AppColors.dark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..strokeCap = StrokeCap.round,
    );

    final fill = Paint()..color = AppColors.dark;
    _sparkle(canvas, Offset(x(272), y(20)), size.height * 0.09, fill);
    _sparkle(canvas, Offset(x(296), y(38)), size.height * 0.05, fill);
    _sparkle(canvas, Offset(x(90), y(18)), size.height * 0.05, fill);
  }

  void _sparkle(Canvas canvas, Offset center, double radius, Paint paint) {
    final inner = radius * 0.22;
    canvas.drawPath(
      Path()
        ..moveTo(center.dx, center.dy - radius)
        ..lineTo(center.dx + inner, center.dy - inner)
        ..lineTo(center.dx + radius, center.dy)
        ..lineTo(center.dx + inner, center.dy + inner)
        ..lineTo(center.dx, center.dy + radius)
        ..lineTo(center.dx - inner, center.dy + inner)
        ..lineTo(center.dx - radius, center.dy)
        ..lineTo(center.dx - inner, center.dy - inner)
        ..close(),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _EdgeLinePainter oldDelegate) => false;
}

/// علامة ملف Google على الأزرار
class GoogleMark extends StatelessWidget {
  final double size;

  const GoogleMark({super.key, this.size = 18});

  @override
  Widget build(BuildContext context) {
    return Text(
      'G',
      style: TextStyle(fontSize: size, height: 1, fontWeight: FontWeight.w900, color: AppColors.primary),
    );
  }
}
