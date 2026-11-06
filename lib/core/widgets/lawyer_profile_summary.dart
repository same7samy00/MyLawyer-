import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'status_badge.dart';

/// ملخص ملف المحامي الموحد داخل البوتن شيت: الصورة والاسم في المنتصف، ثم المؤشرات الثلاثة
class LawyerProfileSummary extends StatelessWidget {
  final Widget avatar;
  final String name;
  final double rating;
  final int reviewsCount;
  final int experienceYears;
  final String distanceText;
  final String distanceCaption;
  final bool isNearest;

  const LawyerProfileSummary({
    super.key,
    required this.avatar,
    required this.name,
    required this.rating,
    required this.reviewsCount,
    required this.experienceYears,
    required this.distanceText,
    this.distanceCaption = 'يبعد عنك',
    this.isNearest = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. الهوية: الصورة والاسم وشارة الأقرب
        Center(child: avatar),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'AppFont',
                  fontFamilyFallback: appFontFallback,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: AppColors.dark,
                ),
                maxLines: 2,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 16),
          ],
        ),
        if (isNearest) ...[
          const SizedBox(height: 4),
          const Center(child: StatusBadge(text: 'الأقرب إليك')),
        ],
        const SizedBox(height: 10),

        // 2. المؤشرات: التقييم والخبرة والمسافة في أعمدة متساوية
        IntrinsicHeight(
          child: Row(
            children: [
              _LawyerStat(
                value: reviewsCount > 0 ? '$rating' : 'جديد',
                caption: reviewsCount > 0 ? '$reviewsCount تقييم' : 'بدون تقييمات',
                leading: const Icon(Icons.star_rounded, color: Color(0xFFEAB308), size: 16),
              ),
              const VerticalDivider(width: 1, thickness: 1, color: AppColors.cardBorder),
              _LawyerStat(value: '$experienceYears', caption: 'سنوات خبرة'),
              const VerticalDivider(width: 1, thickness: 1, color: AppColors.cardBorder),
              _LawyerStat(value: distanceText, caption: distanceCaption),
            ],
          ),
        ),
      ],
    );
  }
}

class _LawyerStat extends StatelessWidget {
  final String value;
  final String caption;
  final Widget? leading;

  const _LawyerStat({
    required this.value,
    required this.caption,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: 3),
                ],
                Flexible(
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontFamily: 'AppFont',
                      fontFamilyFallback: appFontFallback,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: AppColors.dark,
                    ),
                    maxLines: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              caption,
              style: const TextStyle(
                fontFamily: 'AppFont',
                fontFamilyFallback: appFontFallback,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }
}
