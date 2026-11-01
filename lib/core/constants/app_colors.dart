import 'package:flutter/material.dart';

export 'app_fonts.dart';

/// Official Brand Colors for My Lawyer
class AppColors {
  AppColors._();

  // حدود البطاقات والفواصل المتقطعة
  static const Color dashedBorder = Color(0xFF93C5FD);

  // Primary Brand Colors
  static const Color primary = Color(0xFF1D4ED8); // Blue
  static const Color primaryHover = Color(0xFF1E40AF);
  static const Color primaryLight = Color(0xFFEFF6FF);

  // Dark & Neutral Palette
  static const Color dark = Color(0xFF0F172A); // Slate 900
  static const Color darkSecondary = Color(0xFF1E293B); // Slate 800
  static const Color cardBorder = Color(0xFFE2E8F0); // Slate 200
  static const Color textMain = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B); // Slate 500
  static const Color background = Color(0xFFF8FAFC); // Slate 50

  // Status & Accent Colors
  static const Color success = Color(0xFF16A34A); // Green 600
  static const Color successLight = Color(0xFFDCFCE7);
  static const Color warning = Color(0xFFD97706); // Amber 600
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color danger = Color(0xFFDC2626); // Red 600
  static const Color dangerLight = Color(0xFFFEE2E2);

  // Specialized Cards & Sheets
  static const Color cardBg = Colors.white;
  static const Color bottomSheetHeaderBg = Color(0xFFF1F5F9);
}

