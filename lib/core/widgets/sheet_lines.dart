import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// خط زخرفي من حافة البوتن شيت إلى الحافة الأخرى، يوضع خلف المحتوى داخل Stack
class SheetLines extends StatelessWidget {
  final double top;

  const SheetLines({super.key, required this.top});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      top: top,
      height: 62,
      child: IgnorePointer(
        child: SvgPicture.asset(
          'assets/images/sheet_lines.svg',
          fit: BoxFit.fill,
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}
