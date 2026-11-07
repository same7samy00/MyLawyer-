import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// خط صفحات الاستشارة السريعة، بنفس خط التطبيق
TextStyle consultationText(double size, FontWeight weight, Color color, {double? height}) =>
    TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: size, fontWeight: weight, color: color, height: height);
