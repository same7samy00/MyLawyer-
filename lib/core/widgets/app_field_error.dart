import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// غلط في اللي المستخدم كتبه أو اختاره: نص أحمر تحت عنوان الخانة نفسها، بدل رسالة تحت الشاشة.
/// بيختفي أول ما المستخدم يصلّح الخانة. لو [text] فاضي مش بياخد مكان
class AppFieldError extends StatelessWidget {
  final String? text;

  const AppFieldError(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final message = text;
    if (message == null || message.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        message,
        style: const TextStyle(
          fontFamily: 'AppFont',
          fontFamilyFallback: appFontFallback,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          height: 1.5,
          color: AppColors.danger,
        ),
      ),
    );
  }
}
