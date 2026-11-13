import 'dart:async';

import 'package:flutter/material.dart';

import 'mahamiho_bubble.dart';
import 'mahamiho_chat_screen.dart';
import 'mahamiho_figure.dart';

/// محاميحو في كل صفحات الشريط السفلي: نص جسمه من الراس للحزام، لازق في الشريط.
/// أول ما يظهر بيطلع من ورا الشريط بسحب ناعم (من غير قفز) ويشاور، وجنبه فقاعة بتكتب الكلام.
/// لما يخلّص كلامه بينزل ويفضل ظاهر نص دماغه بس. لو دوست عليه وهو نازل بيطلع ويتكلم تاني،
/// ولو دوست عليه وهو طالع بيفتح صفحة محاميحو (MahamihoChatScreen)
class MahamihoGuide extends StatefulWidget {
  const MahamihoGuide({super.key});

  /// الظهور الأول مرة واحدة في كل فتحة للتطبيق
  static bool _greeted = false;

  @visibleForTesting
  static void resetForTest() => _greeted = false;

  /// الكلام اللي في الفقاعة، كل جملة بتتكتب لوحدها
  static const hello = ['أهلاً بيك، أنا محاميحو', 'أنا هنا عشان أساعدك', 'دوس عليّا لو محتاجني'];

  @override
  State<MahamihoGuide> createState() => _MahamihoGuideState();
}

class _MahamihoGuideState extends State<MahamihoGuide> with SingleTickerProviderStateMixin {
  /// الجزء الظاهر من طوله: 0 مستخبي ورا الشريط، و1 طالع كله، و_peek نص دماغه بس
  static const _peek = 0.27;

  late final AnimationController _pos;
  Timer? _timer;
  MahamihoMood _mood = MahamihoMood.idle;

  /// بيتكلم دلوقتي (الفقاعة ظاهرة)، و[_spoke] بيتغير مع كل كلام جديد عشان الفقاعة تبدأ من الأول
  bool _speaking = false;
  int _spoke = 0;

  @override
  void initState() {
    super.initState();
    _pos = AnimationController(vsync: this, duration: const Duration(milliseconds: 800), value: MahamihoGuide._greeted ? _peek : 0);
    if (MahamihoGuide._greeted) return;
    MahamihoGuide._greeted = true;
    _schedule(const Duration(milliseconds: 700), _rise);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // تجهيز الحركات قبل ما تظهر عشان ما يحصلش وميض وهي بتتبدل
    MahamihoFigure.precache(context);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pos.dispose();
    super.dispose();
  }

  void _schedule(Duration after, VoidCallback f) {
    _timer?.cancel();
    _timer = Timer(after, () {
      if (mounted) f();
    });
  }

  /// بيطلع بسحب ناعم، وبعدها يشاور ويتكلم
  void _rise() {
    _pos.animateTo(1, duration: const Duration(milliseconds: 800), curve: Curves.easeOutCubic);
    setState(() {
      _speaking = true;
      _spoke++;
    });
    _schedule(const Duration(milliseconds: 500), () => _start(MahamihoMood.wave));
  }

  /// خلّص كلامه: الفقاعة تختفي وينزل ويفضل نص دماغه بس
  void _lower() {
    _timer?.cancel();
    setState(() {
      _speaking = false;
      _mood = MahamihoMood.idle;
    });
    _pos.animateTo(_peek, duration: const Duration(milliseconds: 700), curve: Curves.easeInOutCubic);
  }

  /// الحركة من أولها، وبعدها يرجع واقف. الصورة القديمة بتفضل ظاهرة لحد ما الجديدة تجهز
  /// (gaplessPlayback في MahamihoFigure)، فمفيش وميض وهي بتتبدل
  void _start(MahamihoMood mood) {
    AssetImage(mood.asset).evict();
    setState(() => _mood = mood);
    _schedule(MahamihoMood.clip, () => setState(() => _mood = MahamihoMood.idle));
  }

  void _onTap() {
    // نازل أو لسه طالع من تحت: يطلع ويتكلم. طالع خلاص: يفتح صفحة محاميحو
    if (_pos.value < 0.9 && !_speaking) {
      _rise();
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MahamihoChatScreen()));
  }

  @override
  Widget build(BuildContext context) {
    // الحجم على قد عرض الشاشة: صغير على الموبايلات الصغيرة، وما يكبرش زيادة على التابلت
    final screen = MediaQuery.sizeOf(context).width;
    final width = (screen * 0.24).clamp(86.0, 120.0);
    final height = width * MahamihoFigure.ratio * MahamihoFigure.halfShown;

    return Stack(
      children: [
        Positioned(
          left: 2,
          bottom: 0,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _onTap,
            child: Row(
              textDirection: TextDirection.ltr,
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  label: 'محاميحو',
                  button: true,
                  // ظاهر منه الجزء اللي فوق الشريط بس، وبينزل ويطلع بسحب
                  child: ClipRect(
                    child: SizedBox(
                      width: width,
                      height: height,
                      child: AnimatedBuilder(
                        animation: _pos,
                        child: MahamihoFigure(mood: _mood, width: width, halfBody: true),
                        builder: (context, child) => Transform.translate(offset: Offset(0, height * (1 - _pos.value)), child: child),
                      ),
                    ),
                  ),
                ),
                // الفقاعة جنب راسه بمسافة صغيرة (من غير دبوس)، وبتظهر بعد ما يطلع وتختفي لما يخلّص
                if (_speaking)
                  Transform.translate(
                    offset: Offset(-width * 0.185 + 10, 0),
                    child: Padding(
                      padding: EdgeInsets.only(bottom: height * 0.52),
                      child: MahamihoBubble(
                        key: ValueKey(_spoke),
                        lines: MahamihoGuide.hello,
                        loop: false,
                        onDone: _lower,
                        maxWidth: (screen - width - 24).clamp(120.0, 170.0),
                        delay: const Duration(milliseconds: 700),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
