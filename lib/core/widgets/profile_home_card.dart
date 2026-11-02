import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/app_colors.dart';
import '../services/api_service.dart';
import '../services/notification_center.dart';
import 'app_button.dart';
import 'app_card.dart';
import 'lawyer_reviews_panel.dart';

/// كارت الحساب في الرئيسية للمحامي والموكل، وبياناته من الخادم
class ProfileHomeCard extends StatefulWidget {
  final String locationName;

  const ProfileHomeCard({super.key, required this.locationName});

  @override
  State<ProfileHomeCard> createState() => _ProfileHomeCardState();
}

class _ProfileHomeCardState extends State<ProfileHomeCard> {
  Map<String, dynamic>? _profile;
  bool _isUploading = false;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _load();
    // التقييم يتحدث مع وصول أي إشعار جديد، ومع رجوع المستخدم للتطبيق
    NotificationCenter.unread.addListener(_load);
    _lifecycle = AppLifecycleListener(onResume: _load);
  }

  @override
  void dispose() {
    NotificationCenter.unread.removeListener(_load);
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final res = await ApiService.get('/users/me');
    if (mounted && res.data is Map<String, dynamic>) {
      setState(() => _profile = res.data as Map<String, dynamic>);
    }
  }

  String get _dualName {
    final words = (_profile?['fullName']?.toString() ?? '').trim().split(RegExp(r'\s+'));
    return words.take(2).join(' ');
  }

  bool get _isLawyer => _profile?['role'] == 'lawyer';

  Future<void> _pickPhoto() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
    if (image == null || !mounted) return;

    setState(() => _isUploading = true);
    final res = await ApiService.uploadFile('/users/me/profile-photo', image.path);
    if (!mounted) return;

    setState(() => _isUploading = false);
    if (res.isOk) {
      await _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.error ?? 'تعذر رفع الصورة')),
      );
    }
  }

  void _openReviews() {
    final lawyerId = _profile!['id'].toString();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('تقييماتي')),
          body: Padding(
            padding: const EdgeInsets.all(18),
            child: LawyerReviewsPanel(lawyerId: lawyerId, onClose: () => Navigator.of(context).pop()),
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

    final photo = profile['profilePhotoPath']?.toString() ?? '';
    final origin = ApiService.baseUrl.replaceAll('/api/v1', '');
    final rating = profile['rating'] ?? 0;
    final bio = profile['bio']?.toString() ?? '';

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              InkWell(
                onTap: _isUploading ? null : _pickPhoto,
                borderRadius: BorderRadius.circular(7.0),
                child: Container(
                  width: 64,
                  height: 64,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(7.0),
                  ),
                  child: _isUploading
                      ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                      : photo.isEmpty
                          ? const Icon(Icons.add_a_photo_rounded, color: AppColors.primary, size: 26)
                          : Image.network('$origin$photo', fit: BoxFit.cover),
                ),
              ),
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
                        style: _detailStyle.copyWith(
                          fontWeight: FontWeight.w800,
                          color: profile['isApproved'] == true ? AppColors.success : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (_isLawyer) ...[
            const SizedBox(height: 10),
            Text('رقم القيد: ${profile['syndicateNumber'] ?? 'غير مسجل'}', style: _detailStyle),
            if (profile['specialty'] != null) ...[
              const SizedBox(height: 3),
              Text('التخصص: ${profile['specialty']}', style: _detailStyle),
            ],
            if (bio.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(bio, maxLines: 3, overflow: TextOverflow.ellipsis, style: _detailStyle),
            ],
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStars(rating is num ? rating : 0),
              const Spacer(),
              if (_isLawyer)
                SizedBox(
                  width: 120,
                  child: AppButton.outlined(text: 'التقييمات', height: 38, fontSize: 12, onPressed: _openReviews),
                )
              else
                Text('${profile['completedOrders'] ?? 0} طلب مكتمل', style: _detailStyle),
            ],
          ),
        ],
      ),
    );
  }

  static const TextStyle _nameStyle = TextStyle(
    fontFamily: 'AppFont',
    fontFamilyFallback: appFontFallback,
    fontSize: 16,
    fontWeight: FontWeight.w900,
    color: AppColors.dark,
  );

  static const TextStyle _detailStyle = TextStyle(
    fontFamily: 'AppFont',
    fontFamilyFallback: appFontFallback,
    fontSize: 12,
    height: 1.4,
    fontWeight: FontWeight.w600,
    color: AppColors.textMain,
  );
}
