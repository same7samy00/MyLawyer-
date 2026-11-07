import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'app_button.dart';
import 'line_illustration.dart';

/// رسالة حالة موحدة للقوائم: لا توجد بيانات أو تعذر التحميل مع إعادة المحاولة
class AppStateMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Future<void> Function()? onRetry;
  final String retryText;

  const AppStateMessage({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.onRetry,
    this.retryText = 'إعادة المحاولة',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LineIllustration(icon: icon, height: 84),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'AppFont',
              fontFamilyFallback: appFontFallback,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.dark,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'AppFont',
                fontFamilyFallback: appFontFallback,
                fontSize: 12,
                height: 1.5,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: 18),
            AppButton.outlined(
              text: retryText,
              icon: Icons.refresh_rounded,
              onPressed: onRetry,
            ),
          ],
        ],
      ),
    );
  }
}
