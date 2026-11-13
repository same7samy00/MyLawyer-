import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/mahamiho_voice.dart';
import '../../core/services/voice_input.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_header.dart';
import '../../core/widgets/app_message.dart';
import '../../data/models/consultation.dart';
import '../../data/repositories/consultation_repository.dart';
import '../client/mahamiho_bubble.dart';
import '../client/mahamiho_circle.dart';
import '../client/mahamiho_figure.dart';
import 'consultation_evaluating_screen.dart';
import 'consultation_pages_screen.dart';
import 'consultation_style.dart';

enum _Stage { ready, listening, understood }

/// صفحة محاميحو للخدمات المكتبية (استشارة، اطلاع على مستندات، كتابة عقد): العميل يحكي مشكلته بصوته أو يكتبها،
/// ويبدّل بينهم في أي وقت. الكلام بيتحول لنص في الخلفية **والعميل ما بيشوفوش**، والنص بيروح للإدارة مع الطلب بعد الدفع.
/// محاميحو بيرد بجمل مسجلة («فهمت طلبك»)، مش ذكاء اصطناعي (`docs/VOICE_SERVICES.md`)
class MahamihoRequestScreen extends StatefulWidget {
  final ConsultationKind kind;

  /// الخدمة اللي اتختارت من الرئيسية، وبتمشي مع الطلب لحد الدفع
  final String serviceTitle;

  /// اللي العميل كتبه لمحاميحو في الشات بيتكتب هنا جاهز
  final String initialDetails;

  /// بديل الميكروفون في الاختبارات
  final VoiceInput? voice;

  const MahamihoRequestScreen({super.key, required this.kind, required this.serviceTitle, this.initialDetails = '', this.voice});

  @override
  State<MahamihoRequestScreen> createState() => _MahamihoRequestScreenState();
}

class _MahamihoRequestScreenState extends State<MahamihoRequestScreen> with SingleTickerProviderStateMixin {
  static const int _maxSeconds = 240;

  late final VoiceInput _voice;
  late final TextEditingController _typed;
  late final AnimationController _wave;
  ConsultationSettings _settings = const ConsultationSettings();
  Timer? _clock;

  /// محاميحو بيشاور أول ما الصفحة تفتح، وبعد الحركة بيقف
  bool _greeting = true;
  Timer? _greetTimer;

