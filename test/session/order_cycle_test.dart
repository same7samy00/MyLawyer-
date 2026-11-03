import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_lawyer/core/services/api_service.dart';
import 'package:my_lawyer/core/services/auth_service.dart';
import 'package:my_lawyer/data/models/order_model.dart';
import 'package:my_lawyer/features/client/orders_tab.dart';
import 'package:my_lawyer/features/support/support_screen.dart';
import 'package:my_lawyer/features/auth/account_suspended_screen.dart';
import 'package:my_lawyer/features/auth/session_router.dart';
import 'package:my_lawyer/features/auth/splash_screen.dart';
import 'package:my_lawyer/features/urgent_service/tracking_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_lawyer/features/notifications/notifications_screen.dart';
import '../helpers/session_test_helpers.dart';

void main() {
  setUpSessionTests();

  group('دورة المهمة', () {
    testWidgets('أول فتح يعرض الأذونات، و«لاحقاً» يكمل ولا تتكرر', (tester) async {
      await tester.pumpWidget(testApp(const SplashScreen()));
      await tester.pump(const Duration(milliseconds: 2700));
      await settleAsync(tester);

      expect(find.text('السماح والمتابعة'), findsOneWidget);

      await tester.tap(find.text('لاحقاً'));
      await settleAsync(tester);

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

      await tester.pumpWidget(testApp(const NotificationsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('المحامي وافق'), findsOneWidget);
      expect(find.byKey(const ValueKey('unread-dot')), findsOneWidget);
      expect(backend.countOf('POST /notifications/read-all'), 0);

      await tester.tap(find.text('تعليم الكل كمقروء'));
      await settleAsync(tester);

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

      await tester.pumpWidget(testApp(const Scaffold(body: OrdersTab()), navigatorKey: SessionRouter.navigatorKey));
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
      await openOrderDetails(tester);

      expect(find.text('كود إنهاء المهمة'), findsNothing);
      expect(find.text('ML-ORD-100001'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('رقم الطلب ظاهر في الكارت والإجراءات في صفحة التفاصيل فقط', (tester) async {
      backend.orders = [sampleOrder(status: 'CANCELLED')];

      await tester.pumpWidget(testApp(const Scaffold(body: OrdersTab())));
      await tester.pumpAndSettle();

      expect(find.textContaining('ML-ORD-100001'), findsOneWidget);
      expect(find.text('إلغاء الطلب'), findsNothing);
    });

    testWidgets('زر الإنهاء لا يظهر للمحامي قبل تسجيل الوصول', (tester) async {
      backend.orders = [sampleOrder(status: 'ACTIVE')];

      await openOrderDetails(tester, isLawyer: true);

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

      await openOrderDetails(tester, isLawyer: true);
      expect(find.text('وصلت'), findsNothing);

      await tester.ensureVisible(find.text('إنهاء المهمة'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('إنهاء المهمة'));
      await settleAsync(tester);

      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.text('إنهاء').last);
      await settleAsync(tester);
      expect(backend.countOf('POST /orders/order-1/complete'), 1);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('شيت التقييم يفتح لوحده للموكل أول ما المحامي ينهي المهمة', (tester) async {
      backend.orders = [
        {...sampleOrder(status: 'ACTIVE'), 'arrivedAt': DateTime.now().toIso8601String()},
      ];
      await openOrderDetails(tester);
      expect(find.byType(BottomSheet), findsNothing);

      backend.orders = [
        {...sampleOrder(status: 'COMPLETED'), 'completedAt': DateTime.now().toIso8601String()},
      ];
      await tester.pump(const Duration(seconds: 11));
      await settleAsync(tester);

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

      await openOrderDetails(tester);

      expect(find.text('قيّم المحامي'), findsOneWidget);
      await tester.ensureVisible(find.text('عندك مشكلة؟'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('عندك مشكلة؟'));
      await settleAsync(tester);

      expect(find.text('طلب ML-ORD-100001'), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(0), 'المحامي اتأخر');
      await tester.enterText(find.byType(TextField).at(1), 'المحامي لم يكمل المهمة كما اتفقنا');
      await tester.ensureVisible(find.text('إرسال التذكرة'));
      await tester.tap(find.text('إرسال التذكرة'));
      await settleAsync(tester);

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

      await openOrderDetails(tester);
      expect(find.text('عندك مشكلة؟'), findsNothing);
      await tester.ensureVisible(find.text('تابع مشكلتك'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تابع مشكلتك'));
      await settleAsync(tester);

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

      await tester.pumpWidget(testApp(const NotificationsScreen()));
      await settleAsync(tester);
      await tester.tap(find.text('رد الدعم الفني'));
      await settleAsync(tester);

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

      await tester.pumpWidget(testApp(const SupportScreen()));
      await settleAsync(tester);
      expect(find.text('مشكلة في الدخول'), findsOneWidget);
      expect(find.text('مقفولة'), findsOneWidget);

      await tester.tap(find.text('مشكلة في الدخول'));
      await settleAsync(tester);
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

      await tester.pumpWidget(testApp(const TrackingScreen(problemTitle: 'محضر')));
      await tester.pump(const Duration(seconds: 11));
      await settleAsync(tester);

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

  group('الطلبات الفعلية', () {
    testWidgets('لا توجد طلبات: حالة فارغة بلا أي بيانات تجريبية', (tester) async {
      await tester.pumpWidget(testApp(const Scaffold(body: OrdersTab())));
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

      await tester.pumpWidget(testApp(const TrackingScreen(problemTitle: 'محضر')));
      await tester.pump(const Duration(seconds: 11));
      await settleAsync(tester);

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
}
