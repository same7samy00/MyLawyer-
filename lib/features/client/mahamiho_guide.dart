import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import 'mahamiho_chat_screen.dart';

/// محاميحو: صغير تحت على الشمال، ثابت طول ما الرئيسية مفتوحة.
/// كل 5 ثواني بيعمل حركة مختلفة (يطلع ويشاور، يطلع، لايك، بيفكّر).
/// جنبه سحابة زرقا فيها «أهلاً! أنا محاميحو»، قاعدة على الشريط السفلي وظاهرة طول ما هو ظاهر،
/// ولما ينزل ورا الشريط ويطلع تاني بتنزل وتطلع معاه.
/// لمسه بيفتح صفحة محاميحو (MahamihoChatScreen).
class MahamihoGuide extends StatefulWidget {
  const MahamihoGuide({super.key});

  /// الظهور الأول بالتلويح مرة واحدة في كل فتحة للتطبيق
  static bool _greeted = false;

  @visibleForTesting
  static void resetForTest() => _greeted = false;

  static const hello = 'أهلاً! أنا محاميحو 👋\nموجود هنا عشان أساعدك';

  @override
  State<MahamihoGuide> createState() => _MahamihoGuideState();
}

/// حركة: الملف ومدتها (عدد اللقطات × 42 مللي ثانية)
class _Clip {
  final String name;
  final int frames;

  /// اللقطة اللي بيكون طلع فيها من ورا الشريط (صفر = بيبدأ واقف)
  final int upAt;
  const _Clip(this.name, this.frames, {this.upAt = 0});

  String get asset => 'assets/mahamiho/$name.webp';
  Duration get length => Duration(milliseconds: frames * 42);
  Duration get upDelay => Duration(milliseconds: upAt * 42);
}

class _MahamihoGuideState extends State<MahamihoGuide> {
  static const _idle = _Clip('idle', 0);
  static const _popWave = _Clip('pop-wave', 66, upAt: 8);
  // بالترتيب ده، وبيلف
  static const _cycle = [_Clip('pop-up', 61, upAt: 12), _Clip('like', 55), _Clip('thinking', 96, upAt: 12), _popWave];
  static const _gap = Duration(seconds: 5);
  static const _minRise = Duration(milliseconds: 350);

  Timer? _timer;
  bool _visible = false;
  _Clip _clip = _idle;
  int _next = 0;
  int _play = 0;

  /// السحابة ورا الشريط، ومدة طلوعها
  bool _cloudDown = false;
  Duration _cloudMove = Duration.zero;

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
    for (final asset in [_idle.asset, _popWave.asset, for (final c in _cycle) c.asset]) {
      AssetImage(asset).resolve(config);
    }
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

  /// في تبويب تاني أو صفحة فوق الرئيسية بيستنى من غير ما يتحرك
  void _playNext() {
    if (!TickerMode.of(context)) {
      _schedule(_gap, _playNext);
      return;
    }
    _start(_cycle[_next]);
    _next = (_next + 1) % _cycle.length;
  }

  /// الحركة بتتمسح من الذاكرة عشان تبدأ من أولها، وبعدها يرجع واقف ويستنى 5 ثواني.
  /// لو الحركة بتبدأ وهو ورا الشريط، السحابة بتنزل معاه وتطلع في نفس وقته
  void _start(_Clip clip) {
    AssetImage(clip.asset).evict();
    final pops = clip.upAt > 0;
    setState(() {
      _clip = clip;
      _play++;
      if (pops) {
        _cloudDown = true;
        _cloudMove = Duration.zero;
      }
    });
    if (pops) {
      final rise = clip.upDelay < _minRise ? _minRise : clip.upDelay;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _cloudDown = false;
            _cloudMove = rise;
          });
        }
      });
    }
    _schedule(clip.length, () {
      setState(() => _clip = _idle);
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
    final width = (screen * 0.22).clamp(80.0, 110.0);
    final height = width * 274 / 270;
    final cloudWidth = (screen - width - 16).clamp(140.0, 185.0);
    final cloudHeight = cloudWidth * _CloudPainter.ratio;

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
        // السحابة لازقة في جنبه وقاعدة على الشريط، والقص بيخليها تختفي ورا الشريط زيه
        Positioned(
          left: width - 10,
          bottom: 0,
          width: cloudWidth,
          height: cloudHeight,
          child: GestureDetector(
            onTap: _onTap,
            child: ClipRect(
              child: AnimatedSlide(
                offset: _cloudDown ? const Offset(0, 1.05) : Offset.zero,
                duration: _cloudMove,
                curve: Curves.easeOutBack,
                child: const _Cloud(text: MahamihoGuide.hello),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Cloud extends StatelessWidget {
  final String text;
  const _Cloud({required this.text});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CloudPainter(),
      child: Align(
        alignment: const Alignment(0, 0.15),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Text(
            text,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 11.5, height: 1.45, fontWeight: FontWeight.w700, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

/// سحابة زرقا، وحواليها حافة متقطعة بينها وبين السحابة مسافة صغيرة
class _CloudPainter extends CustomPainter {
  /// الطول ÷ العرض
  static const ratio = 96 / 190;

  // السحابة مرسومة في مساحة 190 × 96، والحافة أكبر منها بـ 9٪
  static Path _cloud() => Path()
    ..moveTo(27, 66)
    ..cubicTo(9, 66, 9, 42, 27, 42)
    ..cubicTo(25, 22, 49, 14, 61, 26)
    ..cubicTo(69, 6, 99, 4, 109, 22)
    ..cubicTo(123, 6, 153, 12, 155, 32)
    ..cubicTo(177, 32, 181, 58, 165, 64)
    ..cubicTo(169, 80, 145, 86, 133, 76)
    ..cubicTo(123, 88, 95, 88, 87, 76)
    ..cubicTo(75, 88, 47, 86, 45, 74)
    ..cubicTo(35, 78, 23, 74, 27, 66)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 190, size.height / 96);
    final cloud = _cloud();
    final edge = cloud.transform((Matrix4.identity()
          ..translate(95.0, 48.0)
          ..scale(1.09, 1.09)
          ..translate(-95.0, -48.0))
        .storage,);

    final dash = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    for (final metric in edge.computeMetrics()) {
      for (double d = 0; d < metric.length; d += 9) {
        canvas.drawPath(metric.extractPath(d, d + 5), dash);
      }
    }
    canvas.drawPath(cloud, Paint()..color = AppColors.primary);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CloudPainter oldDelegate) => false;
}
