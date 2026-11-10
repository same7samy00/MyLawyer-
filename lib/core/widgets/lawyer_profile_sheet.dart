import 'package:flutter/material.dart';

import 'app_sheet.dart';
import 'lawyer_profile_summary.dart';
import 'lawyer_reviews_panel.dart';
import 'profile_photo.dart';

/// ملف المحامي من تفاصيل الطلب: الصورة والاسم والتقييم دلوقتي والخبرة، وتحتهم تقييماته وتعليقاته
class LawyerProfileSheet extends StatelessWidget {
  final String lawyerId;
  final String name;
  final String? photoPath;
  final double rating;
  final int reviewsCount;
  final int experienceYears;

  const LawyerProfileSheet({
    super.key,
    required this.lawyerId,
    required this.name,
    required this.photoPath,
    required this.rating,
    required this.reviewsCount,
    required this.experienceYears,
  });

  static Future<void> open(
    BuildContext context, {
    required String lawyerId,
    required String name,
    String? photoPath,
    double rating = 0,
    int reviewsCount = 0,
    int experienceYears = 0,
  }) {
    return AppSheet.show<void>(
      context,
      builder: (_) => LawyerProfileSheet(
        lawyerId: lawyerId,
        name: name,
        photoPath: photoPath,
        rating: rating,
        reviewsCount: reviewsCount,
        experienceYears: experienceYears,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      title: 'ملف المحامي',
      children: [
        LawyerProfileSummary(
          lawyerId: lawyerId,
          avatar: ProfilePhoto(path: photoPath, size: 64),
          name: name,
          rating: rating,
          reviewsCount: reviewsCount,
          experienceYears: experienceYears,
        ),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.42),
          child: LawyerReviewsPanel(lawyerId: lawyerId, onClose: () => Navigator.of(context).pop()),
        ),
      ],
    );
  }
}