  late bool _byVoice = widget.initialDetails.trim().isEmpty;
  _Stage _stage = _Stage.ready;
  int _seconds = 0;
  String _spoken = '';
  List<String> _caption = const [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _voice = widget.voice ?? SpeechVoiceInput();
    _typed = TextEditingController(text: widget.initialDetails)..addListener(() => setState(() {}));
    _wave = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
    _loadSettings();
    _say(_byVoice ? 'welcome_voice' : 'welcome_text');
    _greetTimer = Timer(MahamihoMood.clip, () {
      if (mounted) setState(() => _greeting = false);
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _greetTimer?.cancel();
    _wave.dispose();
    _typed.dispose();
    _voice.cancel();
    MahamihoVoice.stop();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final settings = await ConsultationRepository.settings();
    if (mounted) setState(() => _settings = settings);
  }

  /// كلام محاميحو في الفقاعة على مرات، كل جزء بيتكتب لوحده
  static const Map<String, List<String>> _lines = {
    'welcome_voice': ['أهلاً بيك، أنا محاميحو', 'احكيلي محتاج إيه', 'وأنا سامعك'],
    'welcome_text': ['أهلاً بيك، أنا محاميحو', 'اكتبلي محتاج إيه', 'وأنا هفهمك'],
    'listening': ['بسمعك…', 'خد وقتك'],
    'understood': ['فهمت طلبك'],
    'short': ['كمّل كلام شوية', 'عشان أفهمك أحسن'],
  };

  /// كلام في الفقاعة، وبيتسمع لو ملفه الصوتي موجود
  void _say(String line) {
    setState(() => _caption = _lines[line] ?? const []);
    MahamihoVoice.say(line);
  }

  int get _typedLength => _typed.text.trim().length;

  /// محاميحو بيصغر وقت الكتابة والتسجيل عشان الباقي يتشاف على أي موبايل
  /// محاميحو كامل وصغير: أصغر وإنت بتكتب أو بتتكلم عشان المساحة
  double get _figureWidth => _stage == _Stage.listening ? 70 : (!_byVoice && _stage == _Stage.ready ? 62 : 88);

  /// «تمام» لما يفهم، وبيفكّر وإنت بتتكلم أو بتكتب، وبيشاور أول ما الصفحة تفتح
  MahamihoMood get _mood {
    if (_stage == _Stage.understood) return MahamihoMood.ok;
    if (_stage == _Stage.listening) return MahamihoMood.thinking;
    if (!_byVoice && _typed.text.trim().isNotEmpty && _typed.text != widget.initialDetails) return MahamihoMood.thinking;
    return _greeting ? MahamihoMood.wave : MahamihoMood.idle;
  }

  void _message(String text) => showAppMessage(context, SnackBar(content: Text(text)));

  void _switchTo(bool byVoice) {
    if (byVoice == _byVoice || _busy) return;
    if (_stage == _Stage.listening) _cancelListening();
    setState(() {
      _byVoice = byVoice;
      _stage = _Stage.ready;
    });
    _say(byVoice ? 'welcome_voice' : 'welcome_text');
  }

  // الصوت

  Future<void> _startListening() async {
    if (_busy) return;
    setState(() => _busy = true);
    final ready = await _voice.prepare();
    if (!mounted) return;
    if (ready != VoiceReady.ready) {
      setState(() => _busy = false);
      _message(ready == VoiceReady.noArabic
          ? 'الموبايل ده مش بيحوّل الكلام العربي لنص. اكتب مشكلتك بدل ما تتكلم'
          : 'مش قادر أشغّل الميكروفون. اتأكد من الإذن، أو اكتب مشكلتك بدل ما تتكلم',);
      _switchTo(false);
      return;
    }
    await _voice.start(onFailure: _onVoiceFailure);
    if (!mounted) return;
    _seconds = 0;
    _clock?.cancel();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _seconds++);
      if (_seconds >= _maxSeconds) _finishListening();
    });
    _wave.repeat();
    setState(() {
      _busy = false;
      _stage = _Stage.listening;
    });
    _say('listening');
  }

  /// المحرك وقع في النص (النت مثلًا): اللي اتقال لحد دلوقتي بيتحفظ
  void _onVoiceFailure() {
    if (!mounted || _stage != _Stage.listening) return;
    _message('الاتصال قطع. اتأكد من النت وجرب تاني، أو اكتب مشكلتك');
    _finishListening();
  }

  Future<void> _finishListening() async {
    if (_stage != _Stage.listening || _busy) return;
    _clock?.cancel();
    _wave.stop();
    setState(() => _busy = true);
    final text = await _voice.stop();
    if (!mounted) return;
    _spoken = text;
    final enough = text.length >= _settings.minDetailsChars;
    setState(() {
      _busy = false;
      _stage = enough ? _Stage.understood : _Stage.ready;
    });
    _say(enough ? 'understood' : 'short');
  }

  Future<void> _cancelListening() async {
    _clock?.cancel();
    _wave.stop();
    await _voice.cancel();
    if (!mounted) return;
    setState(() {
      _stage = _Stage.ready;
      _spoken = '';
    });
    _say('welcome_voice');
  }

  // الكتابة

  void _sendTyped() {
    if (_typedLength < _settings.minDetailsChars) {
      _message('محتاجين ${_settings.minDetailsChars - _typedLength} حرف كمان على الأقل');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _stage = _Stage.understood);
    _say('understood');
  }

  // المتابعة

  void _continue() {
    if (!_settings.isOpen) {
      _message('الخدمة متوقفة دلوقتي، جرب بعد شوية');
      return;
    }
    final details = _byVoice ? _spoken : _typed.text.trim();
    final next = widget.kind == ConsultationKind.papers
        ? ConsultationPagesScreen(details: details, serviceTitle: widget.serviceTitle, viaVoice: _byVoice)
        : ConsultationEvaluatingScreen(
            kind: widget.kind,
            serviceTitle: widget.serviceTitle,
            details: details,
            pagePaths: const [],
            settings: _settings,
            viaVoice: _byVoice,
          );
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => next));
  }

  void _again() {
    setState(() {
      _stage = _Stage.ready;
      if (_byVoice) _spoken = '';
    });
    _say(_byVoice ? 'welcome_voice' : 'welcome_text');
  }

  @override
  Widget build(BuildContext context) {
    final understood = _stage == _Stage.understood;
    // في الصوت محاميحو جوه دايرة بتتحرك مع صوتك والفقاعة فوق راسه (من فوق الصفحة)، وباقي الحالات الشكل العادي
    final centered = _byVoice && !understood;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AppHeader(title: 'محاميحو', isInnerPage: true),
      body: SafeArea(
        child: Column(
          children: [
            _toggle(),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_settings.isOpen) ...[
                      Text('الخدمة متوقفة دلوقتي\nجرب بعد شوية', textAlign: TextAlign.center, style: consultationText(13, FontWeight.w700, AppColors.danger, height: 1.5)),
                      const SizedBox(height: 10),
                    ],
                    if (centered)
                      // الفقاعة فوق الدايرة، والدايرة في النص
                      ..._voiceHead()
                    else
                      // محاميحو بيظهر بتلاشي، والفقاعة جنبه بتكتب الكلام على مرات
                      Row(
                        textDirection: TextDirection.ltr,
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          RepaintBoundary(child: MahamihoFade(child: MahamihoFigure(mood: _mood, width: _figureWidth))),
                          Transform.translate(
                            offset: Offset(-_figureWidth * 0.185 + 10, 0),
                            child: Padding(
                              padding: EdgeInsets.only(bottom: _figureWidth * MahamihoFigure.ratio * 0.62),
                              child: MahamihoBubble(lines: _caption, delay: const Duration(milliseconds: 300)),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 4),
                    if (understood) ..._understoodBody() else if (_byVoice) ..._voiceBody() else ..._textBody(),
                  ],
                ),
              ),
              ),
            ),
            Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 14), child: _actions()),
          ],
        ),
      ),
    );
  }

  /// الفقاعة في النص فوق راسه، وتحته محاميحو في دايرة بتكبر وتصغر مع صوتك
  List<Widget> _voiceHead() {
    final listening = _stage == _Stage.listening;
    return [
      MahamihoStage(
        mood: _mood,
        lines: _caption,
        level: listening ? _voice.level : null,
        breath: listening ? _wave : null,
      ),
    ];
  }

  Widget _toggle() {
    Widget option(String text, IconData icon, bool voice) {
      final on = _byVoice == voice;
      return Expanded(
        child: InkWell(
          onTap: () => _switchTo(voice),
          borderRadius: BorderRadius.circular(7.0),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: on ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(7.0),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: on ? Colors.white : AppColors.textMuted),
                const SizedBox(width: 6),
                Text(text, style: consultationText(14, FontWeight.w800, on ? Colors.white : AppColors.textMuted)),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.bottomSheetHeaderBg, borderRadius: BorderRadius.circular(7.0)),
      child: Row(children: [option('صوت', Icons.mic_rounded, true), const SizedBox(width: 4), option('كتابة', Icons.keyboard_rounded, false)]),
    );
  }

  /// كلام محاميحو: مكتوب، ومعاه صوت لو الجملة مسجلة
  List<Widget> _voiceBody() {
    final listening = _stage == _Stage.listening;
    final minutes = (_seconds ~/ 60).toString();
    final seconds = (_seconds % 60).toString().padLeft(2, '0');
    return [
      if (listening) ...[
        const SizedBox(height: 12),
        Text('$minutes:$seconds', textDirection: TextDirection.ltr, style: consultationText(30, FontWeight.w900, AppColors.primary)),
      ],
      const SizedBox(height: 10),
      _micButton(listening),
      const SizedBox(height: 8),
      Text(listening ? 'اضغط لما تخلص' : 'اضغط وابدأ كلام', style: consultationText(13, FontWeight.w600, AppColors.textMuted)),
      if (!listening) ...[
        const SizedBox(height: 22),
        Text('كلامك بيتحول لنص ويوصل لفريق المحامين بعد الدفع', textAlign: TextAlign.center, style: consultationText(12, FontWeight.w600, AppColors.textMuted, height: 1.5)),
      ],
    ];
  }

  Widget _micButton(bool listening) {
    return InkWell(
      onTap: _busy ? null : (listening ? _finishListening : _startListening),
      customBorder: const CircleBorder(),
      child: Container(
        width: 84,
        height: 84,
        decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
        child: Icon(listening ? Icons.stop_rounded : Icons.mic_rounded, color: Colors.white, size: listening ? 38 : 40),
      ),
    );
  }

  List<Widget> _textBody() {
    final missing = _settings.minDetailsChars - _typedLength;
    return [
      const SizedBox(height: 14),
      TextField(
        controller: _typed,
        minLines: 6,
        maxLines: 10,
        maxLength: 4000,
        style: consultationText(14, FontWeight.w600, AppColors.dark, height: 1.6),
        decoration: InputDecoration(
          hintText: 'مثال: اتفقت مع صاحب الشقة على…',
          hintStyle: consultationText(13, FontWeight.w500, AppColors.textMuted),
          helperText: missing > 0 ? 'محتاجين $missing حرف كمان على الأقل' : null,
          helperStyle: consultationText(11.5, FontWeight.w600, AppColors.textMuted),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(7.0)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7.0), borderSide: const BorderSide(color: AppColors.cardBorder)),
        ),
      ),
    ];
  }

  List<Widget> _understoodBody() {
    return [
      const SizedBox(height: 16),
      Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(color: AppColors.successLight, shape: BoxShape.circle),
        child: const Icon(Icons.check_rounded, color: AppColors.success, size: 26),
      ),
      const SizedBox(height: 10),
      Text(
        widget.kind == ConsultationKind.papers
            ? 'طلبك اتسجّل. كمّل بإضافة صور الورق،\nوفريق المحامين هيراجعه بعد ما تدفع'
            : 'طلبك اتسجّل، وفريق المحامين هيراجعه\nبعد ما تدفع ويرد عليك بالاستشارة',
        textAlign: TextAlign.center,
        style: consultationText(13, FontWeight.w600, AppColors.textMuted, height: 1.6),
      ),
    ];
  }

  Widget _actions() {
    switch (_stage) {
      case _Stage.understood:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppButton.primary(text: widget.kind == ConsultationKind.papers ? 'متابعة' : 'متابعة للدفع', height: 48, onPressed: _continue),
            const SizedBox(height: 4),
            TextButton(onPressed: _again, child: Text(_byVoice ? 'سجّل تاني' : 'عدّل', style: consultationText(14, FontWeight.w800, AppColors.primary))),
          ],
        );
      case _Stage.listening:
        return AppButton.outlined(text: 'إلغاء', height: 46, onPressed: _cancelListening);
      case _Stage.ready:
        return _byVoice ? const SizedBox.shrink() : AppButton.primary(text: 'أرسل لمحاميحو', height: 48, onPressed: _typedLength >= _settings.minDetailsChars ? _sendTyped : null);
    }
  }
}

