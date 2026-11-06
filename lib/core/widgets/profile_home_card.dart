import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../../data/repositories/profile_repository.dart';
import '../services/notification_center.dart';
import 'app_button.dart';
import 'app_card.dart';
import 'lawyer_reviews_panel.dart';
import 'profile_photo.dart';

/// كارت الحساب في الرئيسية للمحامي والموكل، وبياناته من الخادم
class ProfileHomeCard extends StatefulWidget {
  final String locationName;

  const ProfileHomeCard({super.key, required this.locationName});

  @override
  State<ProfileHomeCard> createState() => _ProfileHomeCardState();
}

class _ProfileHomeCardState extends State<ProfileHomeCard> {
  Map<String, dynamic>? _profile;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _load();
    // التقييم يتحدث مع وصول أي إشعار جديد، ومع رجوع المستخدم للتطبيق
    NotificationCenter.unread.addListener(_load);
    NotificationCenter.profileChanged.addListener(_load);
    _lifecycle = AppLifecycleListener(onResume: _load);
  }

  @override
  void dispose() {
    NotificationCenter.unread.removeListener(_load);
    NotificationCenter.profileChanged.removeListener(_load);
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final res = await ProfileRepository.me();
    if (mounted && res.data is Map<String, dynamic>) {
      setState(() => _profile = res.data as Map<String, dynamic>);
    }
  }

  String get _dualName {
    final words = (_profile?['fullName']?.toString() ?? '').trim().split(RegExp(r'\s+'));
    return words.take(2).join(' ');
  }

  bool get _isLawyer => _profile?['role'] == 'lawyer';

  void _openReviews() {
    final lawyerId = _profile!['id'].toString();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('تقييماتي')),
          body: Padding(
            padding: const EdgeInsets.all(18),
            child: LawyerReviewsPanel(lawyerId: lawyerId, canReport: true, onClose: () => Navigator.of(context).pop()),
          ),
        ),
      ),
    );
  }

  Widget _buildStars(num rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var star = 1; star <= 5; star++)
          Icon(
            rating >= star
                ? Icons.star_rounded
                : (rating >= star - 0.5 ? Icons.star_half_rounded : Icons.star_border_rounded),
            size: 20,
            color: const Color(0xFFEAB308),
          ),
        const SizedBox(width: 6),
        Text('$rating', style: _nameStyle.copyWith(fontSize: 14)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    if (profile == null) return const SizedBox(height: 150);

    final rating = profile['rating'] ?? 0;

    return AppCard(
      padding: const EdgeInsets.all(16),
      backgroundColor: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ProfilePhoto(path: profile['profilePhotoPath']?.toString()),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('أهلاً يا $_dualName', maxLines: 1, overflow: TextOverflow.ellipsis, style: _nameStyle),
                    const SizedBox(height: 3),
                    Text(widget.locationName, maxLines: 1, overflow: TextOverflow.ellipsis, style: _detailStyle),
                    if (_isLawyer) ...[
                      const SizedBox(height: 3),
                      Text(
                        profile['isApproved'] == true ? 'محامٍ معتمد' : 'محامٍ غير معتمد',
                        style: _detailStyle.copyWith(fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const DashedDivider(color: Colors.white38),
          const SizedBox(height: 12),
          if (_isLawyer) ...[
            Row(
              children: [
                Expanded(child: _infoChip('رقم القيد', '${profile['syndicateNumber'] ?? 'غير مسجل'}')),
                const SizedBox(width: 8),
                Expanded(child: _infoChip('سنوات الخبرة', '${profile['experienceYears'] ?? 0}')),
              ],
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              _buildStars(rating is num ? rating : 0),
              const Spacer(),
              if (_isLawyer)
                SizedBox(
                  width: 120,
                  child: AppButton(
                    text: 'التقييمات',
                    height: 38,
                    fontSize: 12,
                    backgroundColor: Colors.white,
                    textColor: AppColors.primary,
                    onPressed: _openReviews,
                  ),
                )
              else
                Text('${profile['completedOrders'] ?? 0} طلب مكتمل', style: _detailStyle),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.14), borderRadius: BorderRadius.circular(7.0)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: _detailStyle.copyWith(fontSize: 11)),
          const SizedBox(height: 2),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: _nameStyle.copyWith(fontSize: 14)),
        ],
      ),
    );
  }

  static const TextStyle _nameStyle = TextStyle(
    fontFamily: 'AppFont',
    fontFamilyFallback: appFontFallback,
    fontSize: 16,
    fontWeight: FontWeight.w900,
    color: Colors.white,
  );

  static const TextStyle _detailStyle = TextStyle(
    fontFamily: 'AppFont',
    fontFamilyFallback: appFontFallback,
    fontSize: 12,
    height: 1.4,
    fontWeight: FontWeight.w600,
    color: Color(0xDDFFFFFF),
  );
}
