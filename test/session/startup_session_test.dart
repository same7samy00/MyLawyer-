import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_lawyer/core/config/app_config.dart';
import 'package:my_lawyer/core/services/api_service.dart';
import 'package:my_lawyer/core/services/auth_service.dart';
import 'package:my_lawyer/core/widgets/connection_gate.dart';
import 'package:my_lawyer/features/auth/account_suspended_screen.dart';
import 'package:my_lawyer/features/auth/connection_retry_screen.dart';
import 'package:my_lawyer/features/auth/lawyer_approval_status_screen.dart';
import 'package:my_lawyer/features/auth/location_permission_screen.dart';
import 'package:my_lawyer/features/auth/login_screen.dart';
import 'package:my_lawyer/features/auth/session_router.dart';
import 'package:my_lawyer/features/client/main_navigation_shell.dart';
import 'package:my_lawyer/features/client/orders_tab.dart';
import 'package:my_lawyer/features/lawyer/lawyer_navigation_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/session_test_helpers.dart';

void main() {
  setUpSessionTests();

  group('فتح التطبيق وتوجيه الجلسة', () {
    testWidgets('بدون جلسة: مباشرة لتسجيل الدخول بلا أي طلب للخادم', (tester) async {
      await launchApp(tester);

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(MainNavigationShell), findsNothing);
      expect(backend.calls, isEmpty);
    });

    testWidgets('علامة دخول قديمة بلا Tokens لا تفتح الصفحات المحمية', (tester) async {
      SharedPreferences.setMockInitialValues({'is_logged_in': true, 'user_account_type': 'client'});
      await launchApp(tester);

      expect(find.byType(LoginScreen), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('is_logged_in'), isNull);
    });

    testWidgets('جلسة صالحة لموكل له موقع محفوظ: يدخل رئيسية الموكل بعد التحقق مع الخادم', (tester) async {
      SharedPreferences.setMockInitialValues(savedSession({'user_location_name': 'المعادي، محافظة القاهرة'}));
      await launchApp(tester);

      expect(find.byType(MainNavigationShell), findsOneWidget);
      expect(backend.countOf('GET /users/me'), greaterThanOrEqualTo(1));
    });

    testWidgets('إذن الموقع متاح من قبل: صفحة «محتاجين نحدد موقعك» ما تظهرش', (tester) async {
      SharedPreferences.setMockInitialValues(savedSession());
      await launchApp(tester);

      expect(find.byType(LocationPermissionScreen), findsNothing);
      expect(find.byType(MainNavigationShell), findsOneWidget);
    });

    testWidgets('حدد موقعه مرة: شاشة الموقع ما تظهرش تاني', (tester) async {
      SharedPreferences.setMockInitialValues(savedSession({'location_screen_done': true}));
      await launchApp(tester);

      expect(find.byType(LocationPermissionScreen), findsNothing);
      expect(find.byType(MainNavigationShell), findsOneWidget);
    });

    testWidgets('محامٍ معتمد: رئيسية المحامي', (tester) async {
      SharedPreferences.setMockInitialValues(savedSession());
      backend.account = lawyerAccount();
      await launchApp(tester);

      expect(find.byType(LawyerNavigationShell), findsOneWidget);
    });

    testWidgets('محامٍ قيد المراجعة: شاشة حالة الاعتماد دون الوصول للطلبات', (tester) async {
      SharedPreferences.setMockInitialValues(savedSession());
      backend.account = lawyerAccount(status: 'pending_admin_approval', approvalStatus: 'pending');
      await launchApp(tester);

      expect(find.byType(LawyerApprovalStatusScreen), findsOneWidget);
      expect(find.text('حسابك قيد المراجعة'), findsOneWidget);
      expect(find.byType(LawyerNavigationShell), findsNothing);
    });

    testWidgets('اعتماد المحامي أثناء الانتظار: تحديث الحالة يفتح واجهته', (tester) async {
      SharedPreferences.setMockInitialValues(savedSession());
      backend.account = lawyerAccount(status: 'pending_admin_approval', approvalStatus: 'pending');
      await launchApp(tester);

      backend.account = lawyerAccount();
      await tester.tap(find.text('تحديث حالة الحساب'));
      await tester.pumpAndSettle();

      expect(find.byType(LawyerNavigationShell), findsOneWidget);
    });

    testWidgets('محامٍ مرفوض: حالة واضحة مع إمكانية الخروج', (tester) async {
      SharedPreferences.setMockInitialValues(savedSession());
      backend.account = lawyerAccount(status: 'rejected', approvalStatus: 'rejected');
      await launchApp(tester);

      expect(find.text('لم يتم اعتماد حسابك'), findsOneWidget);

      await tester.tap(find.text('تسجيل الخروج'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(await ApiService.getRefreshToken(), isNull);
    });

    testWidgets('حساب موقوف: صفحة الإيقاف مع حفظ الجلسة والرجوع بعد التفعيل', (tester) async {
      SharedPreferences.setMockInitialValues(savedSession());
      backend.overrides['GET /users/me'] = (_) => FakeBackend.json(403, {
            'success': false,
            'error': 'تم إيقاف هذا الحساب',
            'data': {'status': 'suspended'},
          });
      await launchApp(tester);

      expect(find.byType(AccountSuspendedScreen), findsOneWidget);
      expect(await ApiService.getRefreshToken(), isNotNull);

      await tester.tap(find.text('تحديث حالة الحساب'));
      await settleAsync(tester);
      expect(find.text('الحساب لسه موقوف'), findsOneWidget);

      backend.overrides.remove('GET /users/me');
      await tester.tap(find.text('تحديث حالة الحساب'));
      await settleAsync(tester);
      expect(find.byType(AccountSuspendedScreen), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('انتهاء الجلسة وتجديدها', () {
    testWidgets('Access منتهٍ مع Refresh صالح: تجديد صامت ودخول طبيعي', (tester) async {
      SharedPreferences.setMockInitialValues(savedSession({'user_location_name': 'المعادي'}));
      backend.overrides['GET /users/me'] = (request) {
        if (request.headers['Authorization'] == 'Bearer renewed-access') {
          return FakeBackend.json(200, {'success': true, 'data': clientAccount()});
        }
        return FakeBackend.json(401, {'success': false, 'error': 'غير مصرح'});
      };
      await launchApp(tester);

      expect(find.byType(MainNavigationShell), findsOneWidget);
      expect(backend.countOf('POST /auth/refresh'), 1);
      // The renewed session sits in the encrypted vault, not in plain storage
      expect(await const FlutterSecureStorage().read(key: ApiService.prefRefreshToken), 'renewed-refresh');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(ApiService.prefRefreshToken), isNull);
    });

    testWidgets('جلسة منتهية فعلياً: مسح بياناتها والعودة للدخول برسالة', (tester) async {
      SharedPreferences.setMockInitialValues(savedSession({'user_phone': '01012345678'}));
      backend.overrides['GET /users/me'] = (_) => FakeBackend.json(401, {'success': false});
      backend.overrides['POST /auth/refresh'] = (_) => FakeBackend.json(401, {'success': false});
      await launchApp(tester);

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('انتهت جلستك، يرجى تسجيل الدخول مرة أخرى'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(ApiService.prefRefreshToken), isNull);
      expect(prefs.getString('user_phone'), isNull);
      expect(await const FlutterSecureStorage().read(key: ApiService.prefRefreshToken), isNull);
    });

    testWidgets('انتهاء الجلسة أثناء الاستخدام: إغلاق كل الصفحات والعودة للدخول', (tester) async {
      SharedPreferences.setMockInitialValues(savedSession());
      ApiService.onSessionExpired = SessionRouter.handleSessionExpired;
      backend.overrides['GET /orders'] = (_) => FakeBackend.json(401, {'success': false});
      backend.overrides['POST /auth/refresh'] = (_) => FakeBackend.json(401, {'success': false});

      await tester.pumpWidget(testApp(
        const Scaffold(body: OrdersTab()),
        navigatorKey: SessionRouter.navigatorKey,
      ),);
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
      SharedPreferences.setMockInitialValues(savedSession({'user_location_name': 'المعادي'}));
      backend.isOffline = true;
      await launchApp(tester);

      expect(find.byType(ConnectionRetryScreen), findsOneWidget);
      expect(find.byType(MainNavigationShell), findsNothing);
      expect(await ApiService.getRefreshToken(), 'stored-refresh');

      backend.isOffline = false;
      await tester.tap(find.text('إعادة المحاولة'));
      await tester.pumpAndSettle();

      expect(find.byType(MainNavigationShell), findsOneWidget);
    });

    testWidgets('خطأ خادم 5xx أثناء التحقق لا يسجل خروج المستخدم', (tester) async {
      SharedPreferences.setMockInitialValues(savedSession());
      backend.overrides['GET /users/me'] = (_) => FakeBackend.json(502, {'error': 'Bad Gateway'});
      await launchApp(tester);

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
      await tester.pumpWidget(testApp(const Scaffold(
        body: ConnectionGate(
          recheckInterval: Duration(seconds: 1),
          child: OrdersTab(),
        ),
      ),),);
      // The bar shows once the automatic retries have failed too, not on the first blip
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }

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
