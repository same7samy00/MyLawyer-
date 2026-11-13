import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// تحميل المحتوى في كل التطبيق: أشكال رمادي فاتح بنفس مكان المحتوى، بتنور وتهدى بهدوء.
/// المستخدم بيشوف شكل الصفحة على طول بدل علامة بتلف. الأزرار والأماكن الصغيرة بس بتفضل على [AppLoader]
class AppSkeleton extends StatefulWidget {
  final Widget child;

  const AppSkeleton({super.key, required this.child});

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'جاري التحميل',
      child: _SkeletonPulse(notifier: _controller, child: widget.child),
    );
  }
}

/// كل الأشكال جوه نفس [AppSkeleton] بتنور مع بعض
class _SkeletonPulse extends InheritedNotifier<Animation<double>> {
  const _SkeletonPulse({required super.notifier, required super.child});
}

/// شكل واحد: سطر نص، أو صورة، أو كارت. الحواف 7 زي التطبيق كله، والدايرة للصور الشخصية
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final bool circle;

  const SkeletonBox({super.key, this.width, this.height = 12, this.circle = false});

  @override
  Widget build(BuildContext context) {
    final pulse = context.dependOnInheritedWidgetOfExactType<_SkeletonPulse>()?.notifier?.value ?? 0;
    return Container(
      width: circle ? height : width,
      height: height,
      decoration: BoxDecoration(
        color: Color.lerp(AppColors.skeleton, AppColors.skeletonShine, Curves.easeInOut.transform(pulse)),
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(7.0),
      ),
    );
  }
}

/// كارت بنفس شكل كروت القوايم: مربع على الجنب وسطرين، والسطرين بينهم مسافة زي النص الحقيقي
class SkeletonRow extends StatelessWidget {
  final bool circle;

  const SkeletonRow({super.key, this.circle = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(7.0),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          SkeletonBox(width: 40, height: 40, circle: circle),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FractionallySizedBox(widthFactor: 0.6, child: SkeletonBox(height: 13)),
                SizedBox(height: 8),
                FractionallySizedBox(widthFactor: 0.38, child: SkeletonBox(height: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// صفحة بتتحمل: كارت كبير فوق لو الصفحة فيها رصيد أو صورة، وتحته كروت القايمة
class AppSkeletonList extends StatelessWidget {
  final int count;

  /// اللي فوق القايمة (رصيد، صورة شخصية)، بنفس مقاسه الحقيقي عشان الصفحة ما تتحركش لما تتحمل
  final Widget? top;
  final bool circle;
  final EdgeInsetsGeometry padding;

  const AppSkeletonList({
    super.key,
    this.count = 6,
    this.top,
    this.circle = false,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return AppSkeleton(
      child: ListView(
        padding: padding,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          if (top != null) ...[top!, const SizedBox(height: 14)],
          for (var i = 0; i < count; i++) ...[
            SkeletonRow(circle: circle),
            if (i < count - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}
