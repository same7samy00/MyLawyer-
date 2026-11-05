import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/api_service.dart';

/// صورة الحساب، وبديلها أيقونة لو لسه ما اترفعتش
class ProfilePhoto extends StatelessWidget {
  final String? path;
  final double size;

  const ProfilePhoto({super.key, required this.path, this.size = 64});

  @override
  Widget build(BuildContext context) {
    final fallback = Icon(Icons.person_rounded, color: AppColors.primary, size: size * 0.55);
    final photo = path ?? '';

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(7.0),
      ),
      child: photo.isEmpty
          ? fallback
          : CachedNetworkImage(
              imageUrl: '${ApiService.baseUrl.replaceAll('/api/v1', '')}$photo',
              fit: BoxFit.cover,
              memCacheWidth: (size * 3).toInt(),
              placeholder: (_, __) => fallback,
              errorWidget: (_, __, ___) => fallback,
            ),
    );
  }
}
