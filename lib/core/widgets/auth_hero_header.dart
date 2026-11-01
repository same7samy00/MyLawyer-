import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../constants/app_colors.dart';
import 'app_pressable.dart';

/// واجهة علوية موحدة لشاشات إنشاء الحساب بدل الهيدر: رسمة بعرض الشاشة وتحتها العنوان والوصف في المنتصف
class AuthHeroHeader extends StatelessWidget {
  final String title;
  final String? description;
  final String illustration;
  final VoidCallback onBack;

  const AuthHeroHeader({
    super.key,
    required this.title,
    this.description,
    this.illustration = 'assets/images/auth_hero.svg',
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
            AspectRatio(
              aspectRatio: 360 / 170,
              child: SvgPicture.asset(
                illustration,
                excludeFromSemantics: true,
              ),
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
            fontSize: 28,
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
