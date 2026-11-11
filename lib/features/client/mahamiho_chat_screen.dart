import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_header.dart';
import 'legal_services.dart';

/// صفحة محاميحو: شات موجّه. الموكل يختار خدمة أو يكتب مشكلته، محاميحو يسأله يوصف اللي حصل،
/// ولما يوافق بيفتح أول خطوة في الخدمة والوصف مكتوب جاهز (الدفع والباقي في شاشات الخدمة نفسها).
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
  static const _botDelay = Duration(milliseconds: 650);

  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<_Message> _messages = [];
  final List<Timer> _timers = [];
  LegalService? _service;
  String _description = '';
  bool _typing = false;

  @override
  void initState() {
    super.initState();
    _messages.add(const _Message('أهلاً! أنا محاميحو 👋\nاختار الخدمة اللي محتاجها، أو احكيلي مشكلتك وأنا أوجّهك.', showServices: true));
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

  void _add(_Message m) {
    setState(() => _messages.add(m));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  /// رد محاميحو بييجي بعد لحظة و«بيكتب...» ظاهرة
  void _reply(_Message m) {
    setState(() => _typing = true);
    _timers.add(Timer(_botDelay, () {
      if (!mounted) return;
      _typing = false;
      _add(m);
    }),);
  }

  void _chooseService(LegalService service) {
    _service = service;
    _description = '';
    _add(_Message(service.title, fromBot: false));
    _reply(_Message(service.isUrgent
        ? 'تمام. احكيلي في سطرين حصل إيه وفين، وأنا أجهّزلك الطلب لأقرب محامي.'
        : 'تمام. احكيلي مشكلتك باختصار، وأنا أجهّزلك الطلب.',),);
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty || _typing) return;
    _input.clear();
    _add(_Message(text, fromBot: false));

    if (_service == null) {
      final guess = LegalService.guess(text);
      if (guess == null) {
        _reply(const _Message('عشان أساعدك صح، اختار الخدمة الأقرب لمشكلتك:', showServices: true));
        return;
      }
      _service = guess;
    }
    _description = _description.isEmpty ? text : '$_description\n$text';
    _reply(_Message(
      _service!.isUrgent
          ? 'جهّزتلك طلب «${_service!.title}». هدوّر على أقرب محامي ليك، وتشوف العروض وتختار. أكمّل؟'
          : 'جهّزتلك طلب «${_service!.title}». هتراجع التفاصيل وتدفع، ومحامي يكلمك. أكمّل؟',
      askConfirm: true,
    ),);
  }

  Future<void> _confirm() async {
    final service = _service;
    if (service == null) return;
    _add(const _Message('أيوه، كمّل', fromBot: false));
    await service.open(context, description: _description);
    if (!mounted) return;
    _service = null;
    _description = '';
    _reply(const _Message('محتاج حاجة تانية؟ أنا هنا.', showServices: true));
  }

  void _edit() {
    _add(const _Message('عايز أعدّل', fromBot: false));
    _description = '';
    _reply(const _Message('ماشي، اكتب المشكلة من الأول، أو اختار خدمة تانية.', showServices: true));
  }

  @override
  Widget build(BuildContext context) {
    final last = _messages.length - 1;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AppHeader(title: 'محاميحو', isInnerPage: true, showNotifications: false),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                itemCount: _messages.length + 1 + (_typing ? 1 : 0),
                itemBuilder: (context, i) {
                  // محاميحو واقف فوق أول رسالة
                  if (i == 0) {
                    return const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: SizedBox(height: 120, child: Image(image: AssetImage('assets/mahamiho/idle.webp'), gaplessPlayback: true)),
                    );
                  }
                  i--;
                  if (i == _messages.length) return const _Bubble(text: 'محاميحو بيكتب...', fromBot: true, muted: true);
                  final m = _messages[i];
                  // الأزرار شغالة في آخر رسالة بس
                  final active = i == last && !_typing;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Bubble(text: m.text, fromBot: m.fromBot),
                      if (m.showServices && active) _ServiceChips(onTap: _chooseService),
                      if (m.askConfirm && active)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Wrap(spacing: 8, children: [
                            _Chip(text: 'أيوه، كمّل', filled: true, onTap: _confirm),
                            _Chip(text: 'عدّل', onTap: _edit),
                          ],),
                        ),
                    ],
                  );
                },
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
                      decoration: const InputDecoration(hintText: 'اكتب لمحاميحو...', isDense: true),
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

class _Bubble extends StatelessWidget {
  final String text;
  final bool fromBot;
  final bool muted;
  const _Bubble({required this.text, required this.fromBot, this.muted = false});

  @override
  Widget build(BuildContext context) {
    const r = Radius.circular(AppTheme.borderRadiusValue);
    const tail = Radius.circular(4);
    return Align(
      // في العربي بداية السطر يمين: محاميحو يمين، والموكل شمال
      alignment: fromBot ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: fromBot ? AppColors.background : AppColors.primary,
          border: fromBot ? Border.all(color: AppColors.cardBorder) : null,
          borderRadius: BorderRadiusDirectional.only(
            topStart: r,
            topEnd: r,
            bottomStart: fromBot ? tail : r,
            bottomEnd: fromBot ? r : tail,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: 'AppFont',
            fontFamilyFallback: appFontFallback,
            fontSize: 13,
            height: 1.55,
            color: fromBot ? (muted ? AppColors.textMuted : AppColors.dark) : Colors.white,
          ),
        ),
      ),
    );
  }
}

class _ServiceChips extends StatelessWidget {
  final ValueChanged<LegalService> onTap;
  const _ServiceChips({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final s in LegalService.all) _Chip(text: s.title, icon: s.icon, onTap: () => onTap(s)),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final IconData? icon;
  final bool filled;
  final VoidCallback onTap;
  const _Chip({required this.text, required this.onTap, this.icon, this.filled = false});

  @override
  Widget build(BuildContext context) {
    final color = filled ? Colors.white : AppColors.primary;
    return Material(
      color: filled ? AppColors.primary : AppColors.primaryLight,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 16, color: color), const SizedBox(width: 6)],
              Text(text, style: TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 12, fontWeight: FontWeight.w700, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
