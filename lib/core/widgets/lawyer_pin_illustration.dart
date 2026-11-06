import 'package:flutter/material.dart';

/// رسمة «محاميك حالاً» بالخطوط: محامي واقف لابس بدلة، وساند بإيده على دبوس خريطة
class LawyerPinIllustration extends StatelessWidget {
  final double size;
  final Color color;

  const LawyerPinIllustration({super.key, this.size = 72, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 1.1,
      child: CustomPaint(painter: _LawyerPinPainter(color)),
    );
  }
}

class _LawyerPinPainter extends CustomPainter {
  final Color color;

  const _LawyerPinPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.03
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = color;

    // الأرض
    canvas.drawLine(Offset(w * 0.06, h * 0.96), Offset(w * 0.94, h * 0.96), line);

    // دبوس الخريطة على اليمين
    final pinCenter = Offset(w * 0.74, h * 0.34);
    final pinRadius = w * 0.17;
    final pin = Path()
      ..moveTo(pinCenter.dx, h * 0.94)
      ..quadraticBezierTo(pinCenter.dx - pinRadius * 1.5, pinCenter.dy + pinRadius * 0.9, pinCenter.dx - pinRadius, pinCenter.dy)
      ..arcToPoint(Offset(pinCenter.dx + pinRadius, pinCenter.dy), radius: Radius.circular(pinRadius))
      ..quadraticBezierTo(pinCenter.dx + pinRadius * 1.5, pinCenter.dy + pinRadius * 0.9, pinCenter.dx, h * 0.94)
      ..close();
    canvas.drawPath(pin, line);
    canvas.drawCircle(pinCenter, pinRadius * 0.42, line);

    // الراس
    final head = Offset(w * 0.3, h * 0.2);
    canvas.drawCircle(head, w * 0.085, line);

    // الجاكيت
    final shoulderL = Offset(w * 0.16, h * 0.36);
    final shoulderR = Offset(w * 0.44, h * 0.36);
    final jacket = Path()
      ..moveTo(shoulderL.dx, shoulderL.dy)
      ..lineTo(shoulderR.dx, shoulderR.dy)
      ..lineTo(w * 0.42, h * 0.64)
      ..lineTo(w * 0.18, h * 0.64)
      ..close();
    canvas.drawPath(jacket, line);

    // الياقة والكرافتة
    canvas.drawLine(Offset(w * 0.25, shoulderL.dy), Offset(w * 0.3, h * 0.47), line);
    canvas.drawLine(Offset(w * 0.35, shoulderR.dy), Offset(w * 0.3, h * 0.47), line);
    final tie = Path()
      ..moveTo(w * 0.3, h * 0.38)
      ..lineTo(w * 0.32, h * 0.5)
      ..lineTo(w * 0.3, h * 0.56)
      ..lineTo(w * 0.28, h * 0.5)
      ..close();
    canvas.drawPath(tie, fill);

    // الدراع الشمال جنبه، واليمين ساند على الدبوس
    canvas.drawLine(shoulderL, Offset(w * 0.12, h * 0.6), line);
    final hand = Offset(pinCenter.dx - pinRadius * 0.95, pinCenter.dy + pinRadius * 0.3);
    final arm = Path()
      ..moveTo(shoulderR.dx, shoulderR.dy)
      ..quadraticBezierTo(w * 0.5, h * 0.44, hand.dx, hand.dy);
    canvas.drawPath(arm, line);
    canvas.drawCircle(hand, w * 0.022, fill);

    // الرجلين
    canvas.drawLine(Offset(w * 0.24, h * 0.64), Offset(w * 0.23, h * 0.95), line);
    canvas.drawLine(Offset(w * 0.36, h * 0.64), Offset(w * 0.37, h * 0.95), line);
  }

  @override
  bool shouldRepaint(_LawyerPinPainter old) => old.color != color;
}
