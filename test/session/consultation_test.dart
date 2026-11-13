import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_lawyer/features/client/mahamiho_bubble.dart';
import 'package:my_lawyer/features/consultation/consultation_checkout_screen.dart';
import 'package:my_lawyer/features/consultation/consultation_type_screen.dart';
import 'package:my_lawyer/features/consultation/mahamiho_request_screen.dart';
import 'package:my_lawyer/features/urgent_service/payment_method_screen.dart';
import 'package:my_lawyer/features/urgent_service/payment_screen.dart';
import 'package:my_lawyer/features/urgent_service/payment_success_screen.dart';
import '../helpers/session_test_helpers.dart';

void main() {
  setUpSessionTests();

  group('الاستشارة السريعة', () {
    testWidgets('النوع ← التفاصيل ← السعر من السيرفر ← الملخص ← الدفع بيبعت الطلب', (tester) async {
      Map<String, dynamic>? sentQuote;
      backend.overrides['GET /consultations/settings'] = (request) => FakeBackend.json(200, {
            'success': true,
            'data': {'maxPages': 10, 'callMinutes': 7, 'minDetailsChars': 20, 'isOpen': true},
          });
      backend.overrides['POST /consultations/quote'] = (request) {
        sentQuote = jsonDecode(request.body) as Map<String, dynamic>;
        return FakeBackend.json(200, {
          'success': true,
          'data': {
            'lines': [{'label': 'استشارة', 'amount': 200}],
            'total': 200,
            'callMinutes': 7,
          },
        });
      };

      await tester.pumpWidget(testApp(const QuickConsultationScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('استشارة بس'));
      await settleAsync(tester);
      expect(find.byType(MahamihoRequestScreen), findsOneWidget);

      // التبديل للكتابة، وبعدها محاميحو يقول «فهمت طلبك» والمتابعة للدفع
      await tester.tap(find.text('كتابة'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'صاحب الشقة عايز يطلعني قبل المدة من غير سبب');
      await tester.pump();
      await tester.tap(find.text('أرسل لمحاميحو'));
      await tester.pump();
      expect(find.byWidgetPredicate((w) => w is MahamihoBubble && w.lines.join(' ') == 'فهمت طلبك'), findsOneWidget);
      await tester.tap(find.text('متابعة للدفع'));
      await tester.pump(const Duration(seconds: 2));
      await settleAsync(tester);

      expect(sentQuote?['kind'], 'CALL');
      expect(find.byType(ConsultationCheckoutScreen), findsOneWidget);
      expect(find.text('200 ج.م'), findsWidgets);

      await tester.tap(find.text('موافق على الشروط'));
      await tester.pump();
      await tester.tap(find.text('متابعة للدفع'));
      await settleAsync(tester);
      expect(find.byType(PaymentScreen), findsOneWidget);
      expect(find.byType(PaymentMethodScreen), findsNothing);
      expect(find.byType(PaymentSuccessScreen), findsNothing);
    });
  });
}
