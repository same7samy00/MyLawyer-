import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_lawyer/core/services/voice_input.dart';
import 'package:my_lawyer/data/models/consultation.dart';
import 'package:my_lawyer/features/consultation/consultation_checkout_screen.dart';
import 'package:my_lawyer/features/consultation/consultation_pages_screen.dart';
import 'package:my_lawyer/features/consultation/mahamiho_request_screen.dart';
import '../helpers/session_test_helpers.dart';

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

      expect(find.text('أهلاً بيك! احكيلي محتاج إيه وأنا سامعك'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.mic_rounded).last);
      await settleAsync(tester);
      expect(voice.started, isTrue);
      expect(find.text('بسمعك… خد وقتك'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.stop_rounded));
      await settleAsync(tester);
      expect(find.text('فهمت طلبك'), findsOneWidget);
      expect(find.text(_story), findsNothing);

      await tester.tap(find.text('متابعة للدفع'));
      await tester.pump(const Duration(seconds: 2));
      await settleAsync(tester);
      expect(find.byType(ConsultationCheckoutScreen), findsOneWidget);
      expect(find.text('كلامك اتسجّل وهيوصل لفريق المحامين'), findsOneWidget);
      expect(find.text(_story), findsNothing);
    });

    testWidgets('كلام قصير: محاميحو يطلب يكمّل، ومفيش متابعة', (tester) async {
      fakeServer();
      await tester.pumpWidget(testApp(MahamihoRequestScreen(kind: ConsultationKind.call, serviceTitle: ConsultationKind.call.serviceName, voice: _FakeVoice(heard: 'مشكلة'))));
      await settleAsync(tester);

      await tester.tap(find.byIcon(Icons.mic_rounded).last);
      await settleAsync(tester);
      await tester.tap(find.byIcon(Icons.stop_rounded));
      await settleAsync(tester);

      expect(find.text('كمّل كلام شوية عشان أفهمك أحسن'), findsOneWidget);
      expect(find.text('متابعة للدفع'), findsNothing);
    });

    testWidgets('الميكروفون مش شغال: رسالة، وبيتحول للكتابة لوحده', (tester) async {
      fakeServer();
      await tester.pumpWidget(testApp(MahamihoRequestScreen(kind: ConsultationKind.call, serviceTitle: ConsultationKind.call.serviceName, voice: _FakeVoice(ready: VoiceReady.unavailable))));
      await settleAsync(tester);

      await tester.tap(find.byIcon(Icons.mic_rounded).last);
      await settleAsync(tester);

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('اكتبلي محتاج إيه وأنا هفهمك'), findsOneWidget);
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
      expect(find.text('فهمت طلبك'), findsOneWidget);

      await tester.tap(find.text('صوت'));
      await settleAsync(tester);
      expect(find.text('أهلاً بيك! احكيلي محتاج إيه وأنا سامعك'), findsOneWidget);
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
