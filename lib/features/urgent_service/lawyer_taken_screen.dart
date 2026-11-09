import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/line_illustration.dart';

/// الموكل كان رايح يدفع، وموكل تاني دفع للمحامي ده قبله. مفيش فلوس اتخصمت، وبيرجع لنفس العروض.
/// ولو مهلة الدفع خلصت ([expired])، الطلب اتقفل ويقدر يطلب تاني
class LawyerTakenScreen extends StatelessWidget {
  final bool expired;

  const LawyerTakenScreen({super.key, this.expired = false});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(true);
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const Spacer(),
                IllustrationBadge(icon: expired ? Icons.timer_off_rounded : Icons.person_search_rounded, size: 96),
                const SizedBox(height: 28),
                Text(
                  expired ? 'مهلة الدفع خلصت' : 'المحامي ده اتشغل',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.dark),
                ),
                const SizedBox(height: 12),
                Text(
                  expired
                      ? 'الطلب اتقفل لأن الدفع ما اكتملش في 10 دقايق\nما اتخصمش منك أي فلوس، وتقدر تطلب تاني'
                      : 'موكل تاني دفع له قبلك بلحظات\nما اتخصمش منك أي فلوس، وعروض باقي المحامين لسه قدامك',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 14, height: 1.7, color: AppColors.textMuted),
                ),
                const Spacer(),
                AppButton.primary(
                  text: expired ? 'رجوع' : 'شوف باقي العروض',
                  onPressed: () => Navigator.of(context).pop(true),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
