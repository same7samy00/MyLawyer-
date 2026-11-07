import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// التحميل الموحد في كل الأبلكيشن: نقط على شكل دايرة بتلف، وكل نقطة أصغر وأبهت من اللي قدامها.
/// [padded] بيحط فراغ فوق وتحت عشان التحميل ما يلزقش في نص أو زرار.
/// جوه الأزرار والأماكن الصغيرة استخدم [AppLoader.inline]
class AppLoader extends StatefulWidget {
  final double size;
  final Color color;
  final bool padded;

  const AppLoader({super.key, this.size = 30, this.color = AppColors.primary, this.padded = true});

  const AppLoader.inline({super.key, this.size = 18, this.color = AppColors.primary}) : padded = false;

  /// الفراغ اللي فوق وتحت التحميل لما يكون جنب محتوى
  static const double gap = 22;

  @override
  State<AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<AppLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))
    ..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loader = SizedBox.square(
      dimension: widget.size,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(painter: _DotsPainter(_controller.value, widget.color)),
        ),
      ),
    );
    if (!widget.padded) return loader;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppLoader.gap),
      child: Center(child: loader),
    );
  }
}

class _DotsPainter extends CustomPainter {
  static const int _count = 8;
  final double progress;
  final Color color;

  const _DotsPainter(this.progress, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final dotRadius = size.width * 0.09;
    final ring = size.width / 2 - dotRadius;
    final head = (progress * _count).floor();
    for (var i = 0; i < _count; i++) {
      // النقطة اللي في الراس أكبر وأغمق، واللي وراها بتبهت
      final behind = (head - i) % _count;
      final strength = 1 - behind / _count;
      final angle = -math.pi / 2 + i * 2 * math.pi / _count;
      final offset = center + Offset(math.cos(angle), math.sin(angle)) * ring;
      canvas.drawCircle(
        offset,
        dotRadius * (0.55 + 0.45 * strength),
        Paint()..color = color.withOpacity(0.2 + 0.8 * strength),
      );
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) => old.progress != progress || old.color != color;
}
