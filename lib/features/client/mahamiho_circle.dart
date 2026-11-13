import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import 'mahamiho_bubble.dart';
import 'mahamiho_figure.dart';

/// محاميحو في دايرة في نص الصفحة (بيطلع من جوه الدايرة بسحب أول ما يظهر)، وفوق راسه فقاعة كلامه (من غير دبوس) بتكتب الجمل جملة جملة.
/// راسه طالعة برا الدايرة من فوق وجسمه جواها من تحت. والحلقات حوالين الدايرة بتكبر مع [level]
/// (صوت الموكل) وبتتنفس مع [breath]، ومن غيرهم بتفضل ثابتة. ده شكل صفحة الصوت وشات محاميحو
class MahamihoStage extends StatelessWidget {
  final MahamihoMood mood;
  final List<String> lines;

  /// false: الجمل بتتقال مرة واحدة وتقف على آخر جملة. true: بتلف
  final bool loop;
  final double bubbleWidth;
  final ValueListenable<double>? level;
  final Animation<double>? breath;

  const MahamihoStage({
    super.key,
    required this.mood,
    required this.lines,
    this.loop = true,
    this.bubbleWidth = 230,
    this.level,
    this.breath,
  });

  /// الصورة فيها فراغ شفاف فوق الراس، فالفقاعة بتنزل عليه عشان تبقى فوق الراس بمسافة صغيرة
  static const double _bubbleDrop = 17;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.translate(
          offset: const Offset(0, _bubbleDrop),
          child: MahamihoBubble(
            key: ValueKey(lines.join('\n')),
            lines: lines,
            loop: loop,
            delay: const Duration(milliseconds: 300),
            maxWidth: bubbleWidth,
          ),
        ),
        const SizedBox(height: 4),
        MahamihoCircle(mood: mood, level: level, breath: breath),
      ],
    );
  }
}

class MahamihoCircle extends StatelessWidget {
  final MahamihoMood mood;
  final ValueListenable<double>? level;
  final Animation<double>? breath;

  const MahamihoCircle({super.key, required this.mood, this.level, this.breath});

  /// مقاسات الدايرة: الراس طالعة برا من فوق، والجسم جوه الدايرة من تحت
  static const double _circleR = 75;
  static const double _headRoom = 40;
  static const double _figW = 124;
  static const double _areaW = 230;
  static const double _areaH = 250;
  static const double _top = 20;
  static const double _centerY = _top + _areaW / 2;

  @override
  Widget build(BuildContext context) {
    final moving = Listenable.merge([if (level != null) level, if (breath != null) breath]);
    return RepaintBoundary(
      child: SizedBox(
        width: _areaW,
        height: _areaH,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: _top,
              left: 0,
              width: _areaW,
              height: _areaW,
              child: AnimatedBuilder(
                animation: moving,
                builder: (_, __) {
                  final l = (level?.value ?? 0.0).clamp(0.0, 1.0);
                  final b = breath == null ? 0.0 : 0.03 * math.sin(breath!.value * 2 * math.pi);
                  Widget ring(double size, double opacity, [Key? key]) => AnimatedContainer(
                        key: key,
                        duration: const Duration(milliseconds: 90),
                        width: size,
                        height: size,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primary.withOpacity(opacity)),
                      );
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      ring(2 * _circleR + 80 * l + 230 * b, 0.08, const ValueKey('voice-ring')),
                      ring(2 * _circleR + 44 * l + 120 * b, 0.14),
                      Container(
                        width: 2 * _circleR,
                        height: 2 * _circleR,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryLight,
                          border: Border.all(color: AppColors.primary, width: 2),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            // محاميحو في نص الدايرة بالعرض: راسه برا من فوق، ومن تحت مقصوص على حافة الدايرة
            Positioned.fill(
              child: ClipPath(
                clipper: const _KeyholeClipper(center: Offset(_areaW / 2, _centerY), radius: _circleR - 1),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      top: _centerY - _circleR - _headRoom,
                      // الصورة نفسها جسمه فيها شايل لليمين شوية، فبنرجّعه لنص الدايرة
                      left: (_areaW - _figW) / 2 - _figW * 0.11,
                      width: _figW,
                      // بيطلع بسحب من جوه الدايرة لفوق مرة واحدة أول ما يظهر
                      child: _RiseInCircle(drop: 2 * _circleR + _headRoom + 8, child: MahamihoFigure(mood: mood, width: _figW)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// محاميحو بيبدأ تحت الدايرة (مستخبي) ويطلع بسحب ناعم لمكانه، فبيبان طالع من جوه الدايرة
class _RiseInCircle extends StatefulWidget {
  final double drop;
  final Widget child;
  const _RiseInCircle({required this.drop, required this.child});

  @override
  State<_RiseInCircle> createState() => _RiseInCircleState();
}

class _RiseInCircleState extends State<_RiseInCircle> with SingleTickerProviderStateMixin {
  late final AnimationController _rise = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..forward();
  late final Animation<double> _curve = CurvedAnimation(parent: _rise, curve: Curves.easeOutCubic);

  @override
  void dispose() {
    _rise.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _curve,
        child: widget.child,
        builder: (_, child) => Transform.translate(offset: Offset(0, widget.drop * (1 - _curve.value)), child: child),
      );
}

/// قص على شكل «ثقب المفتاح»: كل اللي فوق نص الدايرة ظاهر، ومن نص الدايرة لتحت الدايرة نفسها بس
class _KeyholeClipper extends CustomClipper<Path> {
  final Offset center;
  final double radius;
  const _KeyholeClipper({required this.center, required this.radius});

  @override
  Path getClip(Size size) {
    final above = Path()..addRect(Rect.fromLTRB(-size.width, -size.height, size.width * 2, center.dy));
    final circle = Path()..addOval(Rect.fromCircle(center: center, radius: radius));
    return Path.combine(PathOperation.union, above, circle);
  }

  @override
  bool shouldReclip(_KeyholeClipper old) => old.center != center || old.radius != radius;
}
