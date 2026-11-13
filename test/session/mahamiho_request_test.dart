import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_lawyer/core/services/voice_input.dart';
import 'package:my_lawyer/data/models/consultation.dart';
import 'package:my_lawyer/features/client/mahamiho_bubble.dart';
import 'package:my_lawyer/features/client/mahamiho_figure.dart';
import 'package:my_lawyer/features/consultation/consultation_checkout_screen.dart';
import 'package:my_lawyer/features/consultation/consultation_pages_screen.dart';
import 'package:my_lawyer/features/consultation/mahamiho_request_screen.dart';
import '../helpers/session_test_helpers.dart';

/// كل اللي محاميحو بيقوله في الفقاعة دلوقتي (بيتكتب على مرات)
String _says(WidgetTester tester) => tester.widget<MahamihoBubble>(find.byType(MahamihoBubble)).lines.join(' ');

/// ميكروفون وهمي: بيرجّع الكلام اللي اتحدد من غير ما يلمس الموبايل
class _FakeVoice implements VoiceInput {
  final VoiceReady ready;
  final String heard;
  bool started = false;

  _FakeVoice({this.ready = VoiceReady.ready, this.heard = ''});

  @override
  Future<VoiceReady> prepare() async => ready;

  @override
  Future<void> start({required VoidCallback onFailure}) async => started = true;

  @override
  Future<String> stop() async => heard;

  @override
  Future<void> cancel() async => started = false;

  @override
  final ValueNotifier<double> level = ValueNotifier(0);
}

const _story = 'اتفقت مع صاحب الشقة على الإيجار لمدة سنة، ودلوقتي عايز يطلعني قبل المدة من غير سبب';

