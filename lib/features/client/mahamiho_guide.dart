import 'dart:async';

import 'package:flutter/material.dart';

import 'mahamiho_bubble.dart';
import 'mahamiho_chat_screen.dart';
import 'mahamiho_figure.dart';

/// محاميحو في كل صفحات الشريط السفلي: نص جسمه من الراس للحزام تحت على الشمال، ونص الجزء الظاهر بيختفي في أبيض.
/// أول ما يظهر بيطلع من ورا الشريط ويشاور (مرة واحدة)، وجنبه فقاعة بتتنفخ من طرفها وبتكتب الكلام على مرات.
/// بعد كده بيفضل ثابت، وكل شوية بيعمل حركة (تمام، بيفكّر، بيشاور) والفقاعة هي اللي بتتحدث.
/// لمسه بيفتح صفحة محاميحو (MahamihoChatScreen)
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

class _MahamihoGuideState extends State<MahamihoGuide> {
  // بالترتيب ده، وبيلف
  static const _cycle = [MahamihoMood.ok, MahamihoMood.thinking, MahamihoMood.wave];
  static const _gap = Duration(seconds: 6);

  Timer? _timer;
  bool _visible = false;
  MahamihoMood _mood = MahamihoMood.idle;
  int _next = 0;

  @override
  void initState() {
    super.initState();
    if (MahamihoGuide._greeted) {
      _visible = true;
      _schedule(_gap, _playNext);
      return;
    }
    MahamihoGuide._greeted = true;
    _schedule(const Duration(milliseconds: 700), () {
      setState(() => _visible = true);
      _start(MahamihoMood.wave);
    });
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
    super.dispose();
  }

  void _schedule(Duration after, VoidCallback f) {
    _timer?.cancel();
    _timer = Timer(after, () {
      if (mounted) f();
    });
  }

  /// لو صفحة فوق الشريط مفتوحة بيستنى من غير ما يتحرك
  void _playNext() {
    if (!TickerMode.of(context)) {
      _schedule(_gap, _playNext);
      return;
    }
    _start(_cycle[_next]);
    _next = (_next + 1) % _cycle.length;
  }

  /// الحركة من أولها، وبعدها يرجع واقف ويستنى
  void _start(MahamihoMood mood) {
    AssetImage(mood.asset).evict();
    setState(() => _mood = mood);
    _schedule(MahamihoMood.clip, () {
      setState(() => _mood = MahamihoMood.idle);
      _schedule(_gap, _playNext);
    });
  }

  void _onTap() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MahamihoChatScreen()));
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

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
            onTap: _onTap,
            child: Row(
              textDirection: TextDirection.ltr,
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  label: 'محاميحو',
                  button: true,
                  child: MahamihoRise(child: MahamihoFigure(mood: _mood, width: width, halfBody: true)),
                ),
                // الفقاعة لازقة فيه وطرفها عند راسه، وبتتنفخ بعد ما يطلع
                Transform.translate(
                  offset: Offset(-width * 0.16, 0),
                  child: Padding(
                    padding: EdgeInsets.only(bottom: height * 0.52),
                    child: MahamihoBubble(
                      lines: MahamihoGuide.hello,
                      maxWidth: (screen - width - 24).clamp(120.0, 170.0),
                      delay: const Duration(milliseconds: 300),
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
