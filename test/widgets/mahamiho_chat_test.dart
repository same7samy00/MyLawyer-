import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_lawyer/features/client/legal_services.dart';
import 'package:my_lawyer/features/client/mahamiho_bubble.dart';
import 'package:my_lawyer/features/client/mahamiho_chat_screen.dart';
import 'package:my_lawyer/features/client/mahamiho_talk.dart';
import 'package:my_lawyer/features/consultation/consultation_evaluating_screen.dart';

Widget _host() => const MaterialApp(
      home: Directionality(textDirection: TextDirection.rtl, child: MahamihoChatScreen()),
    );

/// آخر رد لمحاميحو: كل جملة في فقاعة
String _says(WidgetTester tester) => tester.widgetList<MahamihoSpeech>(find.byType(MahamihoSpeech)).map((b) => b.text).join(' ');

/// يكتب للمحاميحو ويستنى رده («بيكتب...» على قد طول الرد)
Future<void> _say(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.tap(find.bySemanticsLabel('إرسال'));
  await tester.pump(const Duration(seconds: 2));
  // النزول لآخر الكلام بياخد لحظة
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('بيبدأ بالترحيب والخدمات التمانية', (tester) async {
    await tester.pumpWidget(_host());
    expect(_says(tester), contains('أنا محاميحو'));
    for (final s in LegalService.all) {
      expect(find.text(s.title), findsOneWidget);
    }
  });

  testWidgets('خدمة ميدانية: سؤال على قدها، وبيلقط إن الطلب لقريبه ومستعجل، وبيفتح صفحة الطلب', (tester) async {
    await tester.pumpWidget(_host());
    await tester.tap(find.text('محضر شرطة'));
    await tester.pump(const Duration(seconds: 2));
    expect(_says(tester), contains('مين اللي في القسم'));

    await _say(tester, 'أخويا اتقبض عليه دلوقتي في قسم الدقي');
    expect(_says(tester), contains('«أخويا اتقبض عليه دلوقتي في قسم الدقي»'));
    expect(_says(tester), contains('لـ أخوك'));
    expect(_says(tester), contains('مستعجل'));
    expect(_says(tester), contains('ليك ولا لحد تاني'));
    expect(find.text('يلا بينا'), findsOneWidget);
    expect(find.text('عدّل'), findsOneWidget);
  });

  testWidgets('الكتابة من غير اختيار بتخمّن الخدمة من الكلام', (tester) async {
    await tester.pumpWidget(_host());
    await _say(tester, 'عندي تحقيق في النيابة بكرة');
    expect(_says(tester), contains('«تحقيق نيابة»'));
  });

  testWidgets('خدمة مكتبية: بيطلب تفاصيل كفاية، وبعد التأكيد بيروح على الدفع على طول', (tester) async {
    await tester.pumpWidget(_host());
    await tester.tap(find.text('استشارة قانونية'));
    await tester.pump(const Duration(seconds: 2));
    expect(_says(tester), contains('احكيلي مشكلتك بالتفصيل'));

    await _say(tester, 'مشكلة إيجار');
    expect(_says(tester), contains('محتاج أفهم أكتر'));
    expect(find.text('أيوه، كمّل للدفع'), findsNothing);

    await _say(tester, 'صاحب الشقة عايز يطلعني قبل ما العقد يخلص من غير سبب، والعقد لسه فيه سنة');
    expect(_says(tester), contains('أكمّل للدفع؟'));
    await tester.tap(find.text('أيوه، كمّل للدفع'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    // مفيش صفحة صوت ولا كتابة تاني: على تقييم السعر والدفع على طول
    expect(find.byType(ConsultationEvaluatingScreen), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('السلام والكلام المش واضح', (tester) async {
    await tester.pumpWidget(_host());
    await _say(tester, 'السلام عليكم');
    expect(_says(tester), contains('وعليكم السلام'));
    await _say(tester, 'محتاج مساعدة');
    expect(_says(tester), contains('مش متأكد إني فهمتك'));
  });

  test('الترحيب على قد وقت اليوم واسم الموكل', () {
    final name = MahamihoTalk.firstNameFrom({'fullName': 'محمد أحمد علي'});
    expect(name, 'محمد');
    expect(MahamihoTalk(firstName: name, now: DateTime(2026, 1, 1, 9)).hello(), startsWith('صباح الخير يا محمد'));
    expect(MahamihoTalk(now: DateTime(2026, 1, 1, 21)).hello(), startsWith('مساء الخير 👋'));
    expect(MahamihoTalk.sentences(MahamihoTalk(now: DateTime(2026, 1, 1, 9)).hello()).length, 2);
  });

  test('هيدر طلب المحامي باسم الخدمة المختارة', () {
    expect(LegalService.titleFor('محضر في قسم الشرطة'), 'محضر شرطة');
    expect(LegalService.titleFor('حضور مجلس عرفي'), 'حضور مجلس عرفي');
    expect(LegalService.titleFor('سرقة أو نصب أو احتيال'), 'سرقة أو نصب أو احتيال');
    expect(LegalService.titleFor(null), 'طلب محامي');
  });
}