void main() {
  setUpSessionTests();

  // شاشة موبايل حقيقية، مش شاشة الاختبار العريضة
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first;
    view.physicalSize = const Size(1170, 2532);
    view.devicePixelRatio = 3;
  });
  tearDown(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  void fakeServer() {
    backend.overrides['GET /consultations/settings'] = (request) => FakeBackend.json(200, {
          'success': true,
          'data': {'maxPages': 10, 'callMinutes': 7, 'minDetailsChars': 20, 'isOpen': true},
        });
    backend.overrides['POST /consultations/quote'] = (request) => FakeBackend.json(200, {
          'success': true,
          'data': {
            'lines': [{'label': 'استشارة', 'amount': 200}],
            'total': 200,
            'callMinutes': 7,
          },
        });
  }

  group('محاميحو: الخدمات المكتبية بالصوت والكتابة', () {
    testWidgets('الكلام بيتحول لنص، والعميل ما بيشوفوش، ومحاميحو يقول «فهمت طلبك»', (tester) async {
      fakeServer();
      final voice = _FakeVoice(heard: _story);
      await tester.pumpWidget(testApp(MahamihoRequestScreen(kind: ConsultationKind.call, serviceTitle: ConsultationKind.call.serviceName, voice: voice)));
      await settleAsync(tester);

      expect(_says(tester), contains('احكيلي محتاج إيه'));
      await tester.tap(find.byIcon(Icons.mic_rounded).last);
      await settleAsync(tester);
      expect(voice.started, isTrue);
      expect(_says(tester), contains('خد وقتك'));

      await tester.tap(find.byIcon(Icons.stop_rounded));
      await settleAsync(tester);
      expect(_says(tester), 'فهمت طلبك');
      expect(find.text(_story), findsNothing);

      await tester.tap(find.text('متابعة للدفع'));
      await tester.pump(const Duration(seconds: 2));
      await settleAsync(tester);
      expect(find.byType(ConsultationCheckoutScreen), findsOneWidget);
      expect(find.text('كلامك اتسجّل وهيوصل لفريق المحامين'), findsOneWidget);
      expect(find.text(_story), findsNothing);
    });

    testWidgets('في الصوت محاميحو في نص الشاشة جوه دايرة بتكبر مع صوت العميل', (tester) async {
      fakeServer();
      final voice = _FakeVoice(heard: _story);
      await tester.pumpWidget(testApp(MahamihoRequestScreen(kind: ConsultationKind.call, serviceTitle: ConsultationKind.call.serviceName, voice: voice)));
      await settleAsync(tester);

      final figure = find.byType(MahamihoFigure);
      expect(find.ancestor(of: figure, matching: find.byType(ClipPath)), findsWidgets);
      // في نص الشاشة بالعرض
      final screen = tester.getRect(find.byType(Scaffold).first);
      expect((tester.getCenter(figure).dx - screen.center.dx).abs(), lessThan(20));

      await tester.tap(find.byIcon(Icons.mic_rounded).last);
      await settleAsync(tester);
      Size ring() => tester.getSize(find.byKey(const ValueKey('voice-ring')));
      voice.level.value = 0;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final quiet = ring().width;
      voice.level.value = 1;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(ring().width, greaterThan(quiet + 40));
      await tester.tap(find.byIcon(Icons.stop_rounded));
      await settleAsync(tester);
    });

    testWidgets('كلام قصير: محاميحو يطلب يكمّل، ومفيش متابعة', (tester) async {
      fakeServer();
      await tester.pumpWidget(testApp(MahamihoRequestScreen(kind: ConsultationKind.call, serviceTitle: ConsultationKind.call.serviceName, voice: _FakeVoice(heard: 'مشكلة'))));
      await settleAsync(tester);

      await tester.tap(find.byIcon(Icons.mic_rounded).last);
      await settleAsync(tester);
      await tester.tap(find.byIcon(Icons.stop_rounded));
      await settleAsync(tester);

      expect(_says(tester), contains('عشان أفهمك أحسن'));
      expect(find.text('متابعة للدفع'), findsNothing);
    });

    testWidgets('الميكروفون مش شغال: رسالة، وبيتحول للكتابة لوحده', (tester) async {
      fakeServer();
      await tester.pumpWidget(testApp(MahamihoRequestScreen(kind: ConsultationKind.call, serviceTitle: ConsultationKind.call.serviceName, voice: _FakeVoice(ready: VoiceReady.unavailable))));
      await settleAsync(tester);

      await tester.tap(find.byIcon(Icons.mic_rounded).last);
      await settleAsync(tester);

      expect(find.byType(TextField), findsOneWidget);
      expect(_says(tester), contains('اكتبلي محتاج إيه'));
    });

    testWidgets('التبديل بين الصوت والكتابة في أي وقت، والكتابة بتظهر للعميل', (tester) async {
      fakeServer();
      await tester.pumpWidget(testApp(MahamihoRequestScreen(kind: ConsultationKind.call, serviceTitle: ConsultationKind.call.serviceName, voice: _FakeVoice())));
      await settleAsync(tester);

      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.text('كتابة'));
      await settleAsync(tester);
      expect(find.byType(TextField), findsOneWidget);

      await tester.enterText(find.byType(TextField), _story);
      await tester.pump();
      await tester.tap(find.text('أرسل لمحاميحو'));
      await tester.pump();
      expect(_says(tester), 'فهمت طلبك');

      await tester.tap(find.text('صوت'));
      await settleAsync(tester);
      expect(_says(tester), contains('احكيلي محتاج إيه'));
    });

    testWidgets('اللي اتكتب لمحاميحو في الشات بيفتح وضع الكتابة جاهز', (tester) async {
      fakeServer();
      await tester.pumpWidget(testApp(MahamihoRequestScreen(kind: ConsultationKind.call, serviceTitle: ConsultationKind.call.serviceName, initialDetails: _story, voice: _FakeVoice())));
      await settleAsync(tester);

      expect(find.text(_story), findsOneWidget);
      expect(find.text('أرسل لمحاميحو'), findsOneWidget);
    });

    testWidgets('اطلاع على مستندات: بعد الكلام تيجي صور الورق', (tester) async {
      fakeServer();
      await tester.pumpWidget(testApp(MahamihoRequestScreen(kind: ConsultationKind.papers, serviceTitle: ConsultationKind.papers.serviceName, voice: _FakeVoice(heard: _story))));
      await settleAsync(tester);

      await tester.tap(find.byIcon(Icons.mic_rounded).last);
      await settleAsync(tester);
      await tester.tap(find.byIcon(Icons.stop_rounded));
      await settleAsync(tester);
      await tester.tap(find.text('متابعة'));
      await settleAsync(tester);

      expect(find.byType(ConsultationPagesScreen), findsOneWidget);
    });
  });
}
