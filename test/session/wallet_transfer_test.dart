import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_lawyer/core/config/app_config.dart';
import 'package:my_lawyer/features/client/wallet_tab.dart';
import '../helpers/session_test_helpers.dart';

void main() {
  setUpSessionTests();

  group('التحويل من المحفظة', () {
    testWidgets('التحويل مقفول في النسخة العادية، فالزرار مش ظاهر', (tester) async {
      await tester.pumpWidget(testApp(const Scaffold(body: WalletTab())));
      await settleAsync(tester);
      expect(find.text('تحويل لحساب تاني'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      },
      skip: AppConfig.walletTransfers,
    );

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

      await tester.pumpWidget(testApp(const Scaffold(body: WalletTab())));
      await settleAsync(tester);

      await tester.tap(find.text('تحويل لحساب تاني'));
      await settleAsync(tester);

      await tester.enterText(find.byType(TextField).at(0), '01000000002');
      await tester.enterText(find.byType(TextField).at(1), '50');
      await tester.tap(find.text('متابعة'));
      await settleAsync(tester);
      expect(find.text('المبلغ من 100 لـ 10000 ج.م'), findsOneWidget);
      expect(backend.countOf('GET /wallet/recipient'), 0);

      await tester.enterText(find.byType(TextField).at(1), '150');
      await tester.tap(find.text('متابعة'));
      await settleAsync(tester);
      expect(find.text('150 ج.م إلى أحمد م.'), findsOneWidget);

      await tester.tap(find.text('تأكيد التحويل'));
      await settleAsync(tester);
      expect(backend.countOf('POST /wallet/transfer'), 1);
      expect(find.text('تأكيد التحويل'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      },
      skip: !AppConfig.walletTransfers,
    );
  });
}
