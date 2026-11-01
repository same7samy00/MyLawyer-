import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/device_permission_service.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_pressable.dart';
import 'session_router.dart';

/// تظهر مرة واحدة عند أول فتح للتطبيق وتشرح الأذونات قبل نوافذ النظام
class AppPermissionsScreen extends StatelessWidget {
  final SessionCheck check;

  const AppPermissionsScreen({super.key, required this.check});

  Future<void> _allow(BuildContext context) async {
    final navigator = Navigator.of(context);
    await DevicePermissionService.instance.requestInitialPermissions();
    await SessionRouter.openSession(navigator, check);
  }

  Future<void> _later(BuildContext context) async {
    final navigator = Navigator.of(context);
    await DevicePermissionService.instance.markInitialPermissionsRequested();
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Text(
                'عشان كل حاجة تشتغل معاك',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'AppFont',
                  fontFamilyFallback: appFontFallback,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.dark,
                ),
              ),
              const SizedBox(height: 28),
              const _PermissionRow(
                icon: Icons.location_on_rounded,
                title: 'الموقع',
                body: 'عشان نوصلك بأقرب محامي ونحدد وصوله ليك',
              ),
              const SizedBox(height: 16),
              const _PermissionRow(
                icon: Icons.notifications_rounded,
                title: 'الإشعارات',
                body: 'عشان توصلك الطلبات والردود فوراً حتى والتطبيق مقفول',
              ),
              const Spacer(),
              AppButton.primary(
                text: 'السماح والمتابعة',
                height: 52,
                onPressed: () => _allow(context),
              ),
              const SizedBox(height: 12),
              AppPressable(
                child: TextButton(
                  onPressed: () => _later(context),
                  child: const Text(
                    'لاحقاً',
                    style: TextStyle(
                      fontFamily: 'AppFont',
                      fontFamilyFallback: appFontFallback,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _PermissionRow({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(7.0),
          ),
          child: Icon(icon, color: AppColors.primary, size: 23),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'AppFont',
                  fontFamilyFallback: appFontFallback,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.dark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                body,
                style: const TextStyle(
                  fontFamily: 'AppFont',
                  fontFamilyFallback: appFontFallback,
                  fontSize: 12,
                  height: 1.4,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
