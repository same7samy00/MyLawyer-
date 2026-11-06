import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'app_button.dart';
import 'line_illustration.dart';

/// النافذة العائمة الموحدة: رسمة صغيرة في النص وخطها من الحافة للحافة، والعنوان والنص يمين، وزرين ملونين جنب بعض
class AppDialog extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? child;
  final String confirmText;
  final String cancelText;
  final bool isDanger;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const AppDialog({
    super.key,
    required this.icon,
    required this.title,
    required this.confirmText,
    required this.onConfirm,
    required this.onCancel,
    this.message,
    this.child,
    this.cancelText = 'إلغاء',
    this.isDanger = false,
  });

  /// نافذة تأكيد بترجع true لو المستخدم أكد
  static Future<bool> confirm(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
    required String confirmText,
    bool isDanger = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppDialog(
        icon: icon,
        title: title,
        message: message,
        confirmText: confirmText,
        isDanger: isDanger,
        onConfirm: () => Navigator.pop(dialogContext, true),
        onCancel: () => Navigator.pop(dialogContext, false),
      ),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.0)),
      child: Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LineIllustration(icon: icon, height: 64),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.start,
                    style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.dark),
                  ),
                  if (message != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      message!,
                      textAlign: TextAlign.start,
                      style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 13, height: 1.5, color: AppColors.textMuted),
                    ),
                  ],
                  if (child != null) ...[const SizedBox(height: 10), child!],
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          text: cancelText,
                          height: 44,
                          fontSize: 14,
                          // زرار الإلغاء أحمر في التطبيق كله
                          backgroundColor: AppColors.danger.withOpacity(0.08),
                          textColor: AppColors.danger,
                          onPressed: onCancel,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppButton(
                          text: confirmText,
                          height: 44,
                          fontSize: 14,
                          backgroundColor: isDanger ? AppColors.danger : AppColors.primary,
                          textColor: Colors.white,
                          onPressed: onConfirm,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
