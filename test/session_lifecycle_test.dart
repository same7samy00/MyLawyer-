import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_lawyer/core/config/app_config.dart';
import 'package:my_lawyer/core/services/api_service.dart';
import 'package:my_lawyer/core/services/auth_service.dart';
import 'package:my_lawyer/core/theme/app_theme.dart';
import 'package:my_lawyer/core/widgets/app_card.dart';
import 'package:my_lawyer/core/widgets/connection_gate.dart';
import 'package:my_lawyer/data/models/order_model.dart';
import 'package:my_lawyer/features/client/account_tab.dart';
import 'package:my_lawyer/features/lawyer/lawyer_orders_tab.dart';
import 'package:my_lawyer/features/auth/connection_retry_screen.dart';
import 'package:my_lawyer/features/auth/email_verification_screen.dart';
import 'package:my_lawyer/features/auth/forgot_password_screen.dart';
import 'package:my_lawyer/features/auth/lawyer_approval_status_screen.dart';
import 'package:my_lawyer/features/lawyer/lawyer_navigation_shell.dart';
import 'package:my_lawyer/features/auth/location_permission_screen.dart';
import 'package:my_lawyer/features/auth/login_screen.dart';
import 'package:my_lawyer/features/client/main_navigation_shell.dart';
import 'package:my_lawyer/features/client/nearby_lawyers_showcase_screen.dart';
import 'package:my_lawyer/features/client/orders_tab.dart';
import 'package:my_lawyer/features/client/wallet_tab.dart';
import 'package:my_lawyer/features/support/support_screen.dart';
import 'package:my_lawyer/core/services/notification_center.dart';
import 'package:my_lawyer/features/urgent_service/payment_screen.dart';
import 'package:my_lawyer/features/urgent_service/payment_success_screen.dart';
import 'package:my_lawyer/features/auth/account_suspended_screen.dart';
import 'package:my_lawyer/features/auth/session_router.dart';
import 'package:my_lawyer/features/auth/splash_screen.dart';
import 'package:my_lawyer/features/urgent_service/tracking_screen.dart';
import 'package:my_lawyer/features/auth/user_type_selection_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_lawyer/features/notifications/notifications_screen.dart';
import 'helpers/fake_backend.dart';

Widget _app(Widget home, {GlobalKey<NavigatorState>? navigatorKey}) {
  return MaterialApp(
    navigatorKey: navigatorKey,
    theme: AppTheme.lightTheme,
    locale: const Locale('ar', 'EG'),
    supportedLocales: const [Locale('ar', 'EG')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: home,
  );
}

Map<String, Object> _savedSession([Map<String, Object> extra = const {}]) => {
      ApiService.prefAccessToken: 'stored-access',
      ApiService.prefRefreshToken: 'stored-refresh',
      ...extra,
    };

/// تشغيل التطبيق من الشاشة الافتتاحية حتى استقرار الوجهة
Future<void> _launch(WidgetTester tester) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('has_requested_initial_permissions', true);
  await tester.pumpWidget(_app(const SplashScreen()));
  await tester.pump(const Duration(milliseconds: 2700));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

/// تمرير الوقت على دفعات حتى تكتمل العمليات المتتابعة في الشاشات ذات الخرائط
/// يفتح صفحة تفاصيل الطلب الوحيد من صفحة الطلبات
Future<void> _openDetails(WidgetTester tester, {bool isLawyer = false}) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(Scaffold(body: isLawyer ? const LawyerOrdersTab() : const OrdersTab())));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('عرض التفاصيل'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('عرض التفاصيل'));
  await tester.pumpAndSettle();
}

