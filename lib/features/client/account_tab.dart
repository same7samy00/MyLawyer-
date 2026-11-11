import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/notification_center.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_pressable.dart';
import '../../core/widgets/biometric_toggle_tile.dart';
import '../../core/widgets/logout_confirmation_sheet.dart';
import '../../core/widgets/profile_photo.dart';
import '../../data/repositories/profile_repository.dart';
import '../account/payments_screen.dart';
import '../account/personal_data_screen.dart';
import '../account/terms_privacy_screen.dart';
import '../auth/session_router.dart';
import '../support/support_screen.dart';

class AccountTab extends StatefulWidget {
  const AccountTab({super.key});

  @override
  State<AccountTab> createState() => _AccountTabState();
}

class _AccountTabState extends State<AccountTab> {
  Map<String, dynamic>? _profile = ProfileRepository.saved;

  @override
  void initState() {
    super.initState();
    NotificationCenter.profileChanged.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    NotificationCenter.profileChanged.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final res = await ProfileRepository.me();
    if (mounted && res.data is Map<String, dynamic>) {
      setState(() => _profile = res.data as Map<String, dynamic>);
    }
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
            // Profile Info Card
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  ProfilePhoto(path: _profile?['profilePhotoPath']?.toString(), size: 52),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _profile?['fullName']?.toString() ?? '',
                          style: const TextStyle(
                            fontFamily: 'AppFont',
                            fontFamilyFallback: appFontFallback,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.dark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _profile?['phone']?.toString() ?? '',
                          style: const TextStyle(
                            fontFamily: 'AppFont',
                            fontFamilyFallback: appFontFallback,
                            fontSize: 13,
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
            const SizedBox(height: 20),

            // Settings Items List
            _buildSettingItem(
              title: 'البيانات الشخصية',
              icon: Icons.badge_outlined,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const PersonalDataScreen()),
                );
              },
            ),
            _buildSettingItem(
              title: 'المدفوعات والفواتير',
              icon: Icons.receipt_long_rounded,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const PaymentsScreen()),
                );
              },
            ),
            const BiometricToggleTile(card: true),
            _buildSettingItem(
              title: 'تغيير كلمة المرور',
              icon: Icons.lock_reset_rounded,
              onTap: () {},
            ),
            _buildSettingItem(
              title: 'الدعم الفني',
              icon: Icons.headset_mic_outlined,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const SupportScreen()),
                );
              },
            ),
            _buildSettingItem(
              title: 'الشروط والأحكام وسياسة الخصوصية',
              icon: Icons.verified_user_outlined,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const TermsPrivacyScreen()),
              ),
            ),
            const SizedBox(height: 20),

            // Logout Button
            AppPressable(
              child: OutlinedButton.icon(
              onPressed: _handleLogout,
              icon: Transform.flip(
                flipX: true,
                child: const Icon(Icons.logout_rounded, color: AppColors.danger, size: 20),
              ),
              label: const Text(
                'تسجيل الخروج',
                style: TextStyle(
                  fontFamily: 'AppFont',
                  fontFamilyFallback: appFontFallback,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.danger,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.danger, width: 1.0),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.0)),
              ),
            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontFamily: 'AppFont',
                  fontFamilyFallback: appFontFallback,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.dark,
                ),
              ),
            ),
            const Icon(Icons.keyboard_arrow_left_rounded, color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}
