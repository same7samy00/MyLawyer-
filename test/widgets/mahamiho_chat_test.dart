import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_lawyer/features/client/legal_services.dart';
import 'package:my_lawyer/features/client/mahamiho_chat_screen.dart';

Widget _host() => const MaterialApp(
      home: Directionality(textDirection: TextDirection.rtl, child: MahamihoChatScreen()),
    );

void main() {
  testWidgets('بيبدأ بالترحيب والخدمات التمانية', (tester) async {
    await tester.pumpWidget(_host());
    expect(find.textContaining('أنا محاميحو'), findsOneWidget);
    for (final s in LegalService.all) {
      expect(find.text(s.title), findsOneWidget);
    }
  });

  testWidgets('اختيار خدمة ووصف المشكلة بيوصل لسؤال التأكيد', (tester) async {
    await tester.pumpWidget(_host());
    await tester.tap(find.text('محضر شرطة'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('احكيلي في سطرين'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'أخويا اتقبض عليه في قسم الدقي');
    await tester.tap(find.bySemanticsLabel('إرسال'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('جهّزتلك طلب «محضر شرطة»'), findsOneWidget);
    expect(find.text('أيوه، كمّل'), findsOneWidget);
    expect(find.text('عدّل'), findsOneWidget);
  });

  testWidgets('الكتابة من غير اختيار بتخمّن الخدمة من الكلام', (tester) async {
    await tester.pumpWidget(_host());
    await tester.enterText(find.byType(TextField), 'عندي تحقيق في النيابة بكرة');
    await tester.tap(find.bySemanticsLabel('إرسال'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('«تحقيق نيابة»'), findsOneWidget);
  });

  testWidgets('كلام مش واضح بيرجّع الخدمات يختار منها', (tester) async {
    await tester.pumpWidget(_host());
    await tester.enterText(find.byType(TextField), 'محتاج مساعدة');
    await tester.tap(find.bySemanticsLabel('إرسال'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('اختار الخدمة الأقرب'), findsOneWidget);
  });
}
