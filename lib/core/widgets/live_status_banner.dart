import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/live_updates.dart';

/// شريط صغير لما الاتصال بالسيرفر يفضل مقطوع، عشان المستخدم يعرف إن اللي قدامه ممكن يكون قديم
class LiveStatusBanner extends StatelessWidget {
  const LiveStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: LiveUpdates.isConnected,
      builder: (context, isConnected, _) {
        if (isConnected) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          color: AppColors.primaryLight,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: const Text(
            'بنحاول نتصل… البيانات ممكن تكون مش محدثة',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'AppFont',
              fontFamilyFallback: appFontFallback,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        );
      },
    );
  }
}
