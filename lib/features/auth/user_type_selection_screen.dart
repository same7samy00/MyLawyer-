import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_pressable.dart';
import '../../core/widgets/auth_hero_header.dart';
import 'client_register_screen.dart';
import 'lawyer_register_screen.dart';

/// شاشة اختيار نوع الحساب (موكل أم محامي)
class UserTypeSelectionScreen extends StatelessWidget {
  const UserTypeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            AuthHeroHeader(
              title: 'إنشــاء حســاب جديد',
              description: 'اختر نوع حسابك لتخصيص تجربتك القانونية\nوالوصول إلى كافة الخدمات المناسبة لك',
              onBack: () => Navigator.of(context).pop(),
            ),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [

                    // بطاقة اختيار 1: أنت موكل
                    _buildAccountTypeCard(
                      context: context,
                      title: 'أنت مــوكل',
                      subtitle: 'استشارات وعقود وتوكيل محامٍ معتمد ومتابعة قضاياك بأمان',
                      badgeText: 'أفراد وشركات',
                      icon: Icons.verified_user_rounded,
                      accentColor: AppColors.primary,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const ClientRegisterScreen(),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 18),

                    // بطاقة اختيار 2: أنت محامي
                    _buildAccountTypeCard(
                      context: context,
                      title: 'أنت محــامي',
                      subtitle: 'انضم لمنصة المحامين واستقبل طلبات الموكلين',
                      badgeText: 'مقيد بنقابة المحامين',
                      icon: Icons.shield_rounded,
                      accentColor: const Color(0xFF0D9488), // لون مميز وقور
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const LawyerRegisterScreen(),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 36),

                    // خيار العودة لتسجيل الدخول
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'لديك حساب بالفعل؟',
                          style: TextStyle(
                            fontFamily: 'AppFont',
                            fontFamilyFallback: appFontFallback,
                            fontSize: 14,
                            color: AppColors.textMuted,
                          ),
                        ),
                        AppPressable(
                          child: TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          style: TextButton.styleFrom(
                            overlayColor: Colors.transparent,
                            foregroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                          ),
                          child: const Text(
                            'تسجيل الدخول',
                            style: TextStyle(
                              fontFamily: 'AppFont',
                              fontFamilyFallback: appFontFallback,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// كرت نوع الحساب بأسلوب Minimal UI مع حدود متقطعة هادئة
  Widget _buildAccountTypeCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String badgeText,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return AppCard(
      isDashed: true,
      onTap: onTap,
      padding: const EdgeInsets.all(20.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // أيقونة النوع بدون إطار مربع مزعج
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Icon(
              icon,
              color: accentColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),

          // تفاصيل الخيار
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'AppFont',
                        fontFamilyFallback: appFontFallback,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.dark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '• $badgeText',
                      style: TextStyle(
                        fontFamily: 'AppFont',
                        fontFamilyFallback: appFontFallback,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily: 'AppFont',
                    fontFamilyFallback: appFontFallback,
                    fontSize: 13,
                    height: 1.45,
                    color: AppColors.textMain,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),
          // مؤشر السهم
          const Padding(
            padding: EdgeInsets.only(top: 14.0),
            child: Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

