import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// الكروت تصغر مع التصغير عشان ما تغطيش الخريطة
double mapCardScaleFor(double zoom) => zoom >= 13 ? 1.0 : (zoom >= 10 ? 0.75 : 0.55);

/// يصغّر الكارت كله حول سهمه، فيفضل السهم على مكانه في الخريطة
class ScaledMapCard extends StatelessWidget {
  final double width;
  final double height;
  final Widget child;

  const ScaledMapCard({super.key, required this.width, required this.height, required this.child});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: FittedBox(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          width: width,
          height: height,
          child: Align(alignment: Alignment.bottomCenter, child: child),
        ),
      ),
    );
  }
}

/// كارت موقع المستخدم على الخريطة
class MyLocationMapCard extends StatelessWidget {
  const MyLocationMapCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.dark,
            borderRadius: BorderRadius.circular(7.0),
          ),
          child: const Text(
            'موقعي الحالي',
            maxLines: 1,
            style: TextStyle(
              fontFamily: 'AppFont',
              fontFamilyFallback: appFontFallback,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -5),
          child: Transform.rotate(
            angle: 0.785398,
            child: Container(width: 10, height: 10, color: AppColors.dark),
          ),
        ),
      ],
    );
  }
}
