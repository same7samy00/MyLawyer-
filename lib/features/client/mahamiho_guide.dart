import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// محاميحو: صغير تحت على الشمال، ثابت طول ما الرئيسية مفتوحة.
/// أول ما التطبيق يتفتح بيطلع من ورا الشريط السفلي ويشاور، وجنبه جملة بتختفي بعد شوية.
/// لمسه بيعمل لايك ويقول الجملة تاني.
class MahamihoGuide extends StatefulWidget {
  const MahamihoGuide({super.key});

  /// التلويح مرة واحدة في كل فتحة للتطبيق، وبعدها بيفضل واقف
  static bool _greeted = false;

  @visibleForTesting
  static void resetForTest() => _greeted = false;

  @override
  State<MahamihoGuide> createState() => _MahamihoGuideState();
}

enum _Clip { popWave, idle, like }

class _MahamihoGuideState extends State<MahamihoGuide> {
  // مدة كل حركة = عدد اللقطات × 42 مللي ثانية
  static const _clips = {
    _Clip.popWave: ('assets/mahamiho/pop-wave.webp', Duration(milliseconds: 66 * 42)),
    _Clip.idle: ('assets/mahamiho/idle.webp', Duration.zero),
    _Clip.like: ('assets/mahamiho/like.webp', Duration(milliseconds: 55 * 42)),
  };
  static const _hello = 'أهلاً! أنا محاميحو 👋\nاختار الخدمة اللي محتاجها، وأنا معاك لحد ما المحامي يوصلك.';

  final List<Timer> _timers = [];
  bool _visible = false;
  bool _bubble = false;
  _Clip _clip = _Clip.idle;
  int _play = 0;

  @override
  void initState() {
    super.initState();
    if (MahamihoGuide._greeted) {
      _visible = true;
      return;
    }
    MahamihoGuide._greeted = true;
    _later(const Duration(milliseconds: 1200), _greet);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // تجهيز الحركات قبل ما تظهر عشان ما يحصلش وميض وهي بتتبدل
    final config = createLocalImageConfiguration(context);
    for (final clip in _clips.values) {
      AssetImage(clip.$1).resolve(config);
    }
  }

  @override
  void dispose() {
    _cancelTimers();
    super.dispose();
  }

  void _later(Duration d, VoidCallback f) => _timers.add(Timer(d, () { if (mounted) f(); }));

  void _cancelTimers() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
  }

  /// الحركة اللي بتتشغل مرة بتتمسح من الذاكرة عشان تبدأ من أولها كل مرة، وبعدها يرجع واقف
  void _playClip(_Clip clip) {
    final (asset, length) = _clips[clip]!;
    AssetImage(asset).evict();
    setState(() {
      _clip = clip;
      _play++;
    });
    _later(length, () => setState(() => _clip = _Clip.idle));
  }

  void _sayHello(Duration after) {
    if (after == Duration.zero) {
      setState(() => _bubble = true);
    } else {
      _later(after, () => setState(() => _bubble = true));
    }
    _later(after + const Duration(seconds: 7), () => setState(() => _bubble = false));
  }

  void _greet() {
    setState(() => _visible = true);
    _playClip(_Clip.popWave);
    _sayHello(const Duration(milliseconds: 700));
  }

  void _onTap() {
    _cancelTimers();
    _playClip(_Clip.like);
    _sayHello(Duration.zero);
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    // الحجم على قد عرض الشاشة: صغير على الموبايلات الصغيرة، وما يكبرش زيادة على التابلت
    final screen = MediaQuery.sizeOf(context).width;
    final width = (screen * 0.22).clamp(80.0, 110.0);
    final height = width * 274 / 270;
    final bubbleWidth = (screen - width - 24).clamp(140.0, 250.0);
    final (asset, _) = _clips[_clip]!;

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
                asset,
                key: ValueKey(_play),
                fit: BoxFit.contain,
                alignment: Alignment.bottomCenter,
                gaplessPlayback: true,
                filterQuality: FilterQuality.medium,
              ),
            ),
          ),
        ),
        Positioned(
          left: width,
          bottom: height * 0.45,
          width: bubbleWidth,
          child: IgnorePointer(
            ignoring: !_bubble,
            child: AnimatedOpacity(
              opacity: _bubble ? 1 : 0,
              duration: const Duration(milliseconds: 220),
              child: AnimatedScale(
                scale: _bubble ? 1 : 0.85,
                alignment: Alignment.bottomLeft,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                child: GestureDetector(
                  onTap: () => setState(() => _bubble = false),
                  child: const _Bubble(text: _hello),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  final String text;
  const _Bubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppTheme.borderRadiusValue),
          topRight: Radius.circular(AppTheme.borderRadiusValue),
          bottomRight: Radius.circular(AppTheme.borderRadiusValue),
          bottomLeft: Radius.circular(4),
        ),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Text(
        text,
        style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 12.5, height: 1.5, color: AppColors.dark),
      ),
    );
  }
}
