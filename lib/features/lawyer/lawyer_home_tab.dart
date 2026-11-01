import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/lawyer_availability_card.dart';
import '../../core/services/geo_naming_service.dart';
import '../../core/widgets/app_card.dart';
import 'lawyer_urgent_service_intro_screen.dart';

/// الواجهة الرئيسية المستقلة للمحامي
/// تعكس هوية المنصة وتخصص المحامي مع حذف بنر الموكل ومربع البحث
class LawyerHomeTab extends StatefulWidget {
  const LawyerHomeTab({super.key});

  @override
  State<LawyerHomeTab> createState() => _LawyerHomeTabState();
}

class _LawyerHomeTabState extends State<LawyerHomeTab> {
  String _dualName = '';
  String _syndicateNumber = '';
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
    final savedName = prefs.getString('user_name');
    final savedSyndicate = prefs.getString('syndicate_number');
    final savedLocation = prefs.getString('user_location_name');

    if (!mounted) return;

    setState(() {
      if (savedName != null && savedName.trim().isNotEmpty) {
        final words = savedName.trim().split(RegExp(r'\s+'));
        _dualName = words.length >= 2 ? '${words[0]} ${words[1]}' : words[0];
      }
      if (savedSyndicate != null && savedSyndicate.trim().isNotEmpty) {
        _syndicateNumber = savedSyndicate.trim();
      }
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
            const LawyerAvailabilityCard(),
            // 1. كارت منسق لبيانات المحامي المهنية والعنوان الجغرافي (نص فقط دون أيقونة إشعارات مكررة)
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
              child: Row(
                children: [
                  // صورة/أيقونة الحساب (7.0px)
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(7.0),
                      border: Border.all(color: AppColors.cardBorder, width: 1.0),
                    ),
                    child: const Center(
                      child: Icon(Icons.shield_rounded, color: AppColors.primary, size: 24),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // بيانات المحامي: اللقب أ/ + الاسم ثنائياً + رقم القيد بالنقابة
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'أ/ $_dualName',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'AppFont',
                            fontFamilyFallback: appFontFallback,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: AppColors.dark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _syndicateNumber.isEmpty ? 'رقم القيد غير مسجل' : 'رقم القيد: $_syndicateNumber',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'AppFont',
                            fontFamilyFallback: appFontFallback,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),

                  // العنوان الجغرافي: نص فقط غير قابل للضغط ودون أيقونات توحي بأنه زر
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on_rounded, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 110),
                        child: Text(
                          _locationName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'AppFont',
                            fontFamilyFallback: appFontFallback,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMain,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

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
              child: Row(
                children: [
                  RepaintBoundary(
                    child: SvgPicture.asset(
                      'assets/images/lawyer_pana.svg',
                      width: 50,
                      height: 50,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: 14),

                  // عنوان ووصف الخدمة الخاص بالمحامي
                  const Expanded(
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
                          'خدمة تتيح لك التقدم للانضمام إلى قائمة مقدمي الخدمة المعتمدين لتقديم المساعدة القانونية العاجلة للموكلين.',
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

                  const SizedBox(width: 8),
                  const Icon(
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

