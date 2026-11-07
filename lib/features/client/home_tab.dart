import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/device_permission_service.dart';
import '../../core/services/geo_naming_service.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/lawyer_pin_illustration.dart';
import '../../core/widgets/profile_home_card.dart';
import '../auth/location_permission_screen.dart';
import '../consultation/consultation_type_screen.dart';
import '../urgent_service/urgent_service_problem_screen.dart';
import 'home_banners.dart';

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

            // 5. Legal Services List (LIST Style)
            _buildServiceListItem(
              title: 'محاميك حالاً',
              desc: 'طلب مساعدة قانونية عاجلة ومباشرة من أقرب محامٍ متاح لموقعك الآن',
              icon: Icons.shield_rounded,
              highlighted: true,
              onTap: _openUrgentService,
            ),
            const SizedBox(height: 10),
            _buildServiceListItem(
              title: 'استشارة سريعة',
              desc: 'اكتب مشكلتك وادفع، وفريقنا القانوني يكلمك على تليفونك خلال دقايق',
              icon: Icons.support_agent_rounded,
              image: 'assets/images/consultation_icon.png',
              onTap: _openConsultation,
            ),
            const SizedBox(height: 10),
            _buildServiceListItem(
              title: 'صياغة ومراجعة العقود',
              desc: 'صياغة قانونية محكمة ومراجعة شاملة لجميع بنود الاتفاقيات والوثائق',
              icon: Icons.description_rounded,
              onTap: () {
                _showServiceNotice('خدمة صياغة ومراجعة العقود');
              },
            ),
            const SizedBox(height: 10),
            _buildServiceListItem(
              title: 'تأسيس الشركات والتراخيص',
              desc: 'إنهاء إجراءات السجل التجاري والبطاقة الضريبية واستخراج التراخيص',
              icon: Icons.business_rounded,
              onTap: () {
                _showServiceNotice('خدمة تأسيس الشركات والتراخيص');
              },
            ),
            const SizedBox(height: 10),
            _buildServiceListItem(
              title: 'إدارة القضايا والتوكيلات',
              desc: 'توكيل محامٍ لمتابعة الدعاوى والجلسات وإيداع المذكرات القضائية',
              icon: Icons.policy_rounded,
              onTap: () {
                _showServiceNotice('خدمة إدارة القضايا والتوكيلات');
              },
            ),
            const SizedBox(height: 16),
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

  void _showServiceNotice(String serviceName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$serviceName ستتوفر للحجز المباشر قريباً جداً',
          style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback),
        ),
        backgroundColor: AppColors.dark,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildServiceListItem({
    required String title,
    required String desc,
    IconData? icon,
    String? image,
    bool highlighted = false,
    required VoidCallback onTap,
  }) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: onTap,
      child: Row(
        children: [
          // Icon or SVG with RepaintBoundary for optimal scrolling performance
          // «محاميك حالاً» بنفس صورة البانر اللي فوق
          if (highlighted)
            const RepaintBoundary(child: LawyerPinIllustration(size: 48))
          else if (image != null)
            Image.asset(image, width: 48, height: 48, fit: BoxFit.contain, cacheWidth: 144)
          else
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
