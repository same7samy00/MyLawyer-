import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/auth_service.dart';
import '../../core/widgets/app_button.dart';
import 'session_router.dart';

/// تظهر عند تعذر التحقق من جلسة محفوظة بسبب الاتصال
/// الجلسة تبقى محفوظة، ولا تُعرض أي بيانات قديمة كأنها حالية
class ConnectionRetryScreen extends StatefulWidget {
  final String? message;

  const ConnectionRetryScreen({super.key, this.message});

  @override
  State<ConnectionRetryScreen> createState() => _ConnectionRetryScreenState();
}

class _ConnectionRetryScreenState extends State<ConnectionRetryScreen> {
  String? _message;

  @override
  void initState() {
    super.initState();
    _message = widget.message;
  }

  Future<void> _retry() async {
    final navigator = Navigator.of(context);
    final check = await AuthService.restoreSession();
    if (!mounted) return;

    if (check.status == SessionStatus.serverUnreachable) {
      setState(() => _message = check.message);
      return;
    }
    await SessionRouter.openSession(navigator, check);
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
              const Icon(Icons.wifi_off_rounded, size: 64, color: AppColors.textMuted),
              const SizedBox(height: 20),
              const Text(
                'تعذر الاتصال بالخادم',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'AppFont',
                  fontFamilyFallback: appFontFallback,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.dark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _message ?? 'تعذر الاتصال بالخادم، يرجى التأكد من اتصال الإنترنت.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'AppFont',
                  fontFamilyFallback: appFontFallback,
                  fontSize: 13,
                  height: 1.5,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'حسابك آمن ولم يتم تسجيل خروجك.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'AppFont',
                  fontFamilyFallback: appFontFallback,
                  fontSize: 12,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 28),
              AppButton.primary(
                text: 'إعادة المحاولة',
                icon: Icons.refresh_rounded,
                onPressed: _retry,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
