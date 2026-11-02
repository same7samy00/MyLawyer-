import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';
import 'app_button.dart';

/// شرح إذن الموقع في الخلفية قبل نافذة النظام، ويظهر للمحامي مرة واحدة
class BackgroundLocationSheet extends StatelessWidget {
  const BackgroundLocationSheet({super.key});

  static const String _prefAsked = 'background_location_asked';

  static Future<void> showIfNeeded(BuildContext context) async {
    final permission = await Geolocator.checkPermission();
    final prefs = await SharedPreferences.getInstance();
    if (permission != LocationPermission.whileInUse || prefs.getBool(_prefAsked) == true) return;
    await prefs.setBool(_prefAsked, true);
    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (context) => const BackgroundLocationSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(4.0),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'خليك ظاهر من غير ما تفتح التطبيق',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'AppFont',
                fontFamilyFallback: appFontFallback,
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: AppColors.dark,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'طول ما أنت «متاح»، التطبيق بياخد موقعك كل فترة حتى وهو مقفول، عشان تفضل ظاهر للموكلين القريبين. لما تقفل «متاح»، الموقع بيقف. من فضلك اختار «السماح طول الوقت».',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'AppFont',
                fontFamilyFallback: appFontFallback,
                fontSize: 13,
                height: 1.5,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 18),
            AppButton.primary(
              text: 'متابعة',
              height: 48,
              onPressed: () async {
                final navigator = Navigator.of(context);
                await Geolocator.requestPermission();
                navigator.pop();
              },
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'مش دلوقتي',
                style: TextStyle(
                  fontFamily: 'AppFont',
                  fontFamilyFallback: appFontFallback,
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
