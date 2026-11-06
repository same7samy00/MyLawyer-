import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_lawyer/core/services/invoice_pdf_service.dart';
import 'package:my_lawyer/data/models/payment_record.dart';
import 'package:my_lawyer/features/account/payments_screen.dart';
import '../helpers/session_test_helpers.dart';

void main() {
  setUpSessionTests();

  group('صفحة المدفوعات', () {
    testWidgets('كل دفعة بحالتها، والفاتورة للي اتدفعت بس', (tester) async {
      backend.overrides['GET /wallet/payments'] = (_) => FakeBackend.json(200, {
            'success': true,
            'data': [
              {'id': 'p1', 'reference': 'ML-PAY-100002', 'status': 'PAID', 'amount': 900, 'refunded': 0, 'method': 'DIRECT', 'at': '2026-11-06T10:00:00Z', 'orderNumber': 'ML-ORD-100002', 'service': 'محضر في قسم الشرطة', 'lawyerName': 'سارة ع.'},
              {'id': 'p2', 'reference': 'ML-PAY-100001', 'status': 'REFUNDED', 'amount': 350, 'refunded': 350, 'method': 'WALLET', 'at': '2026-11-05T10:00:00Z', 'orderNumber': 'ML-ORD-100001', 'service': 'قضية أسرة'},
              {'id': 'f1', 'reference': null, 'status': 'FAILED', 'amount': 350, 'refunded': 0, 'method': 'WALLET', 'reason': 'رصيدك مش كفاية', 'at': '2026-11-05T09:00:00Z', 'orderNumber': 'ML-ORD-100001', 'service': 'قضية أسرة'},
            ],
          });

      await tester.pumpWidget(testApp(const PaymentsScreen()));
      await settleAsync(tester);

      expect(find.text('المدفوعات'), findsOneWidget);
      expect(find.text('اتدفعت'), findsOneWidget);
      expect(find.text('اترد لرصيدك'), findsOneWidget);
      expect(find.text('ما تمتش'), findsOneWidget);
      expect(find.text('رصيدك مش كفاية'), findsOneWidget);
      expect(find.text('رجعلك 350 ج.م'), findsOneWidget);
      expect(find.text('تحميل الفاتورة PDF'), findsNWidgets(2));

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('مفيش مدفوعات لسه', (tester) async {
      backend.overrides['GET /wallet/payments'] = (_) => FakeBackend.json(200, {'success': true, 'data': []});
      await tester.pumpWidget(testApp(const PaymentsScreen()));
      await settleAsync(tester);
      expect(find.text('مفيش مدفوعات لسه'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    test('الفاتورة بتطلع ملف PDF بالعربي', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final bytes = await InvoicePdfService.build(PaymentRecord(
        id: 'p1',
        reference: 'ML-PAY-100002',
        status: 'PARTLY_REFUNDED',
        amount: 900,
        refunded: 300,
        method: 'DIRECT',
        service: 'محضر في قسم الشرطة',
        lawyerName: 'سارة ع.',
        orderNumber: 'ML-ORD-100002',
        at: DateTime(2026, 11, 6, 10, 5),
      ));
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      expect(bytes.length, greaterThan(2000));
    });
  });
}
