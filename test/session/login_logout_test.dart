import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_lawyer/core/services/api_service.dart';
import 'package:my_lawyer/core/services/auth_service.dart';
import 'package:my_lawyer/features/auth/email_verification_screen.dart';
import 'package:my_lawyer/features/auth/forgot_password_screen.dart';
import 'package:my_lawyer/features/auth/login_screen.dart';
import 'package:my_lawyer/features/auth/session_router.dart';
import 'package:my_lawyer/features/client/account_tab.dart';
import 'package:my_lawyer/features/client/main_navigation_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/session_test_helpers.dart';

void main() {
  setUpSessionTests();

  group('تسجيل الدخول والخروج', () {
    testWidgets('تذكر بياناتي معطل: الجلسة في الذاكرة فقط والموجّه يعرف نوع الحساب', (tester) async {
      backend.account = lawyerAccount();
      await AuthService.loginUser(identifier: '01123456789', password: 'Password1', rememberMe: false);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(ApiService.prefRefreshToken), isNull);
      expect(await ApiService.getRefreshToken(), 'refresh-token');
      expect((await AuthService.currentSession()).status, SessionStatus.lawyerApproved);
    });

    testWidgets('حساب لم يؤكد بريده: يكمل التحقق بدل رسالة خطأ ولا يدخل الصفحات المحمية', (tester) async {
      backend.overrides['POST /auth/login'] = (_) => FakeBackend.json(403, {
            'success': false,
            'error': 'يرجى تأكيد بريدك الإلكتروني أولاً لتفعيل حسابك',
            'data': {'status': 'pending_email_verification', 'email': 'new@example.com'},
          });

      await tester.pumpWidget(testApp(const LoginScreen()));
      await tester.enterText(find.byType(TextFormField).at(0), '01012345678');
      await tester.enterText(find.byType(TextFormField).at(1), 'Password1');
      await tester.tap(find.text('تسجيل الدخول'));
      await tester.pumpAndSettle();

      expect(find.byType(EmailVerificationScreen), findsOneWidget);
      expect(backend.countOf('POST /auth/resend-otp'), 1);
    });

    testWidgets('رقم الحساب يبقى بعد الخروج ويظهر جاهزاً في خانة معطلة', (tester) async {
      SharedPreferences.setMockInitialValues(savedSession({'login_phone': '01012345678'}));
      await AuthService.clearLocalSession();

      await tester.pumpWidget(testApp(const LoginScreen()));
      await tester.pumpAndSettle();

      final phoneField = tester.widget<TextFormField>(find.byType(TextFormField).at(0));
      expect(phoneField.enabled, isFalse);
      expect(phoneField.controller!.text, '01012345678');
      expect(tester.widget<TextFormField>(find.byType(TextFormField).at(1)).enabled, isTrue);
    });

    testWidgets('زر الخروج: إنهاء الجلسة على الخادم ومسحها ومنع الرجوع للصفحات المحمية', (tester) async {
      SharedPreferences.setMockInitialValues(savedSession({'user_phone': '01012345678'}));
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(testApp(
        const MainNavigationShell(initialIndex: 3),
        navigatorKey: navigatorKey,
      ),);
      await tester.pumpAndSettle();
      expect(find.byType(AccountTab), findsOneWidget);

      await tester.tap(find.text('تسجيل الخروج'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تأكيد تسجيل الخروج'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(backend.countOf('POST /auth/logout'), 1);
      expect(navigatorKey.currentState!.canPop(), isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), isEmpty);
      expect(await ApiService.getAccessToken(), isNull);
    });

    testWidgets('الخروج بلا إنترنت ينهي الجلسة محلياً ويعود للدخول', (tester) async {
      SharedPreferences.setMockInitialValues(savedSession());
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(testApp(const SizedBox.shrink(), navigatorKey: navigatorKey));
      backend.isOffline = true;

      await SessionRouter.signOut(navigatorKey.currentState!);
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(await ApiService.getRefreshToken(), isNull);
    });

    testWidgets('استعادة كلمة المرور: طلب الرمز ثم التعيين ثم العودة للدخول برسالة نجاح', (tester) async {
      backend.overrides['POST /auth/forgot-password'] = (_) => FakeBackend.json(200, {
            'success': true,
            'message': 'إذا كان البريد الإلكتروني مسجلاً، فقد تم إرسال رمز التحقق إليه.',
          });
      backend.overrides['POST /auth/reset-password'] = (_) => FakeBackend.json(200, {
            'success': true,
            'message': 'تم تغيير كلمة المرور بنجاح.',
          });

      await tester.pumpWidget(testApp(const LoginScreen()));
      await tester.tap(find.text('نسيت كلمة المرور؟'));
      await tester.pumpAndSettle();
      expect(find.byType(ForgotPasswordScreen), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), 'client@example.com');
      await tester.tap(find.text('إرسال رمز الاستعادة'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), '654321');
      await tester.enterText(find.byType(TextFormField).at(1), 'NewPass@2026');
      await tester.pump();
      await tester.tap(find.text('تعيين كلمة المرور'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('تم تغيير كلمة المرور بنجاح.'), findsOneWidget);
    });

    testWidgets('إنشاء حساب: رمز رفضه الخادم لا يفتح الحساب حتى لو كان 123456', (tester) async {
      backend.overrides['POST /auth/verify-otp'] = (_) => FakeBackend.json(400, {
            'success': false,
            'error': 'رمز التحقق غير صحيح، يرجى المحاولة مرة أخرى',
          });

      const registration = RegistrationData(
        accountType: UserAccountType.client,
        fullName: 'أحمد محمود',
        phone: '01012345678',
        email: 'ahmed@example.com',
        password: 'Password1',
      );

      final result = await AuthService.verifyEmailCode(registration: registration, inputCode: '123456');

      expect(result.success, isFalse);
      expect(backend.countOf('POST /auth/login'), 0);
      expect(await ApiService.getAccessToken(), isNull);
    });

    test('فشل الاتصال أثناء إنشاء الحساب لا يعتبر نجاحاً', () async {
      backend.isOffline = true;
      const registration = RegistrationData(
        accountType: UserAccountType.client,
        fullName: 'أحمد محمود',
        phone: '01012345678',
        email: 'ahmed@example.com',
        password: 'Password1',
      );

      final result = await AuthService.registerUser(registration);

      expect(result.success, isFalse);
    });

    test('تفعيل البريد بنجاح يفتح جلسة حقيقية من الخادم', () async {
      backend.overrides['POST /auth/verify-otp'] = (_) => FakeBackend.json(200, {'success': true});
      const registration = RegistrationData(
        accountType: UserAccountType.client,
        fullName: 'أحمد محمود',
        phone: '01012345678',
        email: 'ahmed@example.com',
        password: 'Password1',
      );

      final result = await AuthService.verifyEmailCode(registration: registration, inputCode: '654321');

      expect(result.success, isTrue);
      expect(result.data?['sessionOpened'], isTrue);
      expect(await ApiService.getAccessToken(), 'access-token');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('user_name'), 'أحمد محمود');
    });
  });
}
