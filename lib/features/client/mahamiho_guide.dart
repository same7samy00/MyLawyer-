import 'dart:async';

import 'package:flutter/material.dart';

import 'mahamiho_chat_screen.dart';

/// محاميحو: صغير تحت على الشمال، ثابت طول ما الرئيسية مفتوحة.
/// كل 5 ثواني بيعمل حركة مختلفة (يطلع ويشاور، يطلع، لايك، بيفكّر)، ومع كل حركة
/// صورة «أهلاً أنا محاميحو» بتظهر جنبه فوق الشريط السفلي وتختفي.
/// لمسه بيفتح صفحة محاميحو (MahamihoChatScreen).
class MahamihoGuide extends StatefulWidget {
  const MahamihoGuide({super.key});

  /// الظهور الأول بالتلويح مرة واحدة في كل فتحة للتطبيق
  static bool _greeted = false;

  @visibleForTesting
  static void resetForTest() => _greeted = false;

  @override
  State<MahamihoGuide> createState() => _MahamihoGuideState();
}

/// حركة: الملف ومدتها (عدد اللقطات × 42 مللي ثانية)
class _Clip {
  final String name;
  final int frames;
  const _Clip(this.name, this.frames);

  String get asset => 'assets/mahamiho/$name.webp';
  Duration get length => Duration(milliseconds: frames * 42);
}

class _MahamihoGuideState extends State<MahamihoGuide> {
  static const _idle = _Clip('idle', 0);
  static const _popWave = _Clip('pop-wave', 66);
  // بالترتيب ده، وبيلف
  static const _cycle = [_Clip('pop-up', 61), _Clip('like', 55), _Clip('thinking', 96), _popWave];
  static const _gap = Duration(seconds: 5);
  static const _badgeFor = Duration(milliseconds: 3500);
  static const _badge = 'assets/mahamiho/hello.webp';

  Timer? _timer;
  Timer? _badgeTimer;
  bool _visible = false;
  bool _showBadge = false;
  _Clip _clip = _idle;
  int _next = 0;
  int _play = 0;

  @override
  void initState() {
    super.initState();
    if (MahamihoGuide._greeted) {
      _visible = true;
      _schedule(_gap, _playNext);
      return;
    }
    MahamihoGuide._greeted = true;
    _schedule(const Duration(milliseconds: 1200), () {
      setState(() => _visible = true);
      _start(_popWave);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // تجهيز الحركات قبل ما تظهر عشان ما يحصلش وميض وهي بتتبدل
    final config = createLocalImageConfiguration(context);
    for (final asset in [_idle.asset, _popWave.asset, _badge, for (final c in _cycle) c.asset]) {
      AssetImage(asset).resolve(config);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _badgeTimer?.cancel();
    super.dispose();
  }

  void _schedule(Duration after, VoidCallback f) {
    _timer?.cancel();
    _timer = Timer(after, () {
      if (mounted) f();
    });
  }

  /// في تبويب تاني أو صفحة فوق الرئيسية بيستنى من غير ما يتحرك
  void _playNext() {
    if (!TickerMode.of(context)) {
      _schedule(_gap, _playNext);
      return;
    }
    _start(_cycle[_next]);
    _next = (_next + 1) % _cycle.length;
  }

  /// الحركة بتتمسح من الذاكرة عشان تبدأ من أولها، وبعدها يرجع واقف ويستنى 5 ثواني
  void _start(_Clip clip) {
    AssetImage(clip.asset).evict();
    setState(() {
      _clip = clip;
      _play++;
      _showBadge = true;
    });
    _badgeTimer?.cancel();
    _badgeTimer = Timer(_badgeFor, () {
      if (mounted) setState(() => _showBadge = false);
    });
    _schedule(clip.length, () {
      setState(() => _clip = _idle);
      _schedule(_gap, _playNext);
    });
  }

  void _onTap() {
    setState(() => _showBadge = false);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MahamihoChatScreen()));
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    // الحجم على قد عرض الشاشة: صغير على الموبايلات الصغيرة، وما يكبرش زيادة على التابلت
    final screen = MediaQuery.sizeOf(context).width;
    final width = (screen * 0.22).clamp(80.0, 110.0);
    final height = width * 274 / 270;
    final badgeWidth = (width * 1.5).clamp(110.0, 170.0);

    return Stack(
      children: [
        Positioned(
          left: 4,
          bottom: 0,
          width: width,
          height: height,
          child: GestureDetector(
            onTap: _onTap,
            child: Semantics(
              label: 'محاميحو',
              button: true,
              child: Image.asset(
                _clip.asset,
                key: ValueKey(_play),
                fit: BoxFit.contain,
                alignment: Alignment.bottomCenter,
                gaplessPlayback: true,
                filterQuality: FilterQuality.medium,
              ),
            ),
          ),
        ),
        // «أهلاً أنا محاميحو» فوق الشريط على طول وجنبه
        Positioned(
          left: width,
          bottom: 6,
          width: badgeWidth,
          child: IgnorePointer(
            child: AnimatedSlide(
              offset: _showBadge ? Offset.zero : const Offset(0, 0.4),
              duration: const Duration(milliseconds: 320),
              curve: _showBadge ? Curves.easeOutBack : Curves.easeIn,
              child: AnimatedScale(
                scale: _showBadge ? 1 : 0.6,
                alignment: Alignment.bottomLeft,
                duration: const Duration(milliseconds: 320),
                curve: _showBadge ? Curves.easeOutBack : Curves.easeIn,
                child: AnimatedOpacity(
                  opacity: _showBadge ? 1 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: Image.asset(_badge, semanticLabel: 'أهلاً أنا محاميحو موجود هنا لمساعدتك', gaplessPlayback: true),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
