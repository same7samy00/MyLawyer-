import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/auth_service.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/line_illustration.dart';
import 'session_router.dart';

/// صفحة نجاح إنشاء الحساب مع العد التنازلي التلقائي لمدة 3 ثوانٍ
class RegistrationSuccessScreen extends StatefulWidget {
  final RegistrationData registrationData;

  const RegistrationSuccessScreen({
    super.key,
    required this.registrationData,
  });

  @override
  State<RegistrationSuccessScreen> createState() => _RegistrationSuccessScreenState();
}

class _RegistrationSuccessScreenState extends State<RegistrationSuccessScreen> {
  static const int _totalCountdownSeconds = 3;
  int _secondsLeft = _totalCountdownSeconds;
  Timer? _timer;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsLeft <= 1) {
        timer.cancel();
        _proceedToNext();
      } else {
        setState(() {
          _secondsLeft--;
        });
      }
    });
  }

  void _proceedToNext() {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    _timer?.cancel();

    // التوجيه الذكي وفقاً لنوع الحساب وحالة اعتماده على الخادم
    SessionRouter.openCurrentAccount(Navigator.of(context));
  }

  @override
  Widget build(BuildContext context) {
    final firstName = widget.registrationData.firstName;
    final isLawyer = widget.registrationData.accountType == UserAccountType.lawyer;

    return PopScope(
      canPop: false, // منع الرجوع لمنع تكرار شاشة التسجيل
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),

                // الرسم التوضيحي للنجاح
                const Center(
                  child: LineIllustration(icon: Icons.verified_rounded, height: 110),
                ),

                const SizedBox(height: 28),

                // الترحيب بالاسم الأول
                Text(
                  firstName.isEmpty ? 'أهلاً بك' : 'أهلاً $firstName',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'AppFont',
                    fontFamilyFallback: appFontFallback,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: AppColors.dark,
                  ),
                ),

                const SizedBox(height: 8),

                // رسالة تأكيد النجاح المباشرة
                const Text(
                  'تم إنشاء حسابك بنجاح',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'AppFont',
                    fontFamilyFallback: appFontFallback,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.success,
                  ),
                ),

                const SizedBox(height: 12),

                // رسالة توضيحية خفيفة
                Text(
                  isLawyer
                      ? 'تم تسجيل بياناتك المهنية بنجاح، جاري مراجعة الكارنيه وتفعيل الصلاحيات الكاملة'
                      : 'أصبح حسابك جاهزاً الآن للاستفادة من كافة الخدمات والاستشارات القانونية',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'AppFont',
                    fontFamilyFallback: appFontFallback,
                    fontSize: 13,
                    color: AppColors.textMuted,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 32),

                // مؤشر العد التنازلي المرئي (3 ثوانٍ)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const AppLoader.inline(size: 16),
                        const SizedBox(width: 10),
                        Text(
                          'سيتم توجيهك تلقائياً خلال $_secondsLeft ثوانٍ',
                          style: const TextStyle(
                            fontFamily: 'AppFont',
                            fontFamilyFallback: appFontFallback,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                // زر المتابعة الفورية اليدوي 12.0px
                AppButton.primary(
                  text: 'المتابعة الآن',
                  onPressed: _proceedToNext,
                ),

                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

