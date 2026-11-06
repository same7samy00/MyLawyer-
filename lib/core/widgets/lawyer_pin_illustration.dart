import 'package:flutter/material.dart';

/// صورة «محاميك حالاً»: محامي لابس بدلة وساند على دبوس خريطة.
/// على خلفية زرقا بتتحط جوه دايرة بيضا عشان تبان
class LawyerPinIllustration extends StatelessWidget {
  final double size;
  final bool onDark;

  const LawyerPinIllustration({super.key, this.size = 72, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    final image = Image.asset('assets/images/lawyer_pin.png', width: size, height: size, fit: BoxFit.contain);
    if (!onDark) return image;
    return Container(
      width: size + 12,
      height: size + 12,
      padding: const EdgeInsets.all(6),
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      child: image,
    );
  }
}
