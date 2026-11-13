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

/// الجزء الظاهر من محاميحو فوق الشريط (القص عند حافة الشاشة تحت)
double _visible(WidgetTester tester) {
  final clip = tester.getRect(find.ancestor(of: find.byType(MahamihoFigure), matching: find.byType(ClipRect)).first);
  final figure = tester.getRect(find.byType(MahamihoFigure));
  return (clip.bottom - figure.top).clamp(0, clip.height).toDouble();
}

double _full(WidgetTester tester) => tester.getRect(find.ancestor(of: find.byType(MahamihoFigure), matching: find.byType(ClipRect)).first).height;

/// بيعدّي الوقت لحد ما الشرط يتحقق
Future<void> _until(WidgetTester tester, bool Function() done, {int seconds = 30}) async {
  for (var i = 0; i < seconds * 10 && !done(); i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(done(), isTrue);
}

void main() {
  setUp(MahamihoGuide.resetForTest);

  testWidgets('بيطلع من ورا الشريط بسحب ناعم (من غير قفز) ويشاور، ونص جسمه بس', (tester) async {
    await tester.pumpWidget(_host());
    // في الأول مستخبي ورا الشريط
    expect(_visible(tester), 0);

    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 200));
    // في نص الطلعة: ظاهر جزء بس
    expect(_visible(tester), greaterThan(0));
    expect(_visible(tester), lessThan(_full(tester)));

    // الطلعة ناعمة: ما بتعدّيش مكانه النهائي (مفيش ارتداد)
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      expect(_visible(tester), lessThanOrEqualTo(_full(tester) + 0.01));
    }
    expect(_visible(tester), closeTo(_full(tester), 0.5));
    expect(_mood(tester), MahamihoMood.wave);
    expect(tester.widget<MahamihoFigure>(find.byType(MahamihoFigure)).halfBody, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('الفقاعة بتكتب الكلام حرف حرف وبعدين الجملة اللي بعدها', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 700));
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

  testWidgets('بعد ما يخلّص كلامه الفقاعة تختفي وينزل ويفضل نص دماغه بس', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump(const Duration(milliseconds: 700));
    await _until(tester, () => find.byType(MahamihoBubble).evaluate().isNotEmpty);
    await _until(tester, () => find.byType(MahamihoBubble).evaluate().isEmpty);
    await tester.pump(const Duration(seconds: 1));

    final shown = _visible(tester);
    expect(shown, greaterThan(0));
    expect(shown, closeTo(_full(tester) * 0.27, 1));
    expect(_mood(tester), MahamihoMood.idle);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('لمسه وهو نازل بيطلعه ويتكلم تاني، ولمسه وهو طالع بيفتح صفحة محاميحو', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump(const Duration(milliseconds: 700));
    await _until(tester, () => find.byType(MahamihoBubble).evaluate().isEmpty && _visible(tester) < _full(tester) * 0.3 && _visible(tester) > 1);

    await tester.tapAt(tester.getRect(find.byType(MahamihoFigure)).topCenter + const Offset(0, 6));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(_visible(tester), closeTo(_full(tester), 0.5));
    expect(find.byType(MahamihoBubble), findsOneWidget);
    expect(find.text('أو اكتب مشكلتك هنا...'), findsNothing);

    // وهو طالع: صفحة محاميحو
    await tester.tap(find.byType(MahamihoFigure));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('أو اكتب مشكلتك هنا...'), findsOneWidget);
    expect(find.text('محضر شرطة'), findsOneWidget);
  });

  testWidgets('على شاشة صغيرة بيفضل صغير وقاعد على الشريط، والفقاعة جوه الشاشة', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host());
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(seconds: 2));
    final box = tester.getRect(find.byType(MahamihoFigure));
    expect(box.width, lessThanOrEqualTo(120));
    expect(box.bottom, 640);
    expect(tester.getRect(find.byType(MahamihoBubble)).right, lessThanOrEqualTo(320));
    await tester.pumpWidget(const SizedBox());
  });
}
