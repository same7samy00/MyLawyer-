import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_header.dart';
import '../../data/models/consultation.dart';
import '../../data/repositories/consultation_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../consultation/consultation_evaluating_screen.dart';
import '../consultation/consultation_pages_screen.dart';
import 'legal_services.dart';
import 'mahamiho_bubble.dart';
import 'mahamiho_figure.dart';
import 'mahamiho_talk.dart';

/// صفحة محاميحو: شات موجّه بيحس إنه ذكي ومش ذكاء اصطناعي (الكلام في [MahamihoTalk]).
/// الموكل يختار خدمة أو يكتب مشكلته، ومحاميحو يسأله على قد الخدمة ويلخّص اللي فهمه ويأكد معاه:
/// الخدمات المكتبية بتروح على الدفع على طول (والاطلاع على مستندات بيطلب صور الورق الأول)،
/// والخدمات الميدانية بتفتح طلبها («ليك ولا لشخص تاني» والمكان) والموكل يكمّل
class MahamihoChatScreen extends StatefulWidget {
  const MahamihoChatScreen({super.key});

  @override
  State<MahamihoChatScreen> createState() => _MahamihoChatScreenState();
}

class _Message {
  final bool fromBot;
  final String text;
  final bool showServices;
  final bool askConfirm;
  const _Message(this.text, {this.fromBot = true, this.showServices = false, this.askConfirm = false});
}

