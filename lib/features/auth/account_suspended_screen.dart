import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/auth_service.dart';
import '../../core/widgets/app_button.dart';
import 'session_router.dart';

/// شاشة الحساب الموقوف: تقفل التطبيق كله لحد ما الإدارة تفعل الحساب
class AccountSuspendedScreen extends StatefulWidget {
  /// جاي من تسجيل الدخول ومفيش جلسة، فمفيش حاجة تتراجع تلقائياً
  final bool hasSession;

  const AccountSuspendedScreen({super.key, this.hasSession = true});

  @override
  State<AccountSuspendedScreen> createState() => _AccountSuspendedScreenState();
}

class _AccountSuspendedScreenState extends State<AccountSuspendedScreen> {
  Timer? _timer;
  bool _isChecking = false;
  String? _notice;

  @override
  void initState() {
    super.initState();
    // التفعيل من الإدارة يفتح التطبيق من غير ما يضغط حاجة
    if (widget.hasSession) {
      _timer = Timer.periodic(const Duration(seconds: 30), (_) => _check());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    SessionRouter.onSuspendedScreenClosed();
    super.dispose();
  }

  Future<void> _check({bool showResult = false}) async {
    if (_isChecking) return;
    _isChecking = true;
    final navigator = Navigator.of(context);

    final check = await AuthService.restoreSession();
    _isChecking = false;
    if (!mounted) return;

    if (check.status == SessionStatus.accountSuspended) {
      if (showResult) setState(() => _notice = 'الحساب لسه موقوف');
      return;
    }
    if (check.status == SessionStatus.serverUnreachable) {
      if (showResult) setState(() => _notice = check.message);
      return;
    }
    await SessionRouter.openSession(navigator, check);
  }

  Future<void> _signOut() async {
    await SessionRouter.signOut(Navigator.of(context));
  }

  void _backToLogin() {
    SessionRouter.toLogin(Navigator.of(context));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.gpp_bad_rounded, size: 72, color: AppColors.danger),
              const SizedBox(height: 20),
              const Text(
                'حسابك موقوف',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'AppFont',
                  fontFamilyFallback: appFontFallback,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  color: AppColors.dark,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'إدارة التطبيق أوقفت حسابك، ومش هتقدر تستخدم التطبيق لحد ما الحساب يتفعل تاني.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'AppFont',
                  fontFamilyFallback: appFontFallback,
                  fontSize: 13,
                  height: 1.5,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (_notice != null) ...[
                const SizedBox(height: 12),
                Text(
                  _notice!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'AppFont',
                    fontFamilyFallback: appFontFallback,
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 28),
              if (widget.hasSession) ...[
                AppButton.primary(
                  text: 'تحديث حالة الحساب',
                  icon: Icons.refresh_rounded,
                  onPressed: () => _check(showResult: true),
                ),
                const SizedBox(height: 10),
                AppButton.outlined(text: 'تسجيل الخروج', onPressed: _signOut),
              ] else
                AppButton.outlined(text: 'رجوع لتسجيل الدخول', onPressed: _backToLogin),
            ],
          ),
        ),
      ),
    );
  }
}
