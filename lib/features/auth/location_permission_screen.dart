import '../../core/widgets/line_illustration.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_pressable.dart';
import '../../core/services/location_service.dart';
import '../../core/widgets/app_button.dart';
import '../client/main_navigation_shell.dart';
import '../client/nearby_lawyers_showcase_screen.dart';
import '../lawyer/lawyer_navigation_shell.dart';
import 'session_router.dart';

class LocationPermissionScreen extends StatefulWidget {
  final bool forLawyer;

  const LocationPermissionScreen({super.key, this.forLawyer = false});

  @override
  State<LocationPermissionScreen> createState() => _LocationPermissionScreenState();
}

class _LocationPermissionScreenState extends State<LocationPermissionScreen> {
  Future<void> _handleProceed() async {
    // Check / request location permission via official native OS dialog
    final result = await LocationService.instance.checkAndRequestPermission();

    if (!mounted) return;

    if (result.status == LocationServiceStatus.permissionDeniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'إذن الموقع معطل نهائياً من إعدادات الجهاز. يمكنك تفعيله من الإعدادات.',
            style: TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback),
          ),
          action: SnackBarAction(
            label: 'الإعدادات',
            textColor: Colors.white,
            onPressed: () => LocationService.instance.openAppSettings(),
          ),
          backgroundColor: AppColors.dark,
          duration: const Duration(seconds: 4),
        ),
      );
    }

    if (widget.forLawyer) {
      _openLawyerHome();
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const NearbyLawyersShowcaseScreen()),
    );
  }

  void _openLawyerHome() {
    SessionRouter.replaceStack(Navigator.of(context), const LawyerNavigationShell());
  }

  void _handleLater() {
    if (widget.forLawyer) {
      _openLawyerHome();
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const MainNavigationShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Main Illustration & Content
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Undraw Finding the way SVG مع RepaintBoundary لتحسين أداء التمرير
                        // الخط يمر خلف الرسمة من حافة الشاشة إلى الحافة الأخرى
                        RepaintBoundary(
                          child: SizedBox(
                            width: double.infinity,
                            height: 110,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                const LineIllustration(icon: Icons.location_on_rounded, height: 110),
                                if (ModalRoute.of(context)?.canPop ?? false)
                                  PositionedDirectional(
                                    start: 8,
                                    top: 0,
                                    child: AppPressable(
                                      child: IconButton(
                                        icon: const Icon(Icons.arrow_back_rounded, color: AppColors.dark),
                                        onPressed: () => Navigator.of(context).maybePop(),
                                        tooltip: 'رجوع',
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Concise direct text on screen (Two lines)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40.0),
                          child: Text(
                            widget.forLawyer
                                ? 'محتاجين نحدد موقعك\nعشان توصلك طلبات الموكلين القريبين منك'
                                : 'محتاجين نحدد موقعك\nعشان نوفرلك أقرب محامي ليك',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'AppFont',
                              fontFamilyFallback: appFontFallback,
                              fontSize: 19,
                              height: 1.4,
                              fontWeight: FontWeight.w700,
                              color: AppColors.dark,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Subtle security indicator
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shield_outlined, size: 15, color: AppColors.textMuted),
                            SizedBox(width: 6),
                            Text(
                              'موقعك مؤمّن بالكامل ومشفر للخدمة فقط',
                              style: TextStyle(
                                fontFamily: 'AppFont',
                                fontFamilyFallback: appFontFallback,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom Action Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppButton.primary(
                    text: 'تحديد موقعي الآن',
                    icon: Icons.location_on_rounded,
                    onPressed: _handleProceed,
                    height: 52,
                  ),
                  const SizedBox(height: 12),
                  // Button: "سأقوم بتحديده لاحقاً" redirects to Home (MainNavigationShell)
                  AppPressable(
                    child: TextButton(
                    onPressed: _handleLater,
                    child: const Text(
                      'سأقوم بتحديده لاحقاً',
                      style: TextStyle(
                        fontFamily: 'AppFont',
                        fontFamilyFallback: appFontFallback,
                        fontSize: 14,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ),
                ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
