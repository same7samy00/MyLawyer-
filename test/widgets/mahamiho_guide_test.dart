import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_lawyer/features/client/mahamiho_guide.dart';

Widget _host() => const MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: Stack(children: [MahamihoGuide()])),
      ),
    );

void main() {
  setUp(MahamihoGuide.resetForTest);

  testWidgets('محاميحو بيطلع ويقول الجملة، وبعدين ينزل لوحده', (tester) async {
    await tester.pumpWidget(_host());
    expect(find.bySemanticsLabel('محاميحو'), findsNothing);

    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.bySemanticsLabel('محاميحو'), findsOneWidget);
    expect(find.textContaining('أنا محاميحو'), findsOneWidget);

    await tester.pump(const Duration(seconds: 8));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('محاميحو'), findsNothing);
  });

  testWidgets('بيظهر مرة واحدة بس في كل فتحة للتطبيق', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_host());
    await tester.pump(const Duration(seconds: 2));
    expect(find.bySemanticsLabel('محاميحو'), findsNothing);
  });

  testWidgets('على شاشة صغيرة بيفضل صغير وجوه الشاشة', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host());
    await tester.pump(const Duration(milliseconds: 2100));
    final box = tester.getRect(find.bySemanticsLabel('محاميحو'));
    expect(box.width, lessThanOrEqualTo(120));
    expect(box.left, greaterThanOrEqualTo(0));
    expect(tester.getRect(find.textContaining('أنا محاميحو')).right, lessThanOrEqualTo(320));

    await tester.pump(const Duration(seconds: 9));
    await tester.pumpAndSettle();
  });
}