Future<void> _settleAsync(WidgetTester tester) async {
  for (int i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
}

void main() {
  late FakeBackend backend;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/geolocator'),
      (call) async => call.method == 'checkPermission' ? 3 : throw MissingPluginException(),
    );
    backend = FakeBackend();
    ApiService.useHttpClient(backend.client);
  });

  group('فتح التطبيق وتوجيه الجلسة', () {
    testWidgets('بدون جلسة: مباشرة لتسجيل الدخول بلا أي طلب للخادم', (tester) async {
      await _launch(tester);

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(MainNavigationShell), findsNothing);
      expect(backend.calls, isEmpty);
    });

    testWidgets('علامة دخول قديمة بلا Tokens لا تفتح الصفحات المحمية', (tester) async {
      SharedPreferences.setMockInitialValues({'is_logged_in': true, 'user_account_type': 'client'});
      await _launch(tester);

      expect(find.byType(LoginScreen), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('is_logged_in'), isNull);
    });

    testWidgets('جلسة صالحة لموكل له موقع محفوظ: يدخل رئيسية الموكل بعد التحقق مع الخادم', (tester) async {
      SharedPreferences.setMockInitialValues(_savedSession({'user_location_name': 'المعادي، محافظة القاهرة'}));
      await _launch(tester);

      expect(find.byType(MainNavigationShell), findsOneWidget);
      expect(backend.countOf('GET /users/me'), greaterThanOrEqualTo(1));
    });

    testWidgets('جلسة موكل بدون موقع: يذهب لتحديد الموقع', (tester) async {
      SharedPreferences.setMockInitialValues(_savedSession());
      await _launch(tester);

      expect(find.byType(LocationPermissionScreen), findsOneWidget);
    });

    testWidgets('محامٍ معتمد: رئيسية المحامي', (tester) async {
      SharedPreferences.setMockInitialValues(_savedSession());
      backend.account = lawyerAccount();
      await _launch(tester);

      expect(find.byType(LawyerNavigationShell), findsOneWidget);
    });

    testWidgets('محامٍ قيد المراجعة: شاشة حالة الاعتماد دون الوصول للطلبات', (tester) async {
      SharedPreferences.setMockInitialValues(_savedSession());
      backend.account = lawyerAccount(status: 'pending_admin_approval', approvalStatus: 'pending');
      await _launch(tester);

      expect(find.byType(LawyerApprovalStatusScreen), findsOneWidget);
      expect(find.text('حسابك قيد المراجعة'), findsOneWidget);
      expect(find.byType(LawyerNavigationShell), findsNothing);
    });

    testWidgets('اعتماد المحامي أثناء الانتظار: تحديث الحالة يفتح واجهته', (tester) async {
      SharedPreferences.setMockInitialValues(_savedSession());
      backend.account = lawyerAccount(status: 'pending_admin_approval', approvalStatus: 'pending');
      await _launch(tester);

      backend.account = lawyerAccount();
      await tester.tap(find.text('تحديث حالة الحساب'));
      await tester.pumpAndSettle();

      expect(find.byType(LawyerNavigationShell), findsOneWidget);
    });

    testWidgets('محامٍ مرفوض: حالة واضحة مع إمكانية الخروج', (tester) async {
      SharedPreferences.setMockInitialValues(_savedSession());
      backend.account = lawyerAccount(status: 'rejected', approvalStatus: 'rejected');
      await _launch(tester);

      expect(find.text('لم يتم اعتماد حسابك'), findsOneWidget);

      await tester.tap(find.text('تسجيل الخروج'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(await ApiService.getRefreshToken(), isNull);
    });

    testWidgets('حساب موقوف: صفحة الإيقاف مع حفظ الجلسة والرجوع بعد التفعيل', (tester) async {
      SharedPreferences.setMockInitialValues(_savedSession());
      backend.overrides['GET /users/me'] = (_) => FakeBackend.json(403, {
            'success': false,
            'error': 'تم إيقاف هذا الحساب',
            'data': {'status': 'suspended'},
          });
      await _launch(tester);

      expect(find.byType(AccountSuspendedScreen), findsOneWidget);
      expect(await ApiService.getRefreshToken(), isNotNull);

      await tester.tap(find.text('تحديث حالة الحساب'));
      await _settleAsync(tester);
      expect(find.text('الحساب لسه موقوف'), findsOneWidget);

      backend.overrides.remove('GET /users/me');
      await tester.tap(find.text('تحديث حالة الحساب'));
      await _settleAsync(tester);
      expect(find.byType(AccountSuspendedScreen), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('انتهاء الجلسة وتجديدها', () {
    testWidgets('Access منتهٍ مع Refresh صالح: تجديد صامت ودخول طبيعي', (tester) async {
      SharedPreferences.setMockInitialValues(_savedSession({'user_location_name': 'المعادي'}));
      backend.overrides['GET /users/me'] = (request) {
        if (request.headers['Authorization'] == 'Bearer renewed-access') {
          return FakeBackend.json(200, {'success': true, 'data': clientAccount()});
        }
        return FakeBackend.json(401, {'success': false, 'error': 'غير مصرح'});
      };
      await _launch(tester);

      expect(find.byType(MainNavigationShell), findsOneWidget);
      expect(backend.countOf('POST /auth/refresh'), 1);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(ApiService.prefRefreshToken), 'renewed-refresh');
    });

    testWidgets('جلسة منتهية فعلياً: مسح بياناتها والعودة للدخول برسالة', (tester) async {
      SharedPreferences.setMockInitialValues(_savedSession({'user_phone': '01012345678'}));
      backend.overrides['GET /users/me'] = (_) => FakeBackend.json(401, {'success': false});
      backend.overrides['POST /auth/refresh'] = (_) => FakeBackend.json(401, {'success': false});
      await _launch(tester);

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('انتهت جلستك، يرجى تسجيل الدخول مرة أخرى.'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(ApiService.prefRefreshToken), isNull);
      expect(prefs.getString('user_phone'), isNull);
    });

    testWidgets('انتهاء الجلسة أثناء الاستخدام: إغلاق كل الصفحات والعودة للدخول', (tester) async {
      SharedPreferences.setMockInitialValues(_savedSession());
      ApiService.onSessionExpired = SessionRouter.handleSessionExpired;
      backend.overrides['GET /orders'] = (_) => FakeBackend.json(401, {'success': false});
      backend.overrides['POST /auth/refresh'] = (_) => FakeBackend.json(401, {'success': false});

      await tester.pumpWidget(_app(
        const Scaffold(body: OrdersTab()),
        navigatorKey: SessionRouter.navigatorKey,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(SessionRouter.navigatorKey.currentState!.canPop(), isFalse);
      expect(await ApiService.getAccessToken(), isNull);
    });

    test('طلبان متزامنان بتوكن منتهٍ يجددان الجلسة مرة واحدة فقط', () async {
      await ApiService.saveTokens(accessToken: 'old', refreshToken: 'stored-refresh');
      backend.overrides['GET /orders'] = (request) {
        return request.headers['Authorization'] == 'Bearer renewed-access'
            ? FakeBackend.json(200, {'success': true, 'data': []})
            : FakeBackend.json(401, {'success': false});
      };

      final results = await Future.wait([ApiService.get('/orders'), ApiService.get('/orders')]);

      expect(results.every((res) => res.isOk), isTrue);
      expect(backend.countOf('POST /auth/refresh'), 1);
    });

    test('خطأ كلمة المرور 401 لا يعتبر انتهاء جلسة ولا يطلب تجديداً', () async {
      final result = await AuthService.loginUser(identifier: '01012345678', password: 'wrong-password');

      expect(result.success, isFalse);
      expect(backend.countOf('POST /auth/refresh'), 0);
    });
  });

  group('الإنترنت والخادم', () {
    testWidgets('فتح التطبيق بلا إنترنت: إعادة محاولة دون مسح الجلسة ثم الدخول عند العودة', (tester) async {
      SharedPreferences.setMockInitialValues(_savedSession({'user_location_name': 'المعادي'}));
      backend.isOffline = true;
      await _launch(tester);

      expect(find.byType(ConnectionRetryScreen), findsOneWidget);
      expect(find.byType(MainNavigationShell), findsNothing);
      expect(await ApiService.getRefreshToken(), 'stored-refresh');

      backend.isOffline = false;
      await tester.tap(find.text('إعادة المحاولة'));
      await tester.pumpAndSettle();

      expect(find.byType(MainNavigationShell), findsOneWidget);
    });

    testWidgets('خطأ خادم 5xx أثناء التحقق لا يسجل خروج المستخدم', (tester) async {
      SharedPreferences.setMockInitialValues(_savedSession());
      backend.overrides['GET /users/me'] = (_) => FakeBackend.json(502, {'error': 'Bad Gateway'});
      await _launch(tester);

      expect(find.byType(ConnectionRetryScreen), findsOneWidget);
      expect(await ApiService.getRefreshToken(), 'stored-refresh');
    });

    test('انقطاع الشبكة أثناء التجديد لا يمسح الجلسة', () async {
      await ApiService.saveTokens(accessToken: 'old', refreshToken: 'stored-refresh');
      backend.overrides['GET /orders'] = (_) => FakeBackend.json(401, {'success': false});
      backend.overrides['POST /auth/refresh'] = (_) => throw const SocketException('offline');

      final res = await ApiService.get('/orders');

      expect(res.isConnectivityError, isTrue);
      expect(await ApiService.getRefreshToken(), 'stored-refresh');
    });

    testWidgets('الشريط يظهر عند الانقطاع ويختفي تلقائياً عند العودة، وتتحدث الطلبات', (tester) async {
      backend.isOffline = true;
      await tester.pumpWidget(_app(const Scaffold(
        body: ConnectionGate(
          recheckInterval: Duration(seconds: 1),
          child: OrdersTab(),
        ),
      )));
      await tester.pump();
      await tester.pump();

      expect(find.text('مفيش اتصال بالإنترنت'), findsOneWidget);

      backend.isOffline = false;
      backend.orders = [sampleOrder(status: 'ACTIVE')];
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      await tester.pump();

      expect(find.text('مفيش اتصال بالإنترنت'), findsNothing);
      expect(find.text('عرض التفاصيل'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    test('الرسائل التقنية من الخادم لا تصل للمستخدم', () async {
      backend.overrides['GET /orders'] = (_) => FakeBackend.json(500, {
            'statusCode': 500,
            'error': 'Internal Server Error',
            'message': 'relation "orders" does not exist',
          });

      final res = await ApiService.get('/orders');

      expect(res.error, isNot(contains('relation')));
      expect(res.error, contains('تعذر'));
    });
  });

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

      await tester.pumpWidget(_app(const LoginScreen()));
      await tester.enterText(find.byType(TextFormField).at(0), '01012345678');
      await tester.enterText(find.byType(TextFormField).at(1), 'Password1');
      await tester.tap(find.text('تسجيل الدخول'));
      await tester.pumpAndSettle();

      expect(find.byType(EmailVerificationScreen), findsOneWidget);
      expect(backend.countOf('POST /auth/resend-otp'), 1);
    });

    testWidgets('رقم الحساب يبقى بعد الخروج ويظهر جاهزاً في خانة معطلة', (tester) async {
      SharedPreferences.setMockInitialValues(_savedSession({'login_phone': '01012345678'}));
      await AuthService.clearLocalSession();

      await tester.pumpWidget(_app(const LoginScreen()));
      await tester.pumpAndSettle();

      final phoneField = tester.widget<TextFormField>(find.byType(TextFormField).at(0));
      expect(phoneField.enabled, isFalse);
      expect(phoneField.controller!.text, '01012345678');
      expect(tester.widget<TextFormField>(find.byType(TextFormField).at(1)).enabled, isTrue);
    });

    testWidgets('زر الخروج: إنهاء الجلسة على الخادم ومسحها ومنع الرجوع للصفحات المحمية', (tester) async {
      SharedPreferences.setMockInitialValues(_savedSession({'user_phone': '01012345678'}));
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_app(
        const MainNavigationShell(initialIndex: 3),
        navigatorKey: navigatorKey,
      ));
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
      SharedPreferences.setMockInitialValues(_savedSession());
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_app(const SizedBox.shrink(), navigatorKey: navigatorKey));
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

      await tester.pumpWidget(_app(const LoginScreen()));
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

  group('الرجوع والتنقل', () {
    testWidgets('إشعار اتلمس والتطبيق بيفتح بيودّي على التذكرة بتاعته', (tester) async {
      SharedPreferences.setMockInitialValues({'user_location_name': 'المعادي'});
      backend.overrides['GET /support/tickets/t-5'] = (request) => FakeBackend.json(200, {
            'success': true,
            'data': {
              'id': 't-5',
              'reference': 'ML-TKT-100005',
              'category': 'OTHER',
              'title': 'سؤال',
              'status': 'OPEN',
              'messages': [
                {'author': 'ADMIN', 'body': 'ردنا عليك', 'images': []},
              ],
            },
          });
      NotificationCenter.openRequest.value = const NotificationTarget(ticketId: 't-5');

      await tester.pumpWidget(_app(const MainNavigationShell(initialIndex: 0)));
      await _settleAsync(tester);

      expect(find.text('ردنا عليك'), findsOneWidget);
      expect(NotificationCenter.openRequest.value, isNull);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('زر رجوع الهاتف في تبويب داخلي يعود للرئيسية ثم يسمح بالخروج', (tester) async {
      SharedPreferences.setMockInitialValues({'user_location_name': 'المعادي'});
      await tester.pumpWidget(_app(const MainNavigationShell(initialIndex: 2)));
      await tester.pumpAndSettle();

      final handled = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(handled, isTrue);
      expect(find.byType(MainNavigationShell), findsOneWidget);
      final shell = tester.state(find.byType(MainNavigationShell)) as dynamic;
      expect(shell.mounted, isTrue);
      expect(find.text('الرئيسية'), findsNWidgets(2));
    });

    testWidgets('الرجوع يغلق Bottom Sheet أولاً ثم الحوار حسب ترتيب الظهور', (tester) async {
      await tester.pumpWidget(_app(Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () {
              showModalBottomSheet<void>(
                context: context,
                builder: (sheetContext) => TextButton(
                  onPressed: () {
                    showDialog<void>(
                      context: sheetContext,
                      builder: (_) => const AlertDialog(content: Text('حوار')),
                    );
                  },
                  child: const Text('افتح الحوار'),
                ),
              );
            },
            child: const Text('افتح الشيت'),
          ),
        ),
      )));

      await tester.tap(find.text('افتح الشيت'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('افتح الحوار'));
      await tester.pumpAndSettle();
      expect(find.text('حوار'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('حوار'), findsNothing);
      expect(find.text('افتح الحوار'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('افتح الحوار'), findsNothing);
      expect(find.text('افتح الشيت'), findsOneWidget);
    });

    testWidgets('الرجوع في خريطة العرض يغلق ملف المحامي قبل مغادرة الشاشة', (tester) async {
      backend.lawyers = [
        {
          'id': 'lawyer-1',
          'name': 'أ/ طارق حسن',
          'specialty': 'قضايا جنائية',
          'degree': 'محامٍ بالاستئناف',
          'rating': 4.8,
          'reviewsCount': 12,
          'experienceYears': 7,
          'coordinates': [30.05, 31.24],
          'distanceKm': 1.2,
        },
      ];

      await tester.pumpWidget(_app(Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const NearbyLawyersShowcaseScreen()),
            ),
            child: const Text('افتح'),
          ),
        ),
      )));
      await tester.tap(find.text('افتح'));
      await _settleAsync(tester);

      await tester.tap(find.text('أ/ طارق حسن').first);
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.text('ملف Google'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('ملف Google'), findsNothing);
      expect(find.byType(NearbyLawyersShowcaseScreen), findsOneWidget);

      await tester.binding.handlePopRoute();
      await _settleAsync(tester);
      expect(find.byType(NearbyLawyersShowcaseScreen), findsNothing);
    });

    testWidgets('بعد السداد لا يعيد الرجوع لصفحة الدفع بل يذهب للطلبات', (tester) async {
      await tester.pumpWidget(_app(const PaymentSuccessScreen(
        price: 350,
        orderRef: 'ML-ORD-100001',
        locationName: 'قصر النيل',
      )));

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(MainNavigationShell), findsOneWidget);
      expect(find.byType(PaymentSuccessScreen), findsNothing);
    });

    testWidgets('فشل تأكيد السداد لا ينقل لشاشة النجاح ويعرض الخطأ', (tester) async {
      backend.overrides['POST /orders/order-1/confirm-payment'] = (_) => FakeBackend.json(400, {
            'success': false,
            'error': 'لا يمكن تأكيد الدفع في الحالة الحالية',
          });

      await tester.pumpWidget(_app(const PaymentScreen(
        orderId: 'order-1',
        orderNumber: 'ML-ORD-100001',
        locationName: 'قصر النيل',
      )));

      await tester.ensureVisible(find.text('دفع 350 ج.م وتأكيد الطلب'));
      await tester.tap(find.text('دفع 350 ج.م وتأكيد الطلب'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(PaymentSuccessScreen), findsNothing);
      expect(find.text('لا يمكن تأكيد الدفع في الحالة الحالية'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('إنشاء حساب: الرجوع من التحقق لا يعيد لنموذج أُرسل بالفعل', (tester) async {
      backend.overrides['POST /auth/register'] = (_) => FakeBackend.json(201, {'success': true});

      await tester.pumpWidget(_app(const LoginScreen()));
      await tester.ensureVisible(find.text('إنشاء حساب جديد'));
      await tester.tap(find.text('إنشاء حساب جديد'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('أنت مــوكل'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'خالد محمود');
      await tester.enterText(find.byType(TextFormField).at(1), '01012345678');
      await tester.ensureVisible(find.text('بيانات الحساب'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('بيانات الحساب'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'khaled@example.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'Password@2026');
      await tester.pump();
      await tester.tap(find.text('مراجعة البيانات'));
      await tester.pumpAndSettle();
      final submit = find.widgetWithText(ElevatedButton, 'إنشاء الحساب والمتابعة');
      await tester.ensureVisible(submit.first);
      await tester.tap(submit.first);
      await tester.pumpAndSettle();
      expect(find.byType(EmailVerificationScreen), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(UserTypeSelectionScreen), findsOneWidget);
      expect(backend.countOf('POST /auth/register'), 1);
    });

    testWidgets('الضغط المتكرر السريع لا يفتح نسختين من الشاشة', (tester) async {
      await tester.pumpWidget(_app(Scaffold(
        body: Builder(
          builder: (context) => AppCard(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('الشاشة التالية'))),
            ),
            child: const Text('فتح'),
          ),
        ),
      )));

      await tester.tap(find.text('فتح'));
      await tester.pump(const Duration(milliseconds: 40));
      await tester.tap(find.text('فتح'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('الشاشة التالية'), findsOneWidget);
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pop();
      await tester.pumpAndSettle();
      expect(navigator.canPop(), isFalse);
    });

    testWidgets('الانتقال موحد وقصير وباتجاه RTL دون قفز', (tester) async {
      await tester.pumpWidget(_app(Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('صفحة'))),
            ),
            child: const Text('فتح'),
          ),
        ),
      )));

      await tester.tap(find.text('فتح'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final slides = find.ancestor(of: find.text('صفحة'), matching: find.byType(SlideTransition));
      final dx = tester.widget<SlideTransition>(slides.first).position.value.dx;
      expect(dx, lessThan(0.0));
      expect(dx, greaterThan(-0.06));

      final fades = find.ancestor(of: find.text('صفحة'), matching: find.byType(FadeTransition));
      final opacity = tester.widget<FadeTransition>(fades.first).opacity.value;
      expect(opacity, greaterThan(0.0));
      expect(opacity, lessThan(1.0));

      await tester.pump(const Duration(milliseconds: 260));
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('إيماءة السحب للرجوع تعمل على iOS وتحترم RTL', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await tester.pumpWidget(_app(Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('صفحة'))),
            ),
            child: const Text('فتح'),
          ),
        ),
      )));

      await tester.tap(find.text('فتح'));
      await tester.pumpAndSettle();
      expect(find.text('صفحة'), findsOneWidget);

      final size = tester.getSize(find.byType(MaterialApp));
      await tester.dragFrom(Offset(size.width - 4, size.height / 2), Offset(-size.width * 0.8, 0));
      await tester.pumpAndSettle();

      expect(find.text('صفحة'), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    });

    test('Android وiOS لكل منهما انتقاله المعتمد', () {
      final builders = AppTheme.lightTheme.pageTransitionsTheme.builders;
      expect(builders[TargetPlatform.android], isA<SmoothRtlPageTransitionsBuilder>());
      expect(builders[TargetPlatform.iOS], isA<CupertinoPageTransitionsBuilder>());
    });

    testWidgets('شاشة أولى في المكدس لا تعرض زر رجوع بلا فعل', (tester) async {
      await tester.pumpWidget(_app(const LocationPermissionScreen()));
      await tester.pump();

      expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
    });
  });

  group('دورة المهمة', () {
    testWidgets('أول فتح يعرض الأذونات، و«لاحقاً» يكمل ولا تتكرر', (tester) async {
      await tester.pumpWidget(_app(const SplashScreen()));
      await tester.pump(const Duration(milliseconds: 2700));
      await _settleAsync(tester);

      expect(find.text('السماح والمتابعة'), findsOneWidget);

      await tester.tap(find.text('لاحقاً'));
      await _settleAsync(tester);

      expect(find.text('السماح والمتابعة'), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('has_requested_initial_permissions'), isTrue);
    });

    testWidgets('صفحة الإشعارات لا تعلم كمقروء إلا بالزر', (tester) async {
      backend.overrides['GET /notifications'] = (request) => FakeBackend.json(200, {
            'success': true,
            'data': [
              {'id': '1', 'title': 'المحامي وافق', 'body': 'كمّل الدفع', 'isRead': false},
            ],
          });
      backend.overrides['POST /notifications/read-all'] =
          (request) => FakeBackend.json(200, {'success': true});

      await tester.pumpWidget(_app(const NotificationsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('المحامي وافق'), findsOneWidget);
      expect(find.byKey(const ValueKey('unread-dot')), findsOneWidget);
      expect(backend.countOf('POST /notifications/read-all'), 0);

      await tester.tap(find.text('تعليم الكل كمقروء'));
      await _settleAsync(tester);

      expect(backend.countOf('POST /notifications/read-all'), 1);
      expect(find.byKey(const ValueKey('unread-dot')), findsNothing);
      expect(find.text('تعليم الكل كمقروء'), findsNothing);
    });

    testWidgets('الحساب الموقوف يتوجه لصفحة الإيقاف من أي شاشة', (tester) async {
      backend.overrides['GET /orders'] = (_) => FakeBackend.json(403, {
            'success': false,
            'error': 'تم إيقاف هذا الحساب',
            'data': {'status': 'suspended'},
          });
      ApiService.onAccountSuspended = SessionRouter.handleAccountSuspended;

      await tester.pumpWidget(_app(const Scaffold(body: OrdersTab()), navigatorKey: SessionRouter.navigatorKey));
      await tester.pumpAndSettle();

      expect(find.byType(AccountSuspendedScreen), findsOneWidget);
      expect(find.text('حسابك موقوف'), findsOneWidget);
      expect(find.byType(OrdersTab), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    test('الجلسة الموقوفة لها وجهة مستقلة', () {
      final check = AuthService.resolveSession(role: 'client', userStatus: 'suspended', approvalStatus: null);
      expect(check.status, SessionStatus.accountSuspended);
    });

    testWidgets('الموكل ما بيشوفش أي كود في طلبه النشط', (tester) async {
      backend.orders = [sampleOrder(status: 'ACTIVE')];
      await _openDetails(tester);

      expect(find.text('كود إنهاء المهمة'), findsNothing);
      expect(find.text('ML-ORD-100001'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('رقم الطلب ظاهر في الكارت والإجراءات في صفحة التفاصيل فقط', (tester) async {
      backend.orders = [sampleOrder(status: 'CANCELLED')];

      await tester.pumpWidget(_app(const Scaffold(body: OrdersTab())));
      await tester.pumpAndSettle();

      expect(find.textContaining('ML-ORD-100001'), findsOneWidget);
      expect(find.text('إلغاء الطلب'), findsNothing);
    });

    testWidgets('زر الإنهاء لا يظهر للمحامي قبل تسجيل الوصول', (tester) async {
      backend.orders = [sampleOrder(status: 'ACTIVE')];

      await _openDetails(tester, isLawyer: true);

      expect(find.text('وصلت'), findsOneWidget);
      expect(find.text('إنهاء المهمة'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('المحامي ينهي المهمة بعد الوصول بتأكيد من غير كود', (tester) async {
      backend.overrides['POST /orders/order-1/complete'] = (request) {
        expect((jsonDecode(request.body) as Map<String, dynamic>).containsKey('code'), isFalse);
        return FakeBackend.json(200, {'success': true, 'data': {'status': 'COMPLETED'}});
      };
      backend.orders = [
        {...sampleOrder(status: 'ACTIVE'), 'arrivedAt': DateTime.now().toIso8601String()},
      ];

      await _openDetails(tester, isLawyer: true);
      expect(find.text('وصلت'), findsNothing);

      await tester.ensureVisible(find.text('إنهاء المهمة'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('إنهاء المهمة'));
      await _settleAsync(tester);

      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.text('إنهاء').last);
      await _settleAsync(tester);
      expect(backend.countOf('POST /orders/order-1/complete'), 1);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('شيت التقييم يفتح لوحده للموكل أول ما المحامي ينهي المهمة', (tester) async {
      backend.orders = [
        {...sampleOrder(status: 'ACTIVE'), 'arrivedAt': DateTime.now().toIso8601String()},
      ];
      await _openDetails(tester);
      expect(find.byType(BottomSheet), findsNothing);

      backend.orders = [
        {...sampleOrder(status: 'COMPLETED'), 'completedAt': DateTime.now().toIso8601String()},
      ];
      await tester.pump(const Duration(seconds: 11));
      await _settleAsync(tester);

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.descendant(of: find.byType(BottomSheet), matching: find.text('قيّم المحامي')), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('الطلب المكتمل يعرض التقييم، والمشكلة بتتبعت تذكرة دعم والطلب متحدد', (tester) async {
      backend.overrides['POST /support/tickets'] =
          (request) => FakeBackend.json(201, {'success': true, 'message': 'استلمنا تذكرتك رقم ML-TKT-100001', 'data': {'id': 't-1'}});
      backend.orders = [
        {
          ...sampleOrder(status: 'COMPLETED'),
          'completedAt': DateTime.now().toIso8601String(),
          'paidAt': DateTime.now().toIso8601String(),
        },
      ];

      await _openDetails(tester);

      expect(find.text('قيّم المحامي'), findsOneWidget);
      await tester.ensureVisible(find.text('عندك مشكلة؟'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('عندك مشكلة؟'));
      await _settleAsync(tester);

      expect(find.text('طلب ML-ORD-100001'), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(0), 'المحامي اتأخر');
      await tester.enterText(find.byType(TextField).at(1), 'المحامي لم يكمل المهمة كما اتفقنا');
      await tester.ensureVisible(find.text('إرسال التذكرة'));
      await tester.tap(find.text('إرسال التذكرة'));
      await _settleAsync(tester);

      expect(backend.countOf('POST /support/tickets'), 1);
      expect(find.text('إرسال التذكرة'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('لو فيه تذكرة على الطلب، الزرار يبقى «تابع مشكلتك» ويفتحها', (tester) async {
      backend.overrides['GET /support/tickets/t-9'] = (request) => FakeBackend.json(200, {
            'success': true,
            'data': {
              'id': 't-9',
              'reference': 'ML-TKT-100009',
              'category': 'ORDER',
              'title': 'المحامي اتأخر',
              'status': 'UNDER_REVIEW',
              'messages': [
                {'author': 'USER', 'body': 'المحامي اتأخر ساعة', 'images': []},
              ],
            },
          });
      backend.orders = [
        {
          ...sampleOrder(status: 'COMPLETED'),
          'completedAt': DateTime.now().toIso8601String(),
          'paidAt': DateTime.now().toIso8601String(),
          'openTicketId': 't-9',
        },
      ];

      await _openDetails(tester);
      expect(find.text('عندك مشكلة؟'), findsNothing);
      await tester.ensureVisible(find.text('تابع مشكلتك'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تابع مشكلتك'));
      await _settleAsync(tester);

      expect(find.text('المحامي اتأخر ساعة'), findsOneWidget);
      expect(find.text('تحت المراجعة'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('لمس إشعار رد الدعم بيفتح التذكرة نفسها', (tester) async {
      backend.overrides['GET /notifications'] = (request) => FakeBackend.json(200, {
            'success': true,
            'data': [
              {'id': 'n-1', 'title': 'رد الدعم الفني', 'body': 'الإدارة ردت على تذكرتك ML-TKT-100001', 'isRead': false, 'ticketId': 't-1'},
            ],
          });
      backend.overrides['GET /support/tickets/t-1'] = (request) => FakeBackend.json(200, {
            'success': true,
            'data': {
              'id': 't-1',
              'reference': 'ML-TKT-100001',
              'category': 'ACCOUNT',
              'title': 'مشكلة في الدخول',
              'status': 'OPEN',
              'messages': [
                {'author': 'ADMIN', 'body': 'جرب تاني دلوقتي', 'images': []},
              ],
            },
          });

      await tester.pumpWidget(_app(const NotificationsScreen()));
      await _settleAsync(tester);
      await tester.tap(find.text('رد الدعم الفني'));
      await _settleAsync(tester);

      expect(find.text('جرب تاني دلوقتي'), findsOneWidget);
      expect(find.text('إرسال الرد'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('التذكرة المقفولة بتعرض الرسايل من غير خانة رد', (tester) async {
      final ticket = {
        'id': 't-1',
        'reference': 'ML-TKT-100001',
        'category': 'ACCOUNT',
        'title': 'مشكلة في الدخول',
        'status': 'CLOSED',
        'updatedAt': '2026-11-02T10:00:00.000Z',
      };
      backend.overrides['GET /support/tickets'] = (request) => FakeBackend.json(200, {'success': true, 'data': [ticket]});
      backend.overrides['GET /support/tickets/t-1'] = (request) => FakeBackend.json(200, {
            'success': true,
            'data': {
              ...ticket,
              'messages': [
                {'author': 'USER', 'body': 'مش عارف أدخل', 'images': []},
                {'author': 'ADMIN', 'body': 'اتحلت، جرب تاني', 'images': []},
              ],
            },
          });

      await tester.pumpWidget(_app(const SupportScreen()));
      await _settleAsync(tester);
      expect(find.text('مشكلة في الدخول'), findsOneWidget);
      expect(find.text('مقفولة'), findsOneWidget);

      await tester.tap(find.text('مشكلة في الدخول'));
      await _settleAsync(tester);
      expect(find.text('الدعم الفني'), findsOneWidget);
      expect(find.text('اتحلت، جرب تاني'), findsOneWidget);
      expect(find.text('إرسال الرد'), findsNothing);
      expect(find.text('التذكرة دي اتقفلت، لو عندك مشكلة جديدة افتح تذكرة جديدة'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('اعتذار المحامي يظهر في الشيت ثم يتبعت الطلب للمحامي التالي', (tester) async {
      backend.lawyers = [
        {
          'id': 'lawyer-1',
          'name': 'أ/ طارق حسن',
          'specialty': 'قضايا جنائية',
          'degree': 'محامٍ بالاستئناف',
          'rating': 4.8,
          'reviewsCount': 12,
          'experienceYears': 7,
          'coordinates': [30.05, 31.24],
          'distanceKm': 1.2,
        },
        {
          'id': 'lawyer-2',
          'name': 'أ/ منى عادل',
          'specialty': 'قضايا جنائية',
          'degree': 'محامٍ بالاستئناف',
          'rating': 4.8,
          'reviewsCount': 12,
          'experienceYears': 7,
          'coordinates': [30.05, 31.24],
          'distanceKm': 1.2,
        },
      ];
      backend.overrides['POST /orders'] = (request) => FakeBackend.json(201, {
            'success': true,
            'data': {'id': 'order-1', 'orderNumber': 'ML-ORD-100002', 'price': 425, 'status': 'PENDING'},
          });
      backend.overrides['GET /orders/order-1'] = (request) => FakeBackend.json(200, {
            'success': true,
            'data': {'status': 'REJECTED'},
          });

      await tester.pumpWidget(_app(const TrackingScreen(problemTitle: 'محضر')));
      await tester.pump(const Duration(seconds: 11));
      await _settleAsync(tester);

      await tester.tap(find.text('طلب الآن'));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('موافق'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('اعتذر المحامي'), findsOneWidget);

      // الطلب يتبعت تلقائياً للمحامي التالي مرة واحدة لكل محامٍ
      final nextLawyer = find.textContaining('أ/ منى عادل');
      for (int i = 0; i < 40 && backend.countOf('POST /orders') < 2; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(nextLawyer, findsWidgets);
      expect(backend.countOf('POST /orders'), 2);

      final noMoreLawyers = find.text('مفيش محامي تاني متاح دلوقتي، جرب بعد شوية');
      for (int i = 0; i < 40 && noMoreLawyers.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(noMoreLawyers, findsOneWidget);
      expect(backend.countOf('POST /orders'), 2);
      expect(find.text('طلب الآن'), findsOneWidget);
    });
  });

  group('التحويل من المحفظة', () {
    testWidgets('الموكل يكتب الرقم والمبلغ، ويأكد اسم المستلم، وبعدها يتحول', (tester) async {
      backend.overrides['GET /wallet/recipient'] = (request) {
        expect(request.url.queryParameters['phone'], '01000000002');
        return FakeBackend.json(200, {'success': true, 'data': {'name': 'أحمد م.', 'role': 'lawyer'}});
      };
      backend.overrides['POST /wallet/transfer'] = (request) {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['phone'], '01000000002');
        expect(body['amount'], 150);
        return FakeBackend.json(200, {'success': true, 'data': {'amount': 150}});
      };

      await tester.pumpWidget(_app(const Scaffold(body: WalletTab())));
      await _settleAsync(tester);

      await tester.tap(find.text('تحويل لحساب تاني'));
      await _settleAsync(tester);

      await tester.enterText(find.byType(TextField).at(0), '01000000002');
      await tester.enterText(find.byType(TextField).at(1), '50');
      await tester.tap(find.text('متابعة'));
      await _settleAsync(tester);
      expect(find.text('المبلغ من 100 لـ 10000 ج.م'), findsOneWidget);
      expect(backend.countOf('GET /wallet/recipient'), 0);

      await tester.enterText(find.byType(TextField).at(1), '150');
      await tester.tap(find.text('متابعة'));
      await _settleAsync(tester);
      expect(find.text('150 ج.م إلى أحمد م.'), findsOneWidget);

      await tester.tap(find.text('تأكيد التحويل'));
      await _settleAsync(tester);
      expect(backend.countOf('POST /wallet/transfer'), 1);
      expect(find.text('تأكيد التحويل'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('الطلبات الفعلية', () {
    testWidgets('لا توجد طلبات: حالة فارغة بلا أي بيانات تجريبية', (tester) async {
      await tester.pumpWidget(_app(const Scaffold(body: OrdersTab())));
      await tester.pumpAndSettle();

      expect(find.text('لا توجد طلبات حتى الآن'), findsOneWidget);
      expect(find.textContaining('أحمد الشافعي'), findsNothing);
      expect(find.text('ML-984210'), findsNothing);
    });

    test('نموذج الطلب يفرق بين رقم الطلب ومعرفه من القائمة الفعلية', () {
      final order = OrderModel.fromJson(sampleOrder(status: 'ACTIVE'));

      expect(order.id, 'order-1');
      expect(order.orderNumber, 'ML-ORD-100001');
      expect(order.isOngoing, isTrue);
      expect(order.isPaid, isTrue);
    });

    testWidgets('فشل إرسال الطلب يعيد المستخدم لملف المحامي برسالة واضحة', (tester) async {
      backend.lawyers = [
        {
          'id': 'lawyer-1',
          'name': 'أ/ طارق حسن',
          'specialty': 'قضايا جنائية',
          'degree': 'محامٍ بالاستئناف',
          'rating': 4.8,
          'reviewsCount': 12,
          'experienceYears': 7,
          'coordinates': [30.05, 31.24],
          'distanceKm': 1.2,
        },
      ];
      backend.overrides['POST /orders'] = (_) => FakeBackend.json(400, {
            'success': false,
            'error': 'المحامي غير متاح حالياً',
          });

      await tester.pumpWidget(_app(const TrackingScreen(problemTitle: 'محضر')));
      await tester.pump(const Duration(seconds: 11));
      await _settleAsync(tester);

      await tester.tap(find.text('طلب الآن'));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('موافق'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(backend.countOf('POST /orders'), 1);
      expect(find.text('المحامي غير متاح حالياً'), findsOneWidget);
      expect(find.text('طلب الآن'), findsOneWidget);
      expect(find.text('في انتظار قبول المحامي'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
    });
  });

  group('فصل الإنتاج عن الاختبار', () {
    test('الوضع الافتراضي هو الإنتاج بخادمه الفعلي', () {
      expect(AppConfig.isProduction, isTrue);
      expect(AppConfig.apiBaseUrl, AppConfig.productionApiBaseUrl);
      expect(kReleaseMode, isFalse);
    });

    test('لا يوجد في كود التطبيق أي بيانات تجريبية أو أدوات اختبار', () {
      const forbidden = <String>[
        'MockLawyer',
        'isTestMode',
        '_isTesting',
        'kDebugMode',
        '_openClientDirect',
        '_openLawyerDirect',
        'unsplash.com',
        "'123456'",
        'ML-984210',
        'أ. أحمد الشافعي',
        'محمد علي إبراهيم',
        '1,450.00',
        'Client@123456',
        'Lawyer@123456',
      ];

      final dartFiles = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));

      for (final file in dartFiles) {
        final source = file.readAsStringSync();
        for (final term in forbidden) {
          expect(source.contains(term), isFalse, reason: '${file.path} يحتوي على $term');
        }
      }
    });

    test('لا توجد كلمات مرور ثابتة في ملفات الاختبار', () {
      final source = File('test/api_integration_test.dart').readAsStringSync();
      expect(source.contains('@123456'), isFalse);
    });

    test('صلاحية النسخ الاحتياطي معطلة حتى لا تخرج بيانات الجلسة من الجهاز', () {
      final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(manifest, contains('android:allowBackup="false"'));
    });
  });
}
