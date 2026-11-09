import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/service_tag.dart';
import '../../data/models/service_request.dart';

/// كارت طلب «محاميك حالاً» لسه ما اتختارش فيه محامي: بيدوّر على محامين، أو وصلته عروض، أو اتقفل من غير اختيار.
/// لما يتختار محامي الطلب بيظهر بكارت الطلب العادي بداله
class RequestOrderCard extends StatelessWidget {
  final MyRequest request;
  final VoidCallback? onOpen;

  const RequestOrderCard({super.key, required this.request, this.onOpen});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      onTap: request.isOpen ? onOpen : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ServiceTag(name: request.serviceTitle, icon: Icons.location_on_rounded),
          const SizedBox(height: 10),
          Text(request.problemType, style: _titleStyle),
          const SizedBox(height: 4),
          Text('السعر من ${request.minPrice} لـ ${request.maxPrice} ج.م', style: _mutedStyle),
          const SizedBox(height: 10),
          Text(request.statusLabel, style: TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 13, fontWeight: FontWeight.w800, color: request.isOpen ? AppColors.primary : AppColors.textMuted)),
          if (request.isOpen) ...[
            const SizedBox(height: 10),
            Text(request.offers > 0 ? 'دوس عشان تشوف العروض وتختار' : 'دوس عشان تتابع', style: _mutedStyle),
          ],
        ],
      ),
    );
  }

  static const TextStyle _titleStyle = TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.dark);
  static const TextStyle _mutedStyle = TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 12.5, color: AppColors.textMuted);
}
