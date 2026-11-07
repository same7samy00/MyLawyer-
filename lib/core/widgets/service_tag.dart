import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// اسم الخدمة فوق كل كارت في صفحة الطلبات، عشان الصفحة فيها كل الخدمات مع بعض
class ServiceTag extends StatelessWidget {
  final String name;
  final IconData icon;

  const ServiceTag({super.key, required this.name, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(7.0)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.primary),
            const SizedBox(width: 5),
            Text(
              name,
              style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}
