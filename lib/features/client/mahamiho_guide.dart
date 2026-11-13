import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import 'mahamiho_chat_screen.dart';
import 'mahamiho_figure.dart';

/// محاميحو في كل صفحات الشريط السفلي: نص جسمه من الراس للحزام تحت على الشمال، ونص الجزء الظاهر بيختفي في أبيض.
/// جنبه قريب منه سحابة زرقا مايلة ناحية راسه فيها «أهلاً! أنا محاميحو».
/// أول ما يظهر بينط هو والسحابة مع بعض ويشاور، وبعدها كل شوية بينطوا تاني ويعمل حركة (تمام، بيفكّر، بيشاور).
/// لمسه بيفتح صفحة محاميحو (MahamihoChatScreen)
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

class _MahamihoGuideState extends State<MahamihoGuide> with SingleTickerProviderStateMixin {
  // بالترتيب ده، وبيلف
  static const _cycle = [MahamihoMood.ok, MahamihoMood.thinking, MahamihoMood.wave];
  static const _gap = Duration(seconds: 6);

  /// النطة: هو والسحابة بيطلعوا لفوق وينزلوا مع بعض
  late final AnimationController _jump;

  Timer? _timer;
  bool _visible = false;
  MahamihoMood _mood = MahamihoMood.idle;
  int _next = 0;

  @override
  void initState() {
    super.initState();
    _jump = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
    if (MahamihoGuide._greeted) {
      _visible = true;
      _schedule(_gap, _playNext);
      return;
    }
    MahamihoGuide._greeted = true;
    _schedule(const Duration(milliseconds: 1200), () {
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
    _jump.dispose();
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

  /// بينط ويعمل الحركة من أولها، وبعدها يرجع واقف ويستنى
  void _start(MahamihoMood mood) {
    AssetImage(mood.asset).evict();
    setState(() => _mood = mood);
    _jump.forward(from: 0);
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
    final cloudWidth = (screen * 0.42).clamp(150.0, 180.0);
    final cloudHeight = cloudWidth * _CloudPainter.ratio;

    return Stack(
      children: [
        Positioned(
          left: 0,
          bottom: 0,
          width: width + cloudWidth,
          height: height + 24,
          child: AnimatedBuilder(
            animation: _jump,
            builder: (context, child) {
              // طلعة سريعة ونزلة فيها رجّة صغيرة
              final t = _jump.value;
              final lift = t == 0 ? 0.0 : math.sin(math.pi * Curves.easeOut.transform(t)) * 22;
              return Transform.translate(offset: Offset(0, 24 - lift), child: child);
            },
            child: GestureDetector(
              onTap: _onTap,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 2,
                    top: 0,
                    child: Semantics(
                      label: 'محاميحو',
                      button: true,
                      child: MahamihoFigure(mood: _mood, width: width, halfBody: true),
                    ),
                  ),
                  // قريبة منه وطرفها مايل ناحية راسه
                  Positioned(
                    left: width * 0.74,
                    top: height * 0.02,
                    width: cloudWidth,
                    height: cloudHeight,
                    child: Transform.rotate(
                      angle: -0.12,
                      alignment: Alignment.bottomLeft,
                      child: const _Cloud(text: MahamihoGuide.hello),
                    ),
                  ),
                ],
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
