import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_lawyer/features/client/mahamiho_figure.dart';
import 'package:my_lawyer/features/client/mahamiho_guide.dart';

Widget _host() => const MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: MahamihoGuide()),
      ),
    );

final _cloudText = find.text(MahamihoGuide.hello);

MahamihoMood _mood(WidgetTester tester) => tester.widget<MahamihoFigure>(find.byType(MahamihoFigure)).mood;

/// مكان محاميحو والسحابة من تحت: لما بينطوا الاتنين بيطلعوا مع بعض
double _figureBottom(WidgetTester tester) => tester.getRect(find.byType(MahamihoFigure)).bottom;
double _cloudBottom(WidgetTester tester) => tester.getRect(_cloudText).bottom;

void main() {
  setUp(MahamihoGuide.resetForTest);

  testWidgets('بيظهر بنطة ويشاور، وهو والسحابة بينطوا مع بعض، ونص جسمه بس', (tester) async {
    await tester.pumpWidget(_host());
    expect(find.byType(MahamihoFigure), findsNothing);

    await tester.pump(const Duration(milliseconds: 1200));
    expect(_mood(tester), MahamihoMood.wave);
    expect(tester.widget<MahamihoFigure>(find.byType(MahamihoFigure)).halfBody, isTrue);
    final restFigure = _figureBottom(tester);
    final restCloud = _cloudBottom(tester);

    // في نص النطة الاتنين أعلى بنفس المسافة
    await tester.pump(const Duration(milliseconds: 250));
    final lift = restFigure - _figureBottom(tester);
    expect(lift, greaterThan(5));
    expect(restCloud - _cloudBottom(tester), closeTo(lift, 0.5));

    // بعد الحركة بيقف، والسحابة ظاهرة
    await tester.pump(MahamihoMood.clip);
    expect(_mood(tester), MahamihoMood.idle);
    expect(_cloudText, findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('كل شوية بينط ويعمل حركة: تمام، وبعدين بيفكّر، وبعدين بيشاور', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump(const Duration(milliseconds: 1200));
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

    await tester.tap(find.byType(MahamihoFigure));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('اكتب لمحاميحو...'), findsOneWidget);
    expect(find.text('محضر شرطة'), findsOneWidget);
  });

  testWidgets('على شاشة صغيرة بيفضل صغير وقاعد على الشريط، والسحابة جوه الشاشة', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host());
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump(const Duration(seconds: 1));
    final box = tester.getRect(find.byType(MahamihoFigure));
    expect(box.width, lessThanOrEqualTo(120));
    expect(box.bottom, 640);
    expect(tester.getRect(_cloudText).right, lessThanOrEqualTo(320));
    await tester.pumpWidget(const SizedBox());
  });
}
