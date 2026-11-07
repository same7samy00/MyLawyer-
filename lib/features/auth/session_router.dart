import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/background_location_service.dart';
import '../../core/services/device_permission_service.dart';
import '../client/main_navigation_shell.dart';
import '../client/nearby_lawyers_showcase_screen.dart';
import '../lawyer/lawyer_navigation_shell.dart';
import 'account_suspended_screen.dart';
import 'connection_retry_screen.dart';
import 'lawyer_approval_status_screen.dart';
import 'location_permission_screen.dart';
import 'login_screen.dart';

/// المرجع الوحيد لتوجيه المستخدم حسب جلسته ونوع حسابه
/// كل انتقال بين الدخول والخروج يمسح المكدس حتى لا يعود الرجوع لصفحات غير منطقية
class SessionRouter {
  SessionRouter._();

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static bool _isHandlingExpiry = false;
  static bool _isSuspendedScreenOpen = false;

  static bool showPromoMap = true;

  /// الشاشة الصحيحة لحالة الجلسة
  static Future<Widget> screenFor(SessionCheck check) async {
    switch (check.status) {
      case SessionStatus.client:
        final hasLocation = await DevicePermissionService.instance.isLocationPermissionGranted();
        // الإذن متاح من قبل: مفيش داعي لصفحة «محتاجين نحدد موقعك»
        final locationDone = hasLocation || await DevicePermissionService.instance.isLocationScreenDone();
        if (!locationDone) return const LocationPermissionScreen();
        // أي حساب بيبدأ كل فتحة بالخريطة الترويجية، والإشعار اللي لمسه بيتفتح بعد ما يقفلها
        return showPromoMap ? const NearbyLawyersShowcaseScreen() : const MainNavigationShell();
      case SessionStatus.lawyerApproved:
        return await DevicePermissionService.instance.isLocationPermissionGranted() ||
                await DevicePermissionService.instance.isLocationScreenDone()
            ? (showPromoMap ? const NearbyLawyersShowcaseScreen(forLawyer: true) : const LawyerNavigationShell())
            : const LocationPermissionScreen(forLawyer: true);
      case SessionStatus.lawyerPending:
        return const LawyerApprovalStatusScreen(isRejected: false);
      case SessionStatus.lawyerRejected:
        return const LawyerApprovalStatusScreen(isRejected: true);
      case SessionStatus.accountSuspended:
        return const AccountSuspendedScreen();
      case SessionStatus.serverUnreachable:
        return ConnectionRetryScreen(message: check.message);
      case SessionStatus.unauthenticated:
      case SessionStatus.expired:
      case SessionStatus.accountBlocked:
        return LoginScreen(initialMessage: check.message);
    }
  }

  /// فتح وجهة الجلسة مع مسح كل ما قبلها من المكدس
  static Future<void> openSession(NavigatorState navigator, SessionCheck check) async {
    final screen = await screenFor(check);
    await replaceStack(navigator, screen);
  }

  /// فتح وجهة الحساب بعد تسجيل دخول ناجح
  static Future<void> openCurrentAccount(NavigatorState navigator) async {
    await openSession(navigator, await AuthService.currentSession());
  }

  /// لا تنتظر استدعاءات هذه الدالة عودة المستخدم، فهي تنتهي مع بدء الانتقال
  static Future<void> replaceStack(NavigatorState navigator, Widget screen) async {
    navigator.pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (context) => screen),
      (route) => false,
    );
  }

  static Future<void> toLogin(NavigatorState navigator, {String? message}) {
    return replaceStack(navigator, LoginScreen(initialMessage: message));
  }

  /// إنهاء الجلسة وإغلاق كل الصفحات المحمية
  static Future<void> signOut(NavigatorState navigator) async {
    await AuthService.logout();
    await toLogin(navigator);
  }

  /// يستدعيها ApiService لما الخادم يرفض الحساب، فكل الصفحات تتقفل
  static Future<void> handleAccountSuspended() async {
    final navigator = navigatorKey.currentState;
    if (_isSuspendedScreenOpen || navigator == null) return;

    _isSuspendedScreenOpen = true;
    unawaited(BackgroundLocationService.stopAll());
    await replaceStack(navigator, const AccountSuspendedScreen());
  }

  static void onSuspendedScreenClosed() {
    _isSuspendedScreenOpen = false;
  }

  /// يستدعيها ApiService عند ثبوت انتهاء الجلسة أثناء الاستخدام
  static Future<void> handleSessionExpired() async {
    if (_isHandlingExpiry) return;
    _isHandlingExpiry = true;
    try {
      await AuthService.clearLocalSession();
      final navigator = navigatorKey.currentState;
      if (navigator != null) {
        await toLogin(navigator, message: 'انتهت جلستك، يرجى تسجيل الدخول مرة أخرى');
      }
    } finally {
      _isHandlingExpiry = false;
    }
  }
}
