import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_lawyer/features/client/mahamiho_guide.dart';

Widget _host() => const MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: MahamihoGuide()),
      ),
    );

final _badgeImage = find.byWidgetPredicate((w) => w is Image && w.image is AssetImage && (w.image as AssetImage).assetName.endsWith('hello.webp'));

double _badgeOpacity(WidgetTester tester) =>
    tester.widget<AnimatedOpacity>(find.ancestor(of: _badgeImage, matching: find.byType(AnimatedOpacity))).opacity;

String _clip(WidgetTester tester) =>
    ((tester.widget<Image>(find.descendant(of: find.bySemanticsLabel('محاميحو'), matching: find.byType(Image))).image) as AssetImage).assetName;

void main() {
  setUp(MahamihoGuide.resetForTest);

  testWidgets('بيطلع ويشاور، وصورة الترحيب بتظهر وتختفي، وهو بيفضل موجود', (tester) async {
    await tester.pumpWidget(_host());
    expect(find.bySemanticsLabel('محاميحو'), findsNothing);

    await tester.pump(const Duration(milliseconds: 1300));
    expect(find.bySemanticsLabel('محاميحو'), findsOneWidget);
    expect(_clip(tester), 'assets/mahamiho/pop-wave.webp');
    expect(_badgeOpacity(tester), 1);

    await tester.pump(const Duration(seconds: 4));
    expect(_badgeOpacity(tester), 0);
    expect(find.bySemanticsLabel('محاميحو'), findsOneWidget);
  });

  testWidgets('كل 5 ثواني بيعمل حركة مختلفة', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pump(const Duration(milliseconds: 66 * 42 + 10));
    expect(_clip(tester), 'assets/mahamiho/idle.webp');

    await tester.pump(const Duration(seconds: 5));
    expect(_clip(tester), 'assets/mahamiho/pop-up.webp');
    expect(_badgeOpacity(tester), 1);

    await tester.pump(const Duration(milliseconds: 61 * 42 + 10));
    await tester.pump(const Duration(seconds: 5));
    expect(_clip(tester), 'assets/mahamiho/like.webp');

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('لمسه بيفتح صفحة محاميحو', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump(const Duration(seconds: 2));

    await tester.tap(find.bySemanticsLabel('محاميحو'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('اكتب لمحاميحو...'), findsOneWidget);
    expect(find.text('محضر شرطة'), findsOneWidget);
  });

  testWidgets('على شاشة صغيرة بيفضل صغير، لازق في تحت، وجوه الشاشة', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host());
    await tester.pump(const Duration(milliseconds: 1300));
    final box = tester.getRect(find.bySemanticsLabel('محاميحو'));
    expect(box.width, lessThanOrEqualTo(110));
    expect(box.left, greaterThanOrEqualTo(0));
    expect(box.bottom, 640);
    expect(tester.getRect(find.bySemanticsLabel('أهلاً أنا محاميحو موجود هنا لمساعدتك')).right, lessThanOrEqualTo(320));
    await tester.pumpWidget(const SizedBox());
  });
}
