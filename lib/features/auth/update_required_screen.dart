import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/line_illustration.dart';

/// النسخة دي أقدم من أقل نسخة الخادم بيخدمها: الصفحة دي بتفتح مكان التطبيق كله لحد ما يتحدّث.
/// نفس شكل صفحة «حسابك موقوف».
class UpdateRequiredScreen extends StatelessWidget {
  /// صفحة التطبيق في المتجر، من إعدادات الخادم
  final String? updateUrl;

  const UpdateRequiredScreen({super.key, this.updateUrl});

  Future<void> _openStore() async {
    final uri = Uri.tryParse(updateUrl ?? '');
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const LineIllustration(icon: Icons.system_update_rounded, height: 110),
                const SizedBox(height: 20),
                const Text(
                  'حدّث التطبيق',
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
                  'نزّلنا نسخة جديدة فيها تحسينات مهمة\nحدّث التطبيق عشان تكمّل',
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
                if (updateUrl != null && updateUrl!.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  AppButton.primary(text: 'حدّث دلوقتي', icon: Icons.system_update_rounded, onPressed: _openStore),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
