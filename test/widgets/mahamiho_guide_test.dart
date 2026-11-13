import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_lawyer/features/client/mahamiho_bubble.dart';
import 'package:my_lawyer/features/client/mahamiho_figure.dart';
import 'package:my_lawyer/features/client/mahamiho_guide.dart';

Widget _host() => const MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: MahamihoGuide()),
      ),
    );

MahamihoMood _mood(WidgetTester tester) => tester.widget<MahamihoFigure>(find.byType(MahamihoFigure)).mood;

/// اللي مكتوب في الفقاعة دلوقتي
String _typed(WidgetTester tester) =>
    tester.widget<Text>(find.descendant(of: find.byType(MahamihoBubble), matching: find.byType(Text))).data!.trim();

void main() {
  setUp(MahamihoGuide.resetForTest);

  testWidgets('بيطلع من ورا الشريط مرة واحدة ويشاور، ونص جسمه بس', (tester) async {
    await tester.pumpWidget(_host());
    expect(find.byType(MahamihoFigure), findsNothing);

    await tester.pump(const Duration(milliseconds: 700));
    expect(_mood(tester), MahamihoMood.wave);
    expect(tester.widget<MahamihoFigure>(find.byType(MahamihoFigure)).halfBody, isTrue);
    // في الأول تحت الشريط، وبعد الطلعة مكانه ثابت ولازق في الشريط
    final bottom = tester.getRect(find.byType(MahamihoRise)).bottom;
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.getRect(find.byType(MahamihoFigure)).bottom, bottom);

    // بعد الحركة بيقف، ومن غير ما يتحرك من مكانه
    await tester.pump(MahamihoMood.clip);
    expect(_mood(tester), MahamihoMood.idle);
    expect(tester.getRect(find.byType(MahamihoFigure)).bottom, bottom);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('الفقاعة بتكتب الكلام حرف حرف وبعدين الجملة اللي بعدها', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 300));
    // بتبدأ تكتب: جزء من أول جملة بس
    await tester.pump(MahamihoBubble.typeEvery * 4);
    final first = MahamihoGuide.hello.first;
    expect(first.startsWith(_typed(tester)), isTrue);
    expect(_typed(tester).length, lessThan(first.length));

    // الجملة كاملة، وبعد ما تتمسح الجملة التانية بتتكتب
    for (var i = 0; i < first.length; i++) {
      await tester.pump(MahamihoBubble.typeEvery);
    }
    expect(_typed(tester), first);
    await tester.pump(MahamihoBubble.holdFull);
    for (var i = 0; i <= first.length; i++) {
      await tester.pump(MahamihoBubble.eraseEvery);
    }
    await tester.pump(const Duration(milliseconds: 250));
    for (var i = 0; i < 6; i++) {
      await tester.pump(MahamihoBubble.typeEvery);
    }
    expect(MahamihoGuide.hello[1].startsWith(_typed(tester)), isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('كل شوية بيعمل حركة: تمام، وبعدين بيفكّر، وبعدين بيشاور', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(MahamihoMood.clip);
    expect(_mood(tester), MahamihoMood.idle);

    for (final mood in [MahamihoMood.ok, MahamihoMood.thinking, MahamihoMood.wave]) {
      await tester.pump(const Duration(seconds: 6));
      expect(_mood(tester), mood);
      await tester.pump(MahamihoMood.clip);
      expect(_mood(tester), MahamihoMood.idle);
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('لمسه بيفتح صفحة محاميحو', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump(const Duration(seconds: 2));
    // يخلص طلعته الأول
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byType(MahamihoFigure));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('اكتب لمحاميحو...'), findsOneWidget);
    expect(find.text('محضر شرطة'), findsOneWidget);
  });

  testWidgets('على شاشة صغيرة بيفضل صغير وقاعد على الشريط، والفقاعة جوه الشاشة', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host());
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(seconds: 1));
    final box = tester.getRect(find.byType(MahamihoFigure));
    expect(box.width, lessThanOrEqualTo(120));
    expect(box.bottom, 640);
    expect(tester.getRect(find.byType(MahamihoBubble)).right, lessThanOrEqualTo(320));
    await tester.pumpWidget(const SizedBox());
  });
}
