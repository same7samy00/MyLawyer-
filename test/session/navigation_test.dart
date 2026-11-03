import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_lawyer/core/theme/app_theme.dart';
import 'package:my_lawyer/core/widgets/app_card.dart';
import 'package:my_lawyer/features/auth/email_verification_screen.dart';
import 'package:my_lawyer/features/auth/location_permission_screen.dart';
import 'package:my_lawyer/features/auth/login_screen.dart';
import 'package:my_lawyer/features/client/main_navigation_shell.dart';
import 'package:my_lawyer/features/client/nearby_lawyers_showcase_screen.dart';
import 'package:my_lawyer/core/services/notification_center.dart';
import 'package:my_lawyer/features/urgent_service/payment_screen.dart';
import 'package:my_lawyer/features/urgent_service/payment_success_screen.dart';
import 'package:my_lawyer/features/auth/user_type_selection_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/session_test_helpers.dart';

void main() {
  setUpSessionTests();

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

      await tester.pumpWidget(testApp(const MainNavigationShell(initialIndex: 0)));
      await settleAsync(tester);

      expect(find.text('ردنا عليك'), findsOneWidget);
      expect(NotificationCenter.openRequest.value, isNull);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('زر رجوع الهاتف في تبويب داخلي يعود للرئيسية ثم يسمح بالخروج', (tester) async {
      SharedPreferences.setMockInitialValues({'user_location_name': 'المعادي'});
      await tester.pumpWidget(testApp(const MainNavigationShell(initialIndex: 2)));
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
      await tester.pumpWidget(testApp(Builder(
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

      await tester.pumpWidget(testApp(Builder(
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
      await settleAsync(tester);

      await tester.tap(find.text('أ/ طارق حسن').first);
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.text('ملف Google'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('ملف Google'), findsNothing);
      expect(find.byType(NearbyLawyersShowcaseScreen), findsOneWidget);

      await tester.binding.handlePopRoute();
      await settleAsync(tester);
      expect(find.byType(NearbyLawyersShowcaseScreen), findsNothing);
    });

    testWidgets('بعد السداد لا يعيد الرجوع لصفحة الدفع بل يذهب للطلبات', (tester) async {
      await tester.pumpWidget(testApp(const PaymentSuccessScreen(
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

      await tester.pumpWidget(testApp(const PaymentScreen(
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

      await tester.pumpWidget(testApp(const LoginScreen()));
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
      await tester.pumpWidget(testApp(Scaffold(
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
      await tester.pumpWidget(testApp(Scaffold(
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
      await tester.pumpWidget(testApp(Scaffold(
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
      await tester.pumpWidget(testApp(const LocationPermissionScreen()));
      await tester.pump();

      expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
    });
  });
}
