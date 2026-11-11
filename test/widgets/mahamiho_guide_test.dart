import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_lawyer/features/client/mahamiho_guide.dart';

Widget _host() => const MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: MahamihoGuide()),
      ),
    );

double _bubbleOpacity(WidgetTester tester) =>
    tester.widget<AnimatedOpacity>(find.ancestor(of: find.textContaining('أنا محاميحو'), matching: find.byType(AnimatedOpacity))).opacity;

void main() {
  setUp(MahamihoGuide.resetForTest);

  testWidgets('بيطلع ويقول الجملة، والجملة بتختفي وهو بيفضل موجود', (tester) async {
    await tester.pumpWidget(_host());
    expect(find.bySemanticsLabel('محاميحو'), findsNothing);

    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.bySemanticsLabel('محاميحو'), findsOneWidget);
    expect(_bubbleOpacity(tester), 1);

    await tester.pump(const Duration(seconds: 8));
    expect(_bubbleOpacity(tester), 0);
    expect(find.bySemanticsLabel('محاميحو'), findsOneWidget);
  });

  testWidgets('لمسه بيفتح صفحة محاميحو', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump(const Duration(seconds: 12));

    await tester.tap(find.bySemanticsLabel('محاميحو'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('اكتب لمحاميحو...'), findsOneWidget);
    expect(find.text('محضر شرطة'), findsOneWidget);
  });

  testWidgets('بعد أول مرة بيظهر واقف على طول من غير تلويح', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump(const Duration(seconds: 12));

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_host());
    expect(find.bySemanticsLabel('محاميحو'), findsOneWidget);
    expect(_bubbleOpacity(tester), 0);
  });

  testWidgets('على شاشة صغيرة بيفضل صغير، لازق في تحت، وجوه الشاشة', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host());
    await tester.pump(const Duration(milliseconds: 2100));
    final box = tester.getRect(find.bySemanticsLabel('محاميحو'));
    expect(box.width, lessThanOrEqualTo(110));
    expect(box.left, greaterThanOrEqualTo(0));
    expect(box.bottom, 640);
    expect(tester.getRect(find.textContaining('أنا محاميحو')).right, lessThanOrEqualTo(320));
    await tester.pump(const Duration(seconds: 10));
  });
}
