import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// رسمة في المنتصف يمر خلفها خط من حافة الشاشة إلى الحافة الأخرى
/// [bleed] هو الهامش الأفقي للمحتوى الذي يتجاوزه الخط
class EdgeLinesIllustration extends StatelessWidget {
  final String asset;
  final double height;
  final double bleed;

  const EdgeLinesIllustration({
    super.key,
    required this.asset,
    required this.height,
    required this.bleed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned(
            left: -bleed,
            right: -bleed,
            top: 0,
            bottom: 0,
            child: SvgPicture.asset(
              'assets/images/auth_lines.svg',
              fit: BoxFit.fill,
              excludeFromSemantics: true,
            ),
          ),
          SvgPicture.asset(
            asset,
            height: height,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
          ),
        ],
      ),
    );
  }
}
