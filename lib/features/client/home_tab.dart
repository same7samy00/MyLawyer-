import '../../core/widgets/app_pressable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/device_permission_service.dart';
import '../../core/services/geo_naming_service.dart';
import '../../core/widgets/app_card.dart';
import '../urgent_service/urgent_service_problem_screen.dart';
import '../auth/location_permission_screen.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  String _locationName = 'تحديد الموقع';
  String _userName = 'العميل';

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _resolveRealLocation();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLocation = prefs.getString('user_location_name');
    final savedName = prefs.getString('user_name');
    if (mounted) {
      setState(() {
        if (savedLocation != null && savedLocation.trim().isNotEmpty) {
          _locationName = savedLocation.trim();
        }
        if (savedName != null && savedName.trim().isNotEmpty) {
          _userName = savedName.trim();
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
                      child: Icon(Icons.person_rounded, color: AppColors.primary, size: 24),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // الاسم الخاص بالموكل
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'أهلاً بك،',
                          style: TextStyle(
                            fontFamily: 'AppFont',
                            fontFamilyFallback: appFontFallback,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _userName,
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
                        constraints: const BoxConstraints(maxWidth: 115),
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
            const SizedBox(height: 18),

            // 2. «محاميك حالاً» Banner with Global Team SVG Illustration
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
              backgroundColor: AppColors.primary,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'محاميك حالاً',
                          style: TextStyle(
                            fontFamily: 'AppFont',
                            fontFamilyFallback: appFontFallback,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'طلب مساعدة قانونية عاجلة من أقرب محامي متاح لموقعك الآن.',
                          style: TextStyle(
                            fontFamily: 'AppFont',
                            fontFamilyFallback: appFontFallback,
                            fontSize: 12,
                            color: AppColors.primaryLight,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 12),
                        AppPressable(
                          child: ElevatedButton(
                            onPressed: _openUrgentService,
                            style: ElevatedButton.styleFrom(
                              overlayColor: Colors.transparent,
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.primary,
                              minimumSize: const Size(96, 38),
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                            ),
                            child: const Text(
                              'طلب الآن',
                              style: TextStyle(
                                fontFamily: 'AppFont',
                                fontFamilyFallback: appFontFallback,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  RepaintBoundary(
                    child: SvgPicture.asset(
                      'assets/images/lawyer_pana.svg',
                      width: 120,
                      height: 110,
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              ),
            ),
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
              svgAsset: 'assets/images/lawyer_pana.svg',
              onTap: _openUrgentService,
            ),
            const SizedBox(height: 10),
            _buildServiceListItem(
              title: 'استشارة قانونية متخصصة',
              desc: 'تواصل مباشر واستشارة مع نخبة من المستشارين القانونيين المعتمدين',
              icon: Icons.forum_rounded,
              onTap: () {
                _showServiceNotice('خدمة الاستشارات القانونية المتخصصة');
              },
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
          '$serviceName ستتوفر للحجز المباشر قريباً جداً.',
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
    String? svgAsset,
    required VoidCallback onTap,
  }) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: onTap,
      child: Row(
        children: [
          // Icon or SVG with RepaintBoundary for optimal scrolling performance
          if (svgAsset != null)
            RepaintBoundary(
              child: SvgPicture.asset(
                svgAsset,
                width: 44,
                height: 44,
                fit: BoxFit.contain,
              ),
            )
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
