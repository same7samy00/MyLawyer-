import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_lawyer/core/services/api_service.dart';
import 'package:my_lawyer/core/services/auth_service.dart';
import 'package:my_lawyer/core/services/live_updates.dart';
import 'package:my_lawyer/data/models/order_model.dart';
import 'package:my_lawyer/data/models/service_request.dart';
import 'package:my_lawyer/features/auth/account_suspended_screen.dart';
import 'package:my_lawyer/features/auth/session_router.dart';
import 'package:my_lawyer/features/auth/splash_screen.dart';
import 'package:my_lawyer/features/client/orders_tab.dart';
import 'package:my_lawyer/features/lawyer/lawyer_orders_tab.dart';
import 'package:my_lawyer/features/lawyer/request_offer_sheet.dart';
import 'package:my_lawyer/features/notifications/notifications_screen.dart';
import 'package:my_lawyer/features/support/support_screen.dart';
import 'package:my_lawyer/features/urgent_service/tracking_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      expect(find.textContaining('ML-ORD-100001'), findsNothing);

      await tester.tap(find.text('سجل الطلبات'));
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

    testWidgets('صفحة التقييم تفتح لوحدها للموكل أول ما المحامي ينهي المهمة', (tester) async {
      backend.orders = [
        {...sampleOrder(status: 'ACTIVE'), 'arrivedAt': DateTime.now().toIso8601String()},
      ];
      await openOrderDetails(tester);
      // صفحة التفاصيل مفتوحة، ومفيش نوافذ سفلية
      expect(find.text('تفاصيل الطلب'), findsWidgets);
      expect(find.byType(BottomSheet), findsNothing);

      backend.orders = [
        {...sampleOrder(status: 'COMPLETED'), 'completedAt': DateTime.now().toIso8601String()},
      ];
      // السيرفر بيقول إن الطلب ده بالذات اتغير، فبيتجاب لوحده
      LiveUpdates.announce(const LiveChange('orders', 'order-1'));
      await settleAsync(tester);

      // صفحة التقييم فوق صفحة التفاصيل
      expect(find.text('قيّم المحامي'), findsOneWidget);
      expect(find.text('إرسال التقييم'), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);

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
          'arrivedAt': DateTime.now().toIso8601String(),
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

    testWidgets('الموكل يشوف حدود السعر، والعروض تظهر، واختيار عرض يفتح الدفع بسعره', (tester) async {
      mockPhoneLocation();
      backend.lawyers = [
        {
          'id': 'lawyer-1',
          'name': 'أ/ طارق حسن',
          'rating': 4.8,
          'reviewsCount': 12,
          'experienceYears': 7,
          'coordinates': [30.05, 31.24],
          'distanceKm': 1.2,
        },
      ];
      backend.overrides['POST /requests'] = (request) => FakeBackend.json(201, {'success': true, 'data': {'id': 'req-1'}});
      backend.overrides['GET /requests/req-1'] = (request) => FakeBackend.json(200, {
            'success': true,
            'data': {
              'id': 'req-1',
              'status': 'OPEN',
              'round': 1,
              'secondsLeft': 100,
              'offers': [
                {'id': 'of-1', 'lawyerId': 'lawyer-1', 'name': 'أ/ سارة علي', 'rating': 4.6, 'reviewsCount': 3, 'price': 900, 'distanceKm': 2.5, 'minutesAway': 7},
              ],
            },
          });
      backend.overrides['POST /requests/req-1/offers/of-1/select'] = (request) => FakeBackend.json(200, {
            'success': true,
            'data': {'orderId': 'order-1', 'orderNumber': 'ML-ORD-100002', 'price': 900, 'lawyerId': 'lawyer-1'},
          });

      await tester.pumpWidget(testApp(const TrackingScreen(problemTitle: 'محضر')));
      await tester.pump(const Duration(seconds: 11));
      await settleAsync(tester);

      await tester.tap(find.text('اطلب عروض أسعار'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('من 500 لـ 1500 ج.م'), findsOneWidget);

      await tester.tap(find.text('ابعت الطلب'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('900 ج.م'), findsOneWidget);
      expect(find.text('أ/ سارة علي'), findsOneWidget);

      await tester.tap(find.text('اختار العرض'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(backend.countOf('POST /requests/req-1/offers/of-1/select'), 1);
      expect(find.text('دفع 900 ج.م وتأكيد الطلب'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('المحامي يبعت سعر جوه الحدود بس ويشوف صافيه', (tester) async {
      backend.overrides['POST /requests/req-1/offer'] = (request) {
        expect((jsonDecode(request.body) as Map<String, dynamic>)['price'], 1000);
        return FakeBackend.json(201, {'success': true});
      };
      await tester.pumpWidget(testApp(const Scaffold(body: RequestOfferSheet(
        request: IncomingRequest(id: 'req-1', problemType: 'محضر', problemDescription: 'وصف', area: 'محافظة القاهرة', distanceKm: 4, minPrice: 500, maxPrice: 1500, netRate: 0.7, secondsLeft: 100),
      ),),),);
      await tester.pump();

      await tester.tap(find.text('ابعت عرضك'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '200');
      await tester.pump();
      expect(find.text('السعر لازم يكون من 500 لـ 1500 ج.م'), findsOneWidget);
      await tester.tap(find.text('إرسال'));
      await tester.pump();
      expect(backend.countOf('POST /requests/req-1/offer'), 0);

      await tester.tap(find.text('المتوسط'));
      await tester.pump();
      expect(find.text('صافي ليك: 700 ج.م'), findsOneWidget);
      await tester.tap(find.text('إرسال'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(backend.countOf('POST /requests/req-1/offer'), 1);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('طلب جديد يظهر أول صفحة طلبات المحامي بزر التفاصيل', (tester) async {
      backend.overrides['GET /requests/incoming'] = (_) => FakeBackend.json(200, {
            'success': true,
            'data': [
              {'id': 'req-1', 'problemType': 'محضر', 'problemDescription': 'وصف', 'distanceKm': 4, 'minPrice': 500, 'maxPrice': 1500, 'netRate': 0.7, 'secondsLeft': 100},
            ],
          });
      await tester.pumpWidget(testApp(const Scaffold(body: LawyerOrdersTab())));
      await settleAsync(tester);

      expect(find.textContaining('ابعت سعرك • باقي'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.chevron_right_rounded));
      await settleAsync(tester);
      expect(find.text('ابعت عرضك'), findsOneWidget);
      expect(find.text('العنوان'), findsOneWidget);
      expect(find.text('الخدمة'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('الطلبات الفعلية', () {
    testWidgets('لا توجد طلبات: حالة فارغة بلا أي بيانات تجريبية', (tester) async {
      await tester.pumpWidget(testApp(const Scaffold(body: OrdersTab())));
      await tester.pumpAndSettle();

      expect(find.text('مفيش طلبات حالية'), findsOneWidget);
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

    testWidgets('من غير موقع حقيقي الطلب ما يتبعتش', (tester) async {
      backend.lawyers = [
        {'id': 'lawyer-1', 'name': 'أ/ طارق حسن', 'rating': 4.8, 'reviewsCount': 12, 'experienceYears': 7, 'coordinates': [30.05, 31.24], 'distanceKm': 1.2},
      ];

      await tester.pumpWidget(testApp(const TrackingScreen(problemTitle: 'محضر')));
      await tester.pump(const Duration(seconds: 11));
      await settleAsync(tester);

      await tester.tap(find.text('اطلب عروض أسعار'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('ابعت الطلب'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(backend.countOf('POST /requests'), 0);
      expect(find.text('ابعت الطلب'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('فشل إرسال الطلب يرجع الموكل للخريطة برسالة واضحة', (tester) async {
      mockPhoneLocation();
      backend.lawyers = [
        {
          'id': 'lawyer-1',
          'name': 'أ/ طارق حسن',
          'rating': 4.8,
          'reviewsCount': 12,
          'experienceYears': 7,
          'coordinates': [30.05, 31.24],
          'distanceKm': 1.2,
        },
      ];
      backend.overrides['POST /requests'] = (_) => FakeBackend.json(409, {'success': false, 'error': 'مفيش محامي متاح دلوقتي، جرب تاني كمان شوية'});

      await tester.pumpWidget(testApp(const TrackingScreen(problemTitle: 'محضر')));
      await tester.pump(const Duration(seconds: 11));
      await settleAsync(tester);

      await tester.tap(find.text('اطلب عروض أسعار'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('ابعت الطلب'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(backend.countOf('POST /requests'), 1);
      expect(find.text('مفيش محامي متاح دلوقتي، جرب تاني كمان شوية'), findsOneWidget);
      expect(find.text('اطلب عروض أسعار'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
    });
  });
}
