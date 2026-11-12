import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// شكل حقول الكتابة في الخدمات الميدانية: نفس شكل حقل «تفاصيل المشكلة»
const TextStyle fieldTextStyle = TextStyle(
  fontFamily: 'AppFont',
  fontFamilyFallback: appFontFallback,
  fontSize: 14,
  color: AppColors.dark,
);

const TextStyle fieldMutedStyle = TextStyle(
  fontFamily: 'AppFont',
  fontFamilyFallback: appFontFallback,
  fontSize: 12,
  color: AppColors.textMuted,
  height: 1.4,
);

const TextStyle fieldLabelStyle = TextStyle(
  fontFamily: 'AppFont',
  fontFamilyFallback: appFontFallback,
  fontSize: 13,
  fontWeight: FontWeight.w800,
  color: AppColors.dark,
);

InputDecoration fieldDecoration({required String hint, IconData? icon}) {
  OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.0),
        borderSide: BorderSide(color: color, width: width),
      );
  return InputDecoration(
    hintText: hint,
    hintStyle: fieldMutedStyle.copyWith(fontSize: 13),
    prefixIcon: icon == null ? null : Icon(icon, color: AppColors.textMuted, size: 20),
    filled: true,
    fillColor: Colors.white,
    counterText: '',
    contentPadding: const EdgeInsets.all(16),
    border: border(AppColors.cardBorder, 1.0),
    enabledBorder: border(AppColors.cardBorder, 1.0),
    focusedBorder: border(AppColors.primary, 1.4),
  );
}
