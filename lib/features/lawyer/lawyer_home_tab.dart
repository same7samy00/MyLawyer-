import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/lawyer_availability_card.dart';
import '../../core/services/geo_naming_service.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/lawyer_pin_illustration.dart';
import '../../core/widgets/profile_home_card.dart';
import 'lawyer_urgent_service_intro_screen.dart';

/// الواجهة الرئيسية المستقلة للمحامي
/// تعكس هوية المنصة وتخصص المحامي مع حذف بنر الموكل ومربع البحث
class LawyerHomeTab extends StatefulWidget {
  const LawyerHomeTab({super.key});

  @override
  State<LawyerHomeTab> createState() => _LawyerHomeTabState();
}

class _LawyerHomeTabState extends State<LawyerHomeTab> {
  String _locationName = 'تحديد الموقع';

  @override
  void initState() {
    super.initState();
    _loadLawyerData();
    _resolveRealLocation();
  }

  /// تحميل بيانات المحامي من التخزين المحلي واستخراج الاسم ثنائياً ورقم القيد
  Future<void> _loadLawyerData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLocation = prefs.getString('user_location_name');

    if (!mounted) return;

    setState(() {
      if (savedLocation != null && savedLocation.trim().isNotEmpty) {
        _locationName = savedLocation.trim();
      }
    });
  }

  /// استخراج الموقع الجغرافي الحقيقي للمحامي دون نصوص وهمية
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
      debugPrint('LawyerHomeTab location resolution error: $e');
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
            // 1. كارت منسق لبيانات المحامي المهنية والعنوان الجغرافي (نص فقط دون أيقونة إشعارات مكررة)
            ProfileHomeCard(locationName: _locationName),
            const SizedBox(height: 14),
            const LawyerAvailabilityCard(),

            const SizedBox(height: 10),

            // عنوان قسم الخدمات القانونية المتاحة للمحامي
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

            // خدمة واحدة فقط للمحامي: «محاميك حالاً»
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const LawyerUrgentServiceIntroScreen(),
                  ),
                );
              },
              child: const Row(
                children: [
                  RepaintBoundary(
                    child: LawyerPinIllustration(size: 56),
                  ),
                  SizedBox(width: 14),

                  // عنوان ووصف الخدمة الخاص بالمحامي
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'محاميك حالاً',
                          style: TextStyle(
                            fontFamily: 'AppFont',
                            fontFamilyFallback: appFontFallback,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.dark,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'خدمة تتيح لك التقدم للانضمام إلى قائمة مقدمي الخدمة المعتمدين لتقديم المساعدة القانونية العاجلة للموكلين',
                          style: TextStyle(
                            fontFamily: 'AppFont',
                            fontFamilyFallback: appFontFallback,
                            fontSize: 12,
                            height: 1.4,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

