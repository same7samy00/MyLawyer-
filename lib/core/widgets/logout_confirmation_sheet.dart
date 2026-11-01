import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'app_button.dart';
import 'app_pressable.dart';

/// نافذة تأكيد تسجيل الخروج الموحدة لحساب الموكل والمحامي
/// [onConfirm] هو إجراء الخروج الفعلي ويبقى التحميل داخل الزر حتى انتهائه
class LogoutConfirmationSheet extends StatelessWidget {
  final Future<void> Function() onConfirm;

  const LogoutConfirmationSheet({super.key, required this.onConfirm});

  static Future<void> show(BuildContext context, {required Future<void> Function() onConfirm}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (context) => LogoutConfirmationSheet(onConfirm: onConfirm),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.cardBorder,
                borderRadius: BorderRadius.circular(4.0),
              ),
            ),
            const SizedBox(height: 24),
            Transform.flip(
              flipX: true,
              child: const Icon(
                Icons.logout_rounded,
                color: AppColors.danger,
                size: 76,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'تسجيل الخروج',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'AppFont',
                fontFamilyFallback: appFontFallback,
                fontSize: 21,
                fontWeight: FontWeight.w900,
                color: AppColors.dark,
              ),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.0),
              child: Text(
                'هل أنت متأكد من رغبتك في تسجيل الخروج من حسابك؟ يمكنك تسجيل الدخول مجدداً في أي وقت.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'AppFont',
                  fontFamilyFallback: appFontFallback,
                  fontSize: 13,
                  height: 1.5,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 28),
            AppButton(
              text: 'تأكيد تسجيل الخروج',
              backgroundColor: AppColors.danger,
              fontWeight: FontWeight.w700,
              onPressed: onConfirm,
            ),
            const SizedBox(height: 10),
            AppPressable(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24.0),
                  ),
                ),
                child: const Text(
                  'إلغاء والعودة',
                  style: TextStyle(
                    fontFamily: 'AppFont',
                    fontFamilyFallback: appFontFallback,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
