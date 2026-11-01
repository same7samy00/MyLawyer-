import 'package:flutter/material.dart';

/// يغلق لوحة المفاتيح عند الضغط على مكان فارغ، والعناصر القابلة للضغط تحتفظ بضغطتها
class KeyboardDismissArea extends StatelessWidget {
  final Widget child;

  const KeyboardDismissArea({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: child,
    );
  }
}
