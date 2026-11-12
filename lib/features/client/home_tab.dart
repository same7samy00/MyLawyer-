import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/app_cached_tile_provider.dart';
import '../../core/services/device_permission_service.dart';
import '../../core/services/geo_naming_service.dart';
import '../../core/services/location_service.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/profile_home_card.dart';
import '../auth/location_permission_screen.dart';
import '../consultation/consultation_type_screen.dart';
import '../urgent_service/urgent_service_problem_screen.dart';
import 'home_banners.dart';
import 'legal_services.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  String _locationName = 'تحديد الموقع';

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _resolveRealLocation();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLocation = prefs.getString('user_location_name');
    if (mounted) {
      setState(() {
        if (savedLocation != null && savedLocation.trim().isNotEmpty) {
          _locationName = savedLocation.trim();
        }
      });
    }
  }

  /// استخراج الموقع الحقيقي للمستخدم من إحداثيات الجهاز دون استخدام نصوص وهمية
  Future<void> _resolveRealLocation() async {
    try {
      final pos = await LocationService.instance.positionIfAllowed();
      if (pos != null) {
        // مربعات الخريطة حوالين الموكل تتحمل من دلوقتي، فخريطة «محاميك حالاً» تفتح كاملة
        unawaited(AppCachedTileProvider.warmAround(pos.latitude, pos.longitude));
        final realAddress = await GeoNamingService.instance.getCityAndGovernorate(
          pos.latitude,
          pos.longitude,
        );
        if (realAddress.isNotEmpty && mounted) {
          setState(() {
            _locationName = realAddress;
          });
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_location_name', realAddress);
        }
      }
    } catch (e) {
      debugPrint('HomeTab location resolution error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. كارت منسق لبيانات الموكل والعنوان الجغرافي (نص فقط دون أيقونة إشعارات مكررة)
            ProfileHomeCard(locationName: _locationName),
            const SizedBox(height: 18),

            // 2. البانرات: «محاميك حالاً» و«استشارة سريعة»، بتتقلب لوحدها
            HomeBannersCarousel.client(onUrgent: _openUrgentService, onConsultation: _openConsultation),
            const SizedBox(height: 22),

            // 4. Services List Title
            const Text(
              'الخدمات القانونية المتاحة',
              style: TextStyle(
                fontFamily: 'AppFont',
                fontFamilyFallback: appFontFallback,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.dark,
              ),
            ),
            const SizedBox(height: 12),

            // 5. الخدمات (LegalService): أول تلاتة بتفتح الاستشارة، ومن «محضر شرطة» بتفتح «محاميك حالاً» بالمشكلة مكتوبة
            for (final service in LegalService.all) ...[
              _buildServiceListItem(
                title: service.title,
                desc: service.desc,
                icon: service.icon,
                onTap: () => service.open(context),
              ),
              const SizedBox(height: 10),
            ],
            // مساحة لمحاميحو تحت على الشمال عشان ما يغطيش آخر خدمة
            const SizedBox(height: 90),
          ],
        ),
      ),
    );
  }

  void _openConsultation() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const QuickConsultationScreen()));
  }

  Future<void> _openUrgentService() async {
    final hasLocation = await DevicePermissionService.instance.isLocationPermissionGranted();
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => hasLocation ? const UrgentServiceProblemScreen() : const LocationPermissionScreen(),
      ),
    );
  }

  Widget _buildServiceListItem({
    required String title,
    required String desc,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: onTap,
      child: Row(
        children: [
          Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Center(
                child: Icon(icon, color: AppColors.primary, size: 22),
              ),
            ),
          const SizedBox(width: 14),

          // Title & Description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'AppFont',
                    fontFamilyFallback: appFontFallback,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.dark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  style: const TextStyle(
                    fontFamily: 'AppFont',
                    fontFamilyFallback: appFontFallback,
                    fontSize: 11,
                    height: 1.35,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Trailing Arrow
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textMuted,
            size: 20,
          ),
        ],
      ),
    );
  }
}
