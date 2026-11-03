import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'app_pressable.dart';
import 'line_illustration.dart';

/// واجهة علوية موحدة لشاشات إنشاء الحساب بدل الهيدر: رسمة بعرض الشاشة وتحتها العنوان والوصف في المنتصف
class AuthHeroHeader extends StatelessWidget {
  final String title;
  final String? description;
  final IconData icon;
  final VoidCallback onBack;

  const AuthHeroHeader({
    super.key,
    required this.title,
    this.description,
    this.icon = Icons.person_add_alt_1_rounded,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: LineIllustration(icon: icon, height: 110),
            ),
            PositionedDirectional(
              start: 8,
              top: 4,
              child: AppPressable(
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: AppColors.dark),
                  onPressed: onBack,
                  tooltip: 'رجوع',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'AppFont',
            fontFamilyFallback: appFontFallback,
            fontSize: 24,
            height: 1.25,
            fontWeight: FontWeight.w900,
            color: AppColors.dark,
          ),
        ),
        if (description != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Text(
              description!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'AppFont',
                fontFamilyFallback: appFontFallback,
                fontSize: 14,
                height: 1.5,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
