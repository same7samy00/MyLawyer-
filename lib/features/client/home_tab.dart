import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/app_cached_tile_provider.dart';
import '../../core/services/device_permission_service.dart';
import '../../core/services/geo_naming_service.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/profile_home_card.dart';
import '../auth/location_permission_screen.dart';
import '../consultation/consultation_type_screen.dart';
import '../urgent_service/problem_description_screen.dart';
import '../urgent_service/urgent_service_problem_screen.dart';
import 'home_banners.dart';

/// خدمة في قايمة الرئيسية. اللي ليها مشكلة بتفتح «محاميك حالاً»، والباقي بيفتح الاستشارة
class _Service {
  final String title;
  final String desc;
  final IconData icon;
  final String? urgentProblem;
  const _Service(this.title, this.desc, this.icon, {this.urgentProblem});
}

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
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        final pos = await Geolocator.getLastKnownPosition();
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

            // 5. الخدمات: أول تلاتة بتفتح الاستشارة، ومن «محضر شرطة» بتفتح «محاميك حالاً» بالمشكلة مكتوبة
            for (final service in _services) ...[
              _buildServiceListItem(
                title: service.title,
                desc: service.desc,
                icon: service.icon,
                onTap: service.urgentProblem == null ? _openConsultation : () => _openUrgentService(service.urgentProblem),
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

  /// المشكلة بتتكتب في الطلب على طول، ومن غيرها بتتفتح قايمة المشاكل
  Future<void> _openUrgentService([String? problem]) async {
    final hasLocation = await DevicePermissionService.instance.isLocationPermissionGranted();
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => !hasLocation
            ? const LocationPermissionScreen()
            : problem == null
                ? const UrgentServiceProblemScreen()
                : ProblemDescriptionScreen(problemTitle: problem),
      ),
    );
  }

  static const _services = [
    _Service('استشارة قانونية', 'احكي مشكلتك ومحامي يكلمك خلال دقايق', Icons.support_agent_rounded),
    _Service('اطلاع على مستندات', 'محامي يراجع ورقك ويقولك موقفك', Icons.find_in_page_rounded),
    _Service('كتابة عقد أو مستندات', 'عقد أو إنذار أو أي ورقة قانونية مظبوطة', Icons.edit_document),
    _Service('محضر شرطة', 'محامي يروحلك القسم دلوقتي', Icons.local_police_rounded, urgentProblem: 'محضر في قسم الشرطة'),
    _Service('تحقيق نيابة', 'محامي يحضر معاك التحقيق', Icons.manage_search_rounded, urgentProblem: 'تحقيق عاجل في النيابة العامة'),
    _Service('حضور جلسة', 'محامي يحضر عنك أو معاك الجلسة', Icons.event_available_rounded, urgentProblem: 'حضور جلسة'),
    _Service('حضور مجلس عرفي', 'محامي يحضر الجلسة العرفية ويحفظ حقك', Icons.groups_rounded, urgentProblem: 'حضور مجلس عرفي'),
    _Service('إجراءات إدارية', 'محامي يخلّصلك ورقك في الجهات الحكومية', Icons.assignment_turned_in_rounded, urgentProblem: 'إجراءات إدارية'),
  ];

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
