import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/notification_center.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/biometric_toggle_tile.dart';
import '../../core/widgets/logout_confirmation_sheet.dart';
import '../../core/widgets/profile_photo.dart';
import '../../core/widgets/top_message.dart';
import '../../data/repositories/profile_repository.dart';
import '../account/personal_data_screen.dart';
import '../auth/session_router.dart';
import '../support/support_screen.dart';

/// تبويب الحساب الشخصي للمحامي
/// يطابق تصميم حساب الموكل مع تخصيص البيانات للاعتماد المهني ونقابة المحامين
class LawyerAccountTab extends StatefulWidget {
  const LawyerAccountTab({super.key});

  @override
  State<LawyerAccountTab> createState() => _LawyerAccountTabState();
}

class _LawyerAccountTabState extends State<LawyerAccountTab> {
  // الاسم والرقم ورقم القيد من بيانات الحساب المحفوظة، فالكارت بيتبني كامل من أول لحظة
  String _lawyerName = _shortName(ProfileRepository.saved?['fullName']?.toString());
  String _syndicateNumber = ProfileRepository.saved?['syndicateNumber']?.toString() ?? '';
  String _userPhone = ProfileRepository.saved?['phone']?.toString() ?? '';

  static String _shortName(String? name) {
    if (name == null || name.trim().isEmpty) return '';
    final words = name.trim().split(RegExp(r'\s+'));
    return 'أ/ ${words.length >= 2 ? '${words[0]} ${words[1]}' : words[0]}';
  }
  String? _photoPath = ProfileRepository.saved?['profilePhotoPath']?.toString();

  @override
  void initState() {
    super.initState();
    NotificationCenter.profileChanged.addListener(_loadPhoto);
    _loadLawyerData();
    _loadPhoto();
  }

  @override
  void dispose() {
    NotificationCenter.profileChanged.removeListener(_loadPhoto);
    super.dispose();
  }

  Future<void> _loadPhoto() async {
    final res = await ProfileRepository.me();
    if (mounted && res.data is Map<String, dynamic>) {
      setState(() => _photoPath = (res.data as Map<String, dynamic>)['profilePhotoPath']?.toString());
    }
  }

  Future<void> _loadLawyerData() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('user_name');
    final phone = prefs.getString('user_phone');
    final syndicate = prefs.getString('syndicate_number');

    if (!mounted) return;

    setState(() {
      if (name != null && name.trim().isNotEmpty) {
        final words = name.trim().split(RegExp(r'\s+'));
        final dual = words.length >= 2 ? '${words[0]} ${words[1]}' : words[0];
        _lawyerName = 'أ/ $dual';
      }
      if (phone != null && phone.trim().isNotEmpty) {
        _userPhone = phone.trim();
      }
      if (syndicate != null && syndicate.trim().isNotEmpty) {
        _syndicateNumber = syndicate.trim();
      }
    });
  }

  void _handleLogout() {
    final navigator = Navigator.of(context, rootNavigator: true);
    LogoutConfirmationSheet.show(
      context,
      onConfirm: () => SessionRouter.signOut(navigator),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // بطاقة بيانات المحامي المهنية
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  ProfilePhoto(path: _photoPath, size: 52),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                _lawyerName,
                                style: const TextStyle(
                                  fontFamily: 'AppFont',
                                  fontFamilyFallback: appFontFallback,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.dark,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 16),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'رقم القيد: $_syndicateNumber • $_userPhone',
                          style: const TextStyle(
                            fontFamily: 'AppFont',
                            fontFamilyFallback: appFontFallback,
                            fontSize: 12,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // قائمة الإعدادات والخيارات
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  _buildMenuItem(
                    icon: Icons.badge_outlined,
                    title: 'البيانات المهنية والتراخيص',
                    subtitle: 'صورتك وبيانات حسابك المسجلة',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const PersonalDataScreen()),
                      );
                    },
                  ),
                  const Divider(height: 1, color: AppColors.cardBorder, indent: 16, endIndent: 16),
                  const BiometricToggleTile(),
                  const Divider(height: 1, color: AppColors.cardBorder, indent: 16, endIndent: 16),
                  _buildMenuItem(
                    icon: Icons.access_time_rounded,
                    title: 'أوقات الجاهزية واستقبال الطلبات',
                    subtitle: 'تحديد جدول العمل وتلقي البلاغات العاجلة',
                    onTap: () => _showComingSoon('أوقات الجاهزية'),
                  ),
                  const Divider(height: 1, color: AppColors.cardBorder, indent: 16, endIndent: 16),
                  _buildMenuItem(
                    icon: Icons.notifications_none_rounded,
                    title: 'إعدادات الإشعارات والتنبيهات',
                    subtitle: 'نغمات الطلبات العاجلة والإخطارات الميدانية',
                    onTap: () => _showComingSoon('إعدادات الإشعارات'),
                  ),
                  const Divider(height: 1, color: AppColors.cardBorder, indent: 16, endIndent: 16),
                  _buildMenuItem(
                    icon: Icons.security_rounded,
                    title: 'الشروط والأحكام المهنية للمحامين',
                    subtitle: 'ضوابط وأخلاقيات المهنة وسرية البيانات',
                    onTap: () => _showComingSoon('الشروط والأحكام'),
                  ),
                  const Divider(height: 1, color: AppColors.cardBorder, indent: 16, endIndent: 16),
                  _buildMenuItem(
                    icon: Icons.headset_mic_outlined,
                    title: 'الدعم الفني',
                    subtitle: 'افتح تذكرة وتابع ردود الإدارة',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const SupportScreen()),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // زر تسجيل الخروج
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                onTap: _handleLogout,
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(7.0),
                  ),
                  child: Transform.flip(
                    flipX: true,
                    child: const Icon(Icons.logout_rounded, color: AppColors.danger, size: 20),
                  ),
                ),
                title: const Text(
                  'تسجيل الخروج',
                  style: TextStyle(
                    fontFamily: 'AppFont',
                    fontFamilyFallback: appFontFallback,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.danger,
                  ),
                ),
                subtitle: const Text(
                  'إنهاء جلسة الحساب والعودة لشاشة الدخول',
                  style: TextStyle(
                    fontFamily: 'AppFont',
                    fontFamilyFallback: appFontFallback,
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.danger),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(7.0),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontFamily: 'AppFont',
          fontFamilyFallback: appFontFallback,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.dark,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontFamily: 'AppFont',
          fontFamilyFallback: appFontFallback,
          fontSize: 11,
          color: AppColors.textMuted,
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textMuted),
    );
  }

  void _showComingSoon(String feature) {
    showTopMessage(context, 
      SnackBar(
        content: Text('صفحة $feature قيد التجهيز والتطوير', style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback)),
        backgroundColor: AppColors.dark,
      ),
    );
  }
}
