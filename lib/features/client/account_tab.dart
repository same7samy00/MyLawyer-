import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_pressable.dart';
import '../../core/widgets/logout_confirmation_sheet.dart';
import '../auth/session_router.dart';

class AccountTab extends StatefulWidget {
  const AccountTab({super.key});

  @override
  State<AccountTab> createState() => _AccountTabState();
}

class _AccountTabState extends State<AccountTab> {
  String _userPhone = '';

  @override
  void initState() {
    super.initState();
    _loadUserPhone();
  }

  Future<void> _loadUserPhone() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('user_phone');
    if (phone != null && mounted) {
      setState(() {
        _userPhone = phone;
      });
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
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(7.0),
                    ),
                    child: const Icon(Icons.person_rounded, color: AppColors.primary, size: 30),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'عميل المنصة',
                          style: TextStyle(
                            fontFamily: 'AppFont',
                            fontFamilyFallback: appFontFallback,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.dark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _userPhone,
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
              onTap: () {},
            ),
            _buildSettingItem(
              title: 'تغيير كلمة المرور',
              icon: Icons.lock_reset_rounded,
              onTap: () {},
            ),
            _buildSettingItem(
              title: 'مركز المساعدة والدعم الفني',
              icon: Icons.headset_mic_outlined,
              onTap: () {},
            ),
            _buildSettingItem(
              title: 'الشروط والأحكام وسياسة الخصوصية',
              icon: Icons.verified_user_outlined,
              onTap: () {},
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
