import 'package:flutter/material.dart';
import '../../data/models/lifecycle_models.dart';
import '../constants/app_colors.dart';
import 'app_card.dart';
import 'profile_photo.dart';

/// كارت تقييم واحد: الصورة على اليمين، وجنبها الاسم المختصر والنجوم والتعليق والوقت
class ReviewCard extends StatelessWidget {
  final LawyerReview review;

  const ReviewCard({super.key, required this.review});

  String get _formattedDate {
    final date = review.publishedAt;
    if (date == null) return '';
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.day}/${date.month}/${date.year} - $hour:$minute ${date.hour < 12 ? 'ص' : 'م'}';
  }

  TextStyle _style(double size, FontWeight weight, Color color) {
    return TextStyle(
      fontFamily: 'AppFont',
      fontFamilyFallback: appFontFallback,
      fontSize: size,
      height: 1.45,
      fontWeight: weight,
      color: color,
    );
  }

  @override
  Widget build(BuildContext context) {
    final comment = review.comment?.trim() ?? '';

    return AppCard(
      isDashed: false,
      borderRadius: 7.0,
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProfilePhoto(path: review.authorPhoto, size: 48),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        review.authorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _style(13, FontWeight.w800, AppColors.dark),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.verified_user_rounded, size: 14, color: AppColors.success),
                    const SizedBox(width: 3),
                    Text('تجربة مؤكدة', style: _style(11, FontWeight.w700, AppColors.success)),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    for (int star = 1; star <= 5; star++)
                      Icon(
                        star <= review.rating ? Icons.star_rounded : Icons.star_border_rounded,
                        color: const Color(0xFFEAB308),
                        size: 16,
                      ),
                  ],
                ),
                if (comment.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(comment, style: _style(13, FontWeight.w400, AppColors.textMain)),
                ],
                if (_formattedDate.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(_formattedDate, style: _style(11, FontWeight.w400, AppColors.textMuted)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
