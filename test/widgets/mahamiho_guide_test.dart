import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_lawyer/features/client/mahamiho_guide.dart';

Widget _host() => const MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: MahamihoGuide()),
      ),
    );

final _cloudText = find.text(MahamihoGuide.hello);

Offset _cloudSlide(WidgetTester tester) =>
    tester.widget<AnimatedSlide>(find.ancestor(of: _cloudText, matching: find.byType(AnimatedSlide))).offset;

String _clip(WidgetTester tester) =>
    ((tester.widget<Image>(find.descendant(of: find.bySemanticsLabel('محاميحو'), matching: find.byType(Image))).image) as AssetImage).assetName;

void main() {
  setUp(MahamihoGuide.resetForTest);

  testWidgets('بيطلع ويشاور والسحابة بتطلع معاه وبتفضل ظاهرة', (tester) async {
    await tester.pumpWidget(_host());
    expect(find.bySemanticsLabel('محاميحو'), findsNothing);

    await tester.pump(const Duration(milliseconds: 1200));
    expect(_clip(tester), 'assets/mahamiho/pop-wave.webp');
    // أول لقطة: السحابة ورا الشريط معاه
    expect(_cloudSlide(tester), const Offset(0, 1.05));
    await tester.pump();
    await tester.pump();
    expect(_cloudSlide(tester), Offset.zero);

    await tester.pump(const Duration(seconds: 10));
    expect(find.bySemanticsLabel('محاميحو'), findsOneWidget);
    expect(_cloudText, findsOneWidget);
    await tester.pump();
    expect(_cloudSlide(tester), Offset.zero);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('كل 5 ثواني بيعمل حركة مختلفة، واللايك ما بيحرّكش السحابة', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 66 * 42 + 10));
    expect(_clip(tester), 'assets/mahamiho/idle.webp');

    await tester.pump(const Duration(seconds: 5));
    expect(_clip(tester), 'assets/mahamiho/pop-up.webp');
    await tester.pump();

    await tester.pump(const Duration(milliseconds: 61 * 42 + 10));
    await tester.pump(const Duration(seconds: 5));
    expect(_clip(tester), 'assets/mahamiho/like.webp');
    expect(_cloudSlide(tester), Offset.zero);

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

  testWidgets('على شاشة صغيرة بيفضل صغير، والسحابة قاعدة على الشريط وجوه الشاشة', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host());
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final box = tester.getRect(find.bySemanticsLabel('محاميحو'));
    expect(box.width, lessThanOrEqualTo(110));
    expect(box.bottom, 640);
    final cloud = tester.getRect(find.ancestor(of: _cloudText, matching: find.byType(ClipRect)).first);
    expect(cloud.bottom, 640);
    expect(cloud.right, lessThanOrEqualTo(320));
    await tester.pumpWidget(const SizedBox());
  });
}
