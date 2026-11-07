import 'package:flutter/material.dart';

/// صورة «محاميك حالاً»: محامي لابس بدلة وساند على دبوس خريطة.
/// [white] نسخة بيضا للخلفيات الزرقا زي البانر، والعادية زرقا للخلفيات الفاتحة
class LawyerPinIllustration extends StatelessWidget {
  final double size;
  final bool white;

  const LawyerPinIllustration({super.key, this.size = 72, this.white = false});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      white ? 'assets/images/lawyer_pin_white.png' : 'assets/images/lawyer_pin.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      cacheWidth: (size * 3).round(),
    );
  }
}