class _MahamihoChatScreenState extends State<MahamihoChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<_Message> _messages = [];
  final List<Timer> _timers = [];
  late final MahamihoTalk _talk = MahamihoTalk(firstName: MahamihoTalk.firstNameFrom(ProfileRepository.saved), now: DateTime.now());
  ConsultationSettings _settings = const ConsultationSettings();
  LegalService? _service;
  String _description = '';
  bool _typing = false;
  bool _busy = false;

  /// بيشاور أول ما الصفحة تفتح، وبعد الحركة بيقف
  bool _greeting = true;

  @override
  void initState() {
    super.initState();
    _input.addListener(() => setState(() {}));
    _timers.add(Timer(MahamihoMood.clip, () {
      if (mounted) setState(() => _greeting = false);
    }),);
    _messages.add(_Message(_talk.hello(), showServices: true));
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await ConsultationRepository.settings();
    if (mounted) setState(() => _settings = settings);
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// بيفكّر وإنت بتكتب أو وهو بيجهّز رده، و«تمام» لما يجهّز الطلب، وبيشاور أول ما الصفحة تفتح
  MahamihoMood get _mood {
    if (_typing || _input.text.trim().isNotEmpty) return MahamihoMood.thinking;
    if (_messages.isNotEmpty && _messages.last.askConfirm) return MahamihoMood.ok;
    return _greeting ? MahamihoMood.wave : MahamihoMood.idle;
  }

  void _add(_Message m) {
    setState(() => _messages.add(m));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  /// رد محاميحو بييجي بعد وقت على قد طوله و«بيكتب...» ظاهرة، عشان يحس إنه بيفكّر
  void _reply(_Message m) {
    setState(() => _typing = true);
    _timers.add(Timer(MahamihoTalk.thinkingFor(m.text), () {
      if (!mounted) return;
      _typing = false;
      _add(m);
    }),);
  }

  void _chooseService(LegalService service) {
    _service = service;
    _description = '';
    _add(_Message(service.title, fromBot: false));
    _reply(_Message(_talk.askDetails(service)));
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty || _typing || _busy) return;
    _input.clear();
    _add(_Message(text, fromBot: false));

    var guessed = false;
    if (_service == null) {
      final chat = _talk.smallTalk(text);
      if (chat != null) {
        _reply(_Message(chat, showServices: true));
        return;
      }
      final guess = LegalService.guess(text);
      if (guess == null) {
        _reply(_Message(_talk.unclear(), showServices: true));
        return;
      }
      _service = guess;
      guessed = true;
    }
    final service = _service!;
    _description = _description.isEmpty ? text : '$_description\n$text';
    // الخدمات المكتبية محتاجة وصف كفاية عشان المحامي يرد
    final missing = service.isUrgent ? 0 : _settings.minDetailsChars - _description.length;
    if (missing > 0) {
      final ask = _talk.needMore(missing);
      _reply(_Message(guessed ? '${_talk.guessed(service)} $ask' : ask));
      return;
    }
    final summary = _talk.confirm(service, _description, settings: _settings);
    _reply(_Message(guessed ? '${_talk.guessed(service)} $summary' : summary, askConfirm: true));
  }

  Future<void> _confirm() async {
    final service = _service;
    if (service == null || _busy) return;
    _add(_Message(_talk.yesLabel(service), fromBot: false));
    if (!service.isUrgent && !_settings.isOpen) {
      _service = null;
      _description = '';
      _reply(_Message(_talk.closed(), showServices: true));
      return;
    }
    _busy = true;
    final navigator = Navigator.of(context);
    if (service.isUrgent) {
      // الخدمة الميدانية: صفحتها بتسأل «ليك ولا لشخص تاني» والمكان، والموكل يكمّل
      await service.open(context, description: _description);
    } else {
      // الخدمات المكتبية على الدفع على طول، والاطلاع على مستندات بيطلب صور الورق الأول
      final details = '${service.title}: $_description';
      await navigator.push(MaterialPageRoute(
        builder: (_) => service.consultation == ConsultationKind.papers
            ? ConsultationPagesScreen(details: details, serviceTitle: service.title)
            : ConsultationEvaluatingScreen(
                kind: service.consultation,
                serviceTitle: service.title,
                details: details,
                pagePaths: const [],
                settings: _settings,
              ),
      ),);
    }
    if (!mounted) return;
    _busy = false;
    _service = null;
    _description = '';
    _reply(_Message(_talk.anythingElse(), showServices: true));
  }

  void _edit() {
    _add(const _Message('عايز أعدّل', fromBot: false));
    _description = '';
    _reply(_Message(_talk.editing(), showServices: true));
  }

  @override
  Widget build(BuildContext context) {
    // محاميحو على الشمال وآخر رده على اليمين، وتحت خط فاصل: آخر كلام الموكل، والاختيارات أو التأكيد
    final reply = _messages.lastWhere((m) => m.fromBot);
    final lastMessage = _messages.last;
    final active = !_typing && lastMessage.fromBot;
    final mine = _messages.lastWhere((m) => !m.fromBot, orElse: () => const _Message(''));
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AppHeader(title: 'محاميحو', isInnerPage: true, showNotifications: false),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                children: [
                  Row(
                    textDirection: TextDirection.ltr,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      MahamihoFigure(mood: _mood, width: 88),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _typing
                            ? const Align(alignment: AlignmentDirectional.centerStart, child: _ThinkingBubble())
                            : _ReplyBubbles(key: ValueKey(reply), sentences: MahamihoTalk.sentences(reply.text)),
                      ),
                    ],
                  ),
                  const Padding(padding: EdgeInsets.only(top: 16, bottom: 12), child: Divider(height: 1, color: AppColors.cardBorder)),
                  if (mine.text.isNotEmpty) ...[
                    Text('إنت', style: _small(AppColors.textMuted)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        border: Border.all(color: AppColors.cardBorder),
                        borderRadius: BorderRadius.circular(AppTheme.borderRadiusValue),
                      ),
                      child: Text(mine.text, style: _text(13, FontWeight.w500, AppColors.dark)),
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (active && lastMessage.showServices) ...[
                    Text('اختار خدمة', style: _small(AppColors.textMuted)),
                    const SizedBox(height: 8),
                    _ServiceGrid(onTap: _chooseService),
                  ],
                  if (active && lastMessage.askConfirm && _service != null)
                    Row(
                      children: [
                        Expanded(child: AppButton.primary(text: _talk.yesLabel(_service!), height: 46, onPressed: _confirm)),
                        const SizedBox(width: 8),
                        SizedBox(width: 96, child: AppButton.outlined(text: 'عدّل', height: 46, onPressed: _edit)),
                      ],
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.cardBorder))),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 13),
                      // أول مرة بيقوله إنه يقدر يكتب بدل ما يختار
                      decoration: InputDecoration(hintText: mine.text.isEmpty ? 'أو اكتب مشكلتك هنا...' : 'اكتب لمحاميحو...', isDense: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Semantics(
                    label: 'إرسال',
                    button: true,
                    child: InkWell(
                      onTap: _send,
                      customBorder: const CircleBorder(),
                      child: const CircleAvatar(
                        radius: 21,
                        backgroundColor: AppColors.primary,
                        child: Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

TextStyle _text(double size, FontWeight weight, Color color) =>
    TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: size, height: 1.55, fontWeight: weight, color: color);

TextStyle _small(Color color) => _text(11.5, FontWeight.w600, color);

/// رد محاميحو: كل جملة في فقاعة، والفقاعات بتظهر واحدة ورا التانية بتلاشي
class _ReplyBubbles extends StatefulWidget {
  final List<String> sentences;
  const _ReplyBubbles({super.key, required this.sentences});

  static const each = Duration(milliseconds: 450);

  @override
  State<_ReplyBubbles> createState() => _ReplyBubblesState();
}

class _ReplyBubblesState extends State<_ReplyBubbles> with SingleTickerProviderStateMixin {
  late final AnimationController _show = AnimationController(vsync: this, duration: _ReplyBubbles.each * widget.sentences.length)..forward();

  @override
  void dispose() {
    _show.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.sentences.length;
    return LayoutBuilder(
      builder: (context, box) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < n; i++)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
              child: FadeTransition(
                opacity: CurvedAnimation(parent: _show, curve: Interval(i / n, (i + 1) / n, curve: Curves.easeOut)),
                child: MahamihoSpeech(text: widget.sentences[i], maxWidth: box.maxWidth),
              ),
            ),
        ],
      ),
    );
  }
}

/// محاميحو بيفكّر: فقاعة فيها 3 نقط بتنور ورا بعض
class _ThinkingBubble extends StatefulWidget {
  const _ThinkingBubble();

  @override
  State<_ThinkingBubble> createState() => _ThinkingBubbleState();
}

class _ThinkingBubbleState extends State<_ThinkingBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _dots = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();

  @override
  void dispose() {
    _dots.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'محاميحو بيفكّر',
      child: SpeechShape(
        minWidth: 0,
        child: AnimatedBuilder(
          animation: _dots,
          builder: (_, __) => Row(
            mainAxisSize: MainAxisSize.min,
            textDirection: TextDirection.ltr,
            children: [
              for (var i = 0; i < 3; i++)
                Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity((_dots.value * 3 - i).floor() % 3 == 0 ? 1 : 0.45),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// الخدمات التمانية في شبكة عمودين
class _ServiceGrid extends StatelessWidget {
  final ValueChanged<LegalService> onTap;
  const _ServiceGrid({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final width = (box.maxWidth - 8) / 2;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in LegalService.all)
              SizedBox(
                width: width,
                child: Material(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusValue),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppTheme.borderRadiusValue),
                    onTap: () => onTap(s),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                      child: Row(
                        children: [
                          Icon(s.icon, size: 16, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Expanded(child: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _text(12, FontWeight.w700, AppColors.primary))),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
