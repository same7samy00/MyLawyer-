import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class TermsSection {
  final IconData icon;
  final String title;
  final List<String> items;

  const TermsSection({required this.icon, required this.title, required this.items});
}

/// الشروط مقسمة أقسام، كل قسم في حاوية تفتح وتقفل
class TermsAccordion extends StatelessWidget {
  final List<TermsSection> sections;

  const TermsAccordion({super.key, required this.sections});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < sections.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _TermsTile(section: sections[i], initiallyExpanded: i == 0),
        ],
      ],
    );
  }
}

class _TermsTile extends StatelessWidget {
  final TermsSection section;
  final bool initiallyExpanded;

  const _TermsTile({required this.section, required this.initiallyExpanded});

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(7.0),
      side: const BorderSide(color: AppColors.cardBorder),
    );

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        backgroundColor: Colors.white,
        collapsedBackgroundColor: Colors.white,
        shape: shape,
        collapsedShape: shape,
        iconColor: AppColors.primary,
        collapsedIconColor: AppColors.textMuted,
        tilePadding: const EdgeInsets.symmetric(horizontal: 14),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(7.0),
          ),
          child: Icon(section.icon, color: AppColors.primary, size: 19),
        ),
        title: Text(
          section.title,
          style: const TextStyle(
            fontFamily: 'AppFont',
            fontFamilyFallback: appFontFallback,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.dark,
          ),
        ),
        children: [
          for (final item in section.items)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                item,
                style: const TextStyle(
                  fontFamily: 'AppFont',
                  fontFamilyFallback: appFontFallback,
                  fontSize: 13,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMain,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
