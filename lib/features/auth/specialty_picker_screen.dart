import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/legal_specialties.dart';
import '../../core/widgets/app_pressable.dart';
import '../../core/widgets/auth_hero_header.dart';

/// اختيار تخصص المحامي من قائمة ثابتة، ويرجع التخصص المختار للتسجيل
class SpecialtyPickerScreen extends StatelessWidget {
  final String? selected;

  const SpecialtyPickerScreen({super.key, this.selected});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthHeroHeader(
                title: 'اختار تخصصك',
                description: 'التخصص بيظهر للموكلين في ملفك',
                illustration: 'assets/images/specialties_hero.svg',
                onBack: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final specialty in legalSpecialties)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _SpecialtyTile(
                          title: specialty,
                          isSelected: specialty == selected,
                          onTap: () => Navigator.of(context).pop(specialty),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpecialtyTile extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _SpecialtyTile({required this.title, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryLight : Colors.white,
            borderRadius: BorderRadius.circular(7.0),
            border: Border.all(color: isSelected ? AppColors.primary : AppColors.cardBorder),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'AppFont',
                    fontFamilyFallback: appFontFallback,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.dark,
                  ),
                ),
              ),
              if (isSelected) const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
