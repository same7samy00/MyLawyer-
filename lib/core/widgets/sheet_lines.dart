import 'package:flutter/material.dart';
import 'line_illustration.dart';

/// خط زخرفي من حافة البوتن شيت إلى الحافة الأخرى، يوضع خلف المحتوى داخل Stack
class SheetLines extends StatelessWidget {
  final double top;

  const SheetLines({super.key, required this.top});

  @override
  Widget build(BuildContext context) {
    return Positioned(left: 0, right: 0, top: top, height: 62, child: const EdgeLine());
  }
}
