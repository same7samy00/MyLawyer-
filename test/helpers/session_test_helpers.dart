import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_lawyer/core/services/api_service.dart';
import 'package:my_lawyer/core/services/order_store.dart';
import 'package:my_lawyer/core/theme/app_theme.dart';
import 'package:my_lawyer/features/auth/session_router.dart';
import 'package:my_lawyer/features/auth/splash_screen.dart';
import 'package:my_lawyer/features/client/orders_tab.dart';
import 'package:my_lawyer/features/lawyer/lawyer_orders_tab.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_backend.dart';

export 'fake_backend.dart';

late FakeBackend backend;

Widget testApp(Widget home, {GlobalKey<NavigatorState>? navigatorKey}) {
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

Map<String, Object> savedSession([Map<String, Object> extra = const {}]) => {
      ApiService.prefAccessToken: 'stored-access',
      ApiService.prefRefreshToken: 'stored-refresh',
      ...extra,
    };

/// تشغيل التطبيق من الشاشة الافتتاحية حتى استقرار الوجهة
Future<void> launchApp(WidgetTester tester) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('has_requested_initial_permissions', true);
  await tester.pumpWidget(testApp(const SplashScreen()));
  await tester.pump(const Duration(milliseconds: 2700));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

/// تمرير الوقت على دفعات حتى تكتمل العمليات المتتابعة في الشاشات ذات الخرائط
/// يفتح صفحة تفاصيل الطلب الوحيد من صفحة الطلبات
Future<void> openOrderDetails(WidgetTester tester, {bool isLawyer = false}) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(testApp(Scaffold(body: isLawyer ? const LawyerOrdersTab() : const OrdersTab())));
  await tester.pumpAndSettle();
  if (find.text('عرض التفاصيل').evaluate().isEmpty) {
    await tester.tap(find.text('سجل الطلبات'));
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(find.text('عرض التفاصيل'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('عرض التفاصيل'));
  await tester.pumpAndSettle();
}

Future<void> settleAsync(WidgetTester tester) async {
  for (int i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
}

/// الإعداد المشترك قبل كل اختبار
void setUpSessionTests() {
  SessionRouter.showPromoMap = false;


  setUp(() {
    OrderStore.clear();
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/geolocator'),
      (call) async => call.method == 'checkPermission' ? 3 : throw MissingPluginException(),
    );
    backend = FakeBackend();
    ApiService.useHttpClient(backend.client);
  });
}

/// الموبايل عنده موقع حقيقي، للطلبات اللي بتحتاج مكان الموكل
void mockPhoneLocation() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('flutter.baseflow.com/geolocator'),
    (call) async {
      switch (call.method) {
        case 'isLocationServiceEnabled':
          return true;
        case 'checkPermission':
          return 3;
        case 'getLastKnownPosition':
          return null;
        case 'getCurrentPosition':
          return {
            'latitude': 30.05,
            'longitude': 31.25,
            'timestamp': DateTime(2026).millisecondsSinceEpoch,
            'accuracy': 5.0,
            'altitude': 0.0,
            'altitude_accuracy': 0.0,
            'heading': 0.0,
            'heading_accuracy': 0.0,
            'speed': 0.0,
            'speed_accuracy': 0.0,
          };
        default:
          throw MissingPluginException();
      }
    },
  );
}
