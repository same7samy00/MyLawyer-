import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// شارة الحالة الموحدة: خلفية فاتحة من لون الحالة، وأيقونة، ونص بنفس اللون، وحواف 7.
/// في كروت الطلبات، وتحت شريط المراحل في صفحة الطلب (وهناك بتتحدث لوحدها مع الطلب ووقت الوصول)
class StatusPill extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String? text;

  /// بدل [text] لما النص بيتغير لوحده، زي العداد
  final Widget? child;

  const StatusPill({super.key, required this.icon, required this.color, this.text, this.child});

  /// شكل النص جوه الشارة، للي بيبني [child] بنفسه
  static TextStyle textStyle(Color color) =>
      TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 12.5, height: 1.4, fontWeight: FontWeight.w800, color: color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(7.0)),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(child: child ?? Text(text ?? '', style: textStyle(color))),
        ],
      ),
    );
  }
}
