import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// رسالة خطأ الدخول: أيقونة على قد المشكلة، وسطر عنوان وتحته التفاصيل لو الرسالة طويلة
class AuthErrorBanner extends StatelessWidget {
  final String message;

  const AuthErrorBanner({super.key, required this.message});

  /// الأيقونة حسب نوع المشكلة
  static IconData iconFor(String message) {
    if (message.contains('كلمة المرور') || message.contains('كلمة السر')) return Icons.lock_outline_rounded;
    if (message.contains('غير مسجل') || message.contains('مش مسجل') || message.contains('غير موجود')) return Icons.person_off_outlined;
    if (message.contains('الاتصال') || message.contains('الإنترنت') || message.contains('النت') || message.contains('الخادم')) return Icons.wifi_off_rounded;
    if (message.contains('موقوف') || message.contains('محظور') || message.contains('معلق') || message.contains('إيقاف')) return Icons.block_rounded;
    if (message.contains('محاولات') || message.contains('حاول بعد')) return Icons.timer_outlined;
    if (message.contains('البصمة')) return Icons.fingerprint_rounded;
    if (message.contains('البريد') || message.contains('الإيميل')) return Icons.mark_email_unread_outlined;
    return Icons.error_outline_rounded;
  }

  /// الرسالة الطويلة تتقسم على أول فاصلة أو نقطة: العنوان فوق والتفاصيل تحت
  static (String, String?) split(String message) {
    final text = message.trim();
    if (text.length <= 34) return (text, null);
    final match = RegExp(r'[،,.!؟:]\s+').firstMatch(text);
    if (match == null || match.start < 6 || match.end >= text.length) return (text, null);
    return (text.substring(0, match.start).trim(), text.substring(match.end).trim());
  }

  @override
  Widget build(BuildContext context) {
    final (title, details) = split(message);
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Row(
          crossAxisAlignment: details == null ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: AppColors.dangerLight, borderRadius: BorderRadius.circular(7)),
              child: Icon(iconFor(message), color: AppColors.danger, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'AppFont',
                      fontFamilyFallback: appFontFallback,
                      color: AppColors.danger,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                  if (details != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      details,
                      style: const TextStyle(
                        fontFamily: 'AppFont',
                        fontFamilyFallback: appFontFallback,
                        color: Color(0xFFB91C1C),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
