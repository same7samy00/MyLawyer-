import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/biometric_service.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/line_illustration.dart';

/// صفحة لوحدها بعد أول دخول بالباسورد: تفعيل الدخول بالبصمة أو «مش دلوقتي»
class BiometricSetupScreen extends StatefulWidget {
  final String identifier;
  final String password;
  final VoidCallback onDone;

  const BiometricSetupScreen({super.key, required this.identifier, required this.password, required this.onDone});

  @override
  State<BiometricSetupScreen> createState() => _BiometricSetupScreenState();
}

class _BiometricSetupScreenState extends State<BiometricSetupScreen> {
  String? _error;

  Future<void> _enable() async {
    setState(() => _error = null);
    final ok = await BiometricService.enable(widget.identifier, widget.password);
    if (!mounted) return;
    if (!ok) {
      setState(() => _error = 'ما اتأكدتش البصمة\nجرّب تاني أو اختار «مش دلوقتي»');
      return;
    }
    widget.onDone();
  }

  Future<void> _skip() async {
    await BiometricService.markAsked(widget.identifier);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    const body = TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 14, height: 1.6, fontWeight: FontWeight.w600, color: AppColors.textMuted);
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                const Center(child: LineIllustration(icon: Icons.fingerprint_rounded, height: 120)),
                const SizedBox(height: 24),
                const Text(
                  'ادخل أسرع بالبصمة',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.dark),
                ),
                const SizedBox(height: 10),
                const Text(
                  'المرة الجاية افتح حسابك بلمسة واحدة\nمن غير ما تكتب الباسورد',
                  textAlign: TextAlign.center,
                  style: body,
                ),
                const SizedBox(height: 18),
                const _Point(icon: Icons.lock_rounded, text: 'بياناتك بتتحفظ مشفرة على موبايلك بس'),
                const _Point(icon: Icons.toggle_on_rounded, text: 'تقدر تقفلها في أي وقت من حسابك'),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, textAlign: TextAlign.center, style: body.copyWith(color: AppColors.danger, fontSize: 13)),
                ],
                const Spacer(),
                AppButton.primary(text: 'فعّل البصمة', icon: Icons.fingerprint_rounded, height: 50, onPressed: _enable),
                const SizedBox(height: 10),
                AppButton.outlined(text: 'مش دلوقتي', height: 48, onPressed: _skip),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Point extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Point({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.dark)),
          ),
        ],
      ),
    );
  }
}
