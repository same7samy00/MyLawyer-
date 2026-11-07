import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/notification_center.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_header.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/app_state_message.dart';
import '../../core/widgets/profile_photo.dart';
import '../../data/repositories/profile_repository.dart';

/// صورة الحساب وبياناته المسجلة للموكل والمحامي
class PersonalDataScreen extends StatefulWidget {
  const PersonalDataScreen({super.key});

  @override
  State<PersonalDataScreen> createState() => _PersonalDataScreenState();
}

class _PersonalDataScreenState extends State<PersonalDataScreen> {
  Map<String, dynamic>? _profile = ProfileRepository.saved;
  String? _error;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await ProfileRepository.me();
    if (!mounted) return;

    setState(() {
      if (res.isOk && res.data is Map<String, dynamic>) {
        _profile = res.data as Map<String, dynamic>;
        _error = null;
      } else if (_profile == null) {
        _error = res.error ?? 'تعذر تحميل بياناتك';
      }
    });
  }

  void _showNotice(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback),
        ),
        backgroundColor: AppColors.dark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7.0)),
      ),
    );
  }

  Future<void> _pickPhoto() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
    if (image == null || !mounted) return;

    setState(() => _isUploading = true);
    final res = await ProfileRepository.uploadPhoto(image.path);
    if (!mounted) return;

    setState(() => _isUploading = false);
    _showNotice(res.isOk ? 'تم تحديث الصورة' : (res.error ?? 'تعذر رفع الصورة'));
    if (!res.isOk) return;

    await _load();
    NotificationCenter.profileChanged.value++;
  }

  String _joinDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    return date == null ? '-' : '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppHeader(title: 'البيانات الشخصية', isInnerPage: true),
      body: SafeArea(
        child: profile == null
            ? (_error == null
                ? const Center(child: AppLoader())
                : ListView(
                    children: [
                      AppStateMessage(
                        icon: Icons.wifi_off_rounded,
                        title: 'تعذر تحميل بياناتك',
                        message: _error,
                        onRetry: _load,
                      ),
                    ],
                  ))
            : _buildContent(profile),
      ),
    );
  }

  Widget _buildContent(Map<String, dynamic> profile) {
    final isLawyer = profile['role'] == 'lawyer';
    final rows = <Widget>[
      _infoRow('الاسم', profile['fullName']),
      _infoRow('رقم الهاتف', profile['phone']),
      _infoRow('البريد الإلكتروني', profile['email']),
      _infoRow('تاريخ التسجيل', _joinDate(profile['createdAt'])),
      if (isLawyer) ...[
        _infoRow('رقم القيد', profile['syndicateNumber']),
        _infoRow('سنوات الخبرة', profile['experienceYears']),
        _infoRow('الاعتماد', profile['isApproved'] == true ? 'محامٍ معتمد' : 'محامٍ غير معتمد'),
      ],
    ];

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Center(
          child: _isUploading
              ? const SizedBox(
                  width: 110,
                  height: 110,
                  child: Center(child: AppLoader.inline(size: 30)),
                )
              : ProfilePhoto(path: profile['profilePhotoPath']?.toString(), size: 110),
        ),
        const SizedBox(height: 12),
        Center(
          child: SizedBox(
            width: 170,
            child: AppButton.outlined(
              text: 'تغيير الصورة',
              icon: Icons.add_a_photo_rounded,
              height: 42,
              fontSize: 13,
              onPressed: _isUploading ? null : _pickPhoto,
            ),
          ),
        ),
        const SizedBox(height: 18),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: AppColors.cardBorder),
                rows[i],
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoRow(String label, dynamic value) {
    final text = value?.toString() ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 116,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'AppFont',
                fontFamilyFallback: appFontFallback,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text.isEmpty ? '-' : text,
              style: const TextStyle(
                fontFamily: 'AppFont',
                fontFamilyFallback: appFontFallback,
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w800,
                color: AppColors.dark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
