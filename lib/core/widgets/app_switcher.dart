import 'package:flutter/material.dart';

/// تبديل المحتوى جوه الشيت أو الصفحة: المحتوى الجديد يطلع من تحت بسرعة، والطول يتظبط بنعومة، من غير تلاشي
class AppSwitcher extends StatelessWidget {
  final Widget child;

  const AppSwitcher({super.key, required this.child});

  static const Duration duration = Duration(milliseconds: 220);

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: duration,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: duration,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        // القديم يختفي على طول، فمفيش تداخل بين المحتويين
        layoutBuilder: (current, previous) => current ?? const SizedBox.shrink(),
        transitionBuilder: (child, animation) => SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(animation),
          child: child,
        ),
        child: child,
      ),
    );
  }
}
