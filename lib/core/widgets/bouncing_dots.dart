import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// تحميل خفيف: 3 نقط بتنط ورا بعض، ومقاسها ثابت فما بتحركش اللي حواليها
class BouncingDots extends StatefulWidget {
  final Color color;
  final double size;

  const BouncingDots({super.key, this.color = AppColors.primary, this.size = 10});

  @override
  State<BouncingDots> createState() => _BouncingDotsState();
}

class _BouncingDotsState extends State<BouncingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
    ..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return SizedBox(
      width: size * 5,
      height: size * 2.2,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < 3; i++) _dot(i),
          ],
        ),
      ),
    );
  }

  Widget _dot(int index) {
    // كل نقطة بتبدأ بعد اللي قبلها بشوية، وبتطلع وتنزل في نص الدورة
    final t = (_controller.value - index * 0.18) % 1.0;
    final lift = t < 0.5 ? Curves.easeOut.transform(t * 2) : Curves.easeIn.transform(2 - t * 2);
    return Transform.translate(
      offset: Offset(0, -lift * widget.size * 1.1),
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}
