import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:lottie/lottie.dart' hide Marker;
import '../../core/constants/app_colors.dart';
import '../../core/constants/map_config.dart';
import '../../core/services/app_cached_tile_provider.dart';
import '../../core/services/geo_naming_service.dart';
import '../../core/services/location_service.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/lawyer_profile_summary.dart';
import '../../core/widgets/lawyer_reviews_panel.dart';
import '../../core/widgets/sheet_lines.dart';
import '../../data/models/map_lawyer.dart';
import '../../data/repositories/lawyer_repository.dart';
import '../urgent_service/lawyer_google_profile_screen.dart';
import 'main_navigation_shell.dart';
import '../auth/session_router.dart';

/// خريطة العرض الترويجية للمحامين القريبين (Nearby Lawyers Showcase Screen)
/// تظهر بعد تحديد الموقع للمستخدم الجديد كعرض تعريفي وترويجي للمحامين القريبين
/// بدون هيدر علوي، وبدون زر رجوع علوي، وبدون أي عناصر لطلب خدمة "محاميك حالاً"
/// يظهر البوتن شيت فقط عند الضغط على محامٍ معين، ويختفي بالضغط خارج البطاقة أو زر الإغلاق
class NearbyLawyersShowcaseScreen extends StatefulWidget {
  const NearbyLawyersShowcaseScreen({super.key});

  @override
  State<NearbyLawyersShowcaseScreen> createState() => _NearbyLawyersShowcaseScreenState();
}

class _NearbyLawyersShowcaseScreenState extends State<NearbyLawyersShowcaseScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  AnimationController? _cameraAnimController;

  Position? _currentPosition;
  String _locationName = 'جاري تحديد موقعك';
  bool _isInitialLoading = true;

  List<MapLawyer> _nearbyLawyers = [];
  MapLawyer? _selectedLawyer;
  bool _showReviews = false;

  @override
  void initState() {
    super.initState();
    _fetchCurrentLocation();
  }

  @override
  void dispose() {
    _cameraAnimController?.stop();
    _cameraAnimController?.dispose();
    super.dispose();
  }

  Future<void> _fetchCurrentLocation() async {
    Position? position;
    try {
      final result = await LocationService.instance.checkAndRequestPermission().timeout(
        const Duration(seconds: 4),
        onTimeout: () => const LocationResult(
          status: LocationServiceStatus.error,
          errorMessage: 'Location request timed out',
        ),
      );
      position = result.position;
    } catch (_) {}
    if (!mounted) return;

    // عند تعذر الموقع تعرض الخريطة نطاق القاهرة الكبرى الافتراضي
    final center = position != null
        ? LatLng(position.latitude, position.longitude)
        : const LatLng(30.0444, 31.2357);

    try {
      _mapController.move(center, 14.8);
    } catch (_) {}

    // تحويل الإحداثيات لاسم المدينة والمحافظة بالعربية بدقة وبدون تكرار
    final locationName = position != null
        ? await GeoNamingService.instance.getCityAndGovernorate(position.latitude, position.longitude)
        : 'محافظة القاهرة';

    final res = await LawyerRepository.getNearbyLawyers(lat: center.latitude, lon: center.longitude);
    if (!mounted) return;

    setState(() {
      _currentPosition = position;
      _locationName = locationName;
      _nearbyLawyers = (res.data ?? const []).map(MapLawyer.fromModel).toList();
      _isInitialLoading = false;
    });
  }

  void _animatedMapMove(
    LatLng destLocation,
    double destZoom, {
    Curve curve = Curves.easeInOutCubic,
    Duration duration = const Duration(milliseconds: 650),
  }) {
    // إلغاء أي حركة كاميرا سابقة لمنع التداخل والقفزات المفاجئة
    _cameraAnimController?.stop();
    _cameraAnimController?.dispose();
    _cameraAnimController = null;

    final camera = _mapController.camera;
    // التحقق مما إذا كان الموقع المطلوب والزووم متطابقين بالفعل لعدم تنفيذ حركة غير ضرورية
    final double latDiff = (camera.center.latitude - destLocation.latitude).abs();
    final double lngDiff = (camera.center.longitude - destLocation.longitude).abs();
    final double zoomDiff = (camera.zoom - destZoom).abs();
    if (latDiff < 0.00005 && lngDiff < 0.00005 && zoomDiff < 0.05) {
      return;
    }

    final latTween = Tween<double>(begin: camera.center.latitude, end: destLocation.latitude);
    final lngTween = Tween<double>(begin: camera.center.longitude, end: destLocation.longitude);
    final zoomTween = Tween<double>(begin: camera.zoom, end: destZoom);

    final controller = AnimationController(
      duration: duration,
      vsync: this,
    );
    _cameraAnimController = controller;

    final Animation<double> animation = CurvedAnimation(
      parent: controller,
      curve: curve,
    );

    controller.addListener(() {
      _mapController.move(
        LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
        zoomTween.evaluate(animation),
      );
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
        if (_cameraAnimController == controller) {
          _cameraAnimController = null;
        }
        controller.dispose();
      }
    });

    controller.forward();
  }

  void _onLawyerMarkerTapped(MapLawyer lawyer) {
    if (_selectedLawyer?.id == lawyer.id) return;

    setState(() {
      _selectedLawyer = lawyer;
    });

    // حساب إزاحة مركز الكاميرا لتوسيط المحامي تماماً في المساحة المرئية فوق البوتن شيت (390px)
    // الإزاحة تعادل تحريك المركز جنوباً بما يقارب 160 بكسل (~0.0042 درجة) لرفع موقع المحامي في النصف العلوي المرئي
    const double targetZoom = 15.2;
    const double latShift = 0.0042;
    final targetCenter = LatLng(lawyer.position.latitude - latShift, lawyer.position.longitude);

    _animatedMapMove(targetCenter, targetZoom);
  }

  void _closeLawyerProfile() {
    setState(() {
      _selectedLawyer = null;
    });
  }

  void _proceedToMainApp() {
    SessionRouter.replaceStack(Navigator.of(context), const MainNavigationShell());
  }

  void _openGoogleProfile() {
    final lawyer = _selectedLawyer;
    if (lawyer == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LawyerGoogleProfileScreen(lawyer: lawyer),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final centerLatLng = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : const LatLng(30.0444, 31.2357);

    // الرجوع يغلق ملف المحامي المفتوح أولاً قبل مغادرة الخريطة
    return PopScope(
      canPop: _selectedLawyer == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _closeLawyerProfile();
      },
      child: Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // 1. الخريطة التفاعلية الكاملة بدون هيدر
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: centerLatLng,
              initialZoom: 14.5,
              minZoom: 4.0,
              maxZoom: 18.0,
              onTap: (_, __) {
                if (_selectedLawyer != null) {
                  _closeLawyerProfile();
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: MapConfig.serverTileUrl,
                fallbackUrl: MapConfig.fallbackTileUrl,
                userAgentPackageName: MapConfig.userAgentPackage,
                tileProvider: AppCachedTileProvider.instance,
                maxNativeZoom: 18,
              ),

              // علامات المحامين وعلامة المستخدم
              MarkerLayer(
                markers: [
                  // نقطة موقع المستخدم
                  Marker(
                    point: centerLatLng,
                    width: 32,
                    height: 32,
                    child: _buildUserLocationMarker(),
                  ),

                  // علامات المحامين القريبين (بأبعاد متناسقة 140x52 لمنع الـ Overflow نهائياً)
                  for (final lawyer in _nearbyLawyers)
                    Marker(
                      point: lawyer.position,
                      width: 140,
                      height: 52,
                      alignment: Alignment.topCenter,
                      child: GestureDetector(
                        onTap: () => _onLawyerMarkerTapped(lawyer),
                        child: _ShowcaseLawyerPin(
                          lawyer: lawyer,
                          isSelected: _selectedLawyer?.id == lawyer.id,
                          isNearest: lawyer.id == _nearbyLawyers.firstOrNull?.id,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // 2. شارة الموقع الجغرافي المعروضة في المنتصف أعلى الخريطة (تم حذف زر الرجوع تماماً)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                child: Center(
                  child: Material(
                    color: Colors.white,
                    elevation: 3,
                    shadowColor: Colors.black.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12.0),
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _locationName,
                              style: const TextStyle(
                                fontFamily: 'AppFont',
                                fontFamilyFallback: appFontFallback,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.dark,
                              ),
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 3. أزرار التحكم بالخريطة (تكبير / تصغير / إعادة التمركز)
          Positioned(
            right: 16,
            bottom: _selectedLawyer != null ? 405 : 88,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildMapFloatingBtn(
                  icon: Icons.my_location_rounded,
                  color: AppColors.primary,
                  onPressed: () {
                    _animatedMapMove(centerLatLng, 15.0);
                  },
                ),
                const SizedBox(height: 8),
                _buildMapFloatingBtn(
                  icon: Icons.add,
                  color: AppColors.dark,
                  onPressed: () {
                    _animatedMapMove(
                      _mapController.camera.center,
                      _mapController.camera.zoom + 1,
                    );
                  },
                ),
                const SizedBox(height: 8),
                _buildMapFloatingBtn(
                  icon: Icons.remove,
                  color: AppColors.dark,
                  onPressed: () {
                    _animatedMapMove(
                      _mapController.camera.center,
                      _mapController.camera.zoom - 1,
                    );
                  },
                ),
              ],
            ),
          ),

          // 4. زر عائم ثابت للانتقال إلى الرئيسية (يظهر حينما لا يكون هناك محامٍ محدد)
          if (_selectedLawyer == null)
            Positioned(
              left: 20,
              right: 20,
              bottom: 24,
              child: SafeArea(
                top: false,
                child: AppButton.primary(
                  text: 'المتابعة إلى الرئيسية',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: _proceedToMainApp,
                  height: 50,
                ),
              ),
            ),

          // 5. البوتن شيت التعريفي للمحامي (مطابق 100% لاستايل ملف المحامي في محاميك حالاً)
          if (_selectedLawyer != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                top: false,
                child: Container(
                  height: _showReviews ? MediaQuery.sizeOf(context).height * 0.8 : 390.0,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28.0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 24,
                        offset: const Offset(0, -6),
                      ),
                    ],
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const SheetLines(top: 86),
                      Column(
                    children: [
                      // مقبض السحب العلوي وزر الإغلاق
                      Padding(
                        padding: const EdgeInsets.only(top: 10, left: 16, right: 16, bottom: 4),
                        child: Row(
                          children: [
                            const SizedBox(width: 32),
                            const Spacer(),
                            // مقبض السحب
                            Container(
                              width: 44,
                              height: 4.0,
                              decoration: BoxDecoration(
                                color: AppColors.cardBorder,
                                borderRadius: BorderRadius.circular(4.0),
                              ),
                            ),
                            const Spacer(),
                            // زر الإغلاق
                            GestureDetector(
                              onTap: _closeLawyerProfile,
                              child: Container(
                                width: 32,
                                height: 32,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.cardBorder),
                                ),
                                child: const Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: AppColors.dark,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // عنوان "أقرب المحامين إليك" في المنتصف
                      const Text(
                        'أقرب المحامين إليك',
                        style: TextStyle(
                          fontFamily: 'AppFont',
                          fontFamilyFallback: appFontFallback,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.dark,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // خط منقط فاصل
                      const _ShowcaseDashedLineSeparator(),
                      const SizedBox(height: 10),

                      // محتوى الملف التعريفي الكامل
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20.0, 0, 20.0, 14.0),
                          child: _showReviews
                              ? LawyerReviewsPanel(
                                  lawyerId: _selectedLawyer!.id,
                                  onClose: () => setState(() => _showReviews = false),
                                )
                              : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // 1. ملخص الملف التعريفي الموحد مع TrackingScreen
                              Expanded(
                                child: SingleChildScrollView(
                                  physics: const BouncingScrollPhysics(),
                                  child: LawyerProfileSummary(
                                    avatar: _ShowcaseAvatarPhoto(
                                      imageUrl: _selectedLawyer!.imageUrl,
                                      initials: _selectedLawyer!.avatarInitials,
                                      fallbackColor: _selectedLawyer!.avatarColor,
                                      size: 56,
                                    ),
                                    name: _selectedLawyer!.name,
                                    title: _selectedLawyer!.title,
                                    specialization: _selectedLawyer!.specialization,
                                    rating: _selectedLawyer!.rating,
                                    reviewsCount: _selectedLawyer!.reviewsCount,
                                    experienceYears: _selectedLawyer!.experienceYears,
                                    distanceText: '${_selectedLawyer!.distanceMeters.round()} م',
                                    isNearest: _selectedLawyer!.id == _nearbyLawyers.firstOrNull?.id,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),

                              // 2. ملف Google والتقييمات جنب بعض
                              Row(
                                children: [
                                  Expanded(
                                    child: AppButton.outlined(
                                      text: 'ملف Google',
                                      customIcon: SvgPicture.asset(
                                        'assets/images/google_logo.svg',
                                        width: 18,
                                        height: 18,
                                      ),
                                      onPressed: _openGoogleProfile,
                                      height: 44,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: AppButton.outlined(
                                      text: 'التقييمات (${_selectedLawyer!.reviewsCount})',
                                      onPressed: () => setState(() => _showReviews = true),
                                      height: 44,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // 3. زر المتابعة إلى الرئيسية
                              AppButton.primary(
                                text: 'المتابعة إلى الرئيسية',
                                              onPressed: _proceedToMainApp,
                                height: 44,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                    ],
                  ),
                ),
              ),
            ),

          // 6. طبقة التغبيش والتحميل لحين اكتمال تجهيز الخريطة ومواقع المحامين (مطابقة لخريطة محاميك حالاً)
          if (_isInitialLoading)
            Positioned.fill(
              child: Container(
                    color: Colors.white.withOpacity(0.78),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Lottie.asset(
                          'assets/images/splash_gif.json',
                          width: 80,
                          height: 80,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'جاري تجهيز الخريطة وعرض أقرب المحامين',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'AppFont',
                            fontFamilyFallback: appFontFallback,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.dark,
                          ),
                        ),
                      ],
                    ),
                  ),
            ),
        ],
      ),
    ),
    );
  }

  Widget _buildUserLocationMarker() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.4),
            blurRadius: 10,
            spreadRadius: 3,
          ),
        ],
      ),
      child: const Center(
        child: Icon(Icons.person_pin_circle_rounded, color: Colors.white, size: 16),
      ),
    );
  }

  Widget _buildMapFloatingBtn({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.white,
      elevation: 3,
      shadowColor: Colors.black.withOpacity(0.12),
      borderRadius: BorderRadius.circular(7.0),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(7.0),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }
}

/// دبوس المحامي المربع الاحترافي على الخريطة الترويجية (مطابق لـ TrackingScreen لمنع أي Overflow)
class _ShowcaseLawyerPin extends StatelessWidget {
  final MapLawyer lawyer;
  final bool isSelected;
  final bool isNearest;

  const _ShowcaseLawyerPin({
    required this.lawyer,
    required this.isSelected,
    this.isNearest = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color badgeBg = isSelected ? AppColors.dark : Colors.white;
    final Color borderColor = isSelected ? AppColors.primary : Colors.transparent;
    final double borderWidth = isSelected ? 2.0 : 0.0;

    return CustomPaint(
      painter: _ShowcaseBubblePainter(
        color: badgeBg,
        borderColor: borderColor,
        borderWidth: borderWidth,
        hasBorder: isSelected,
        isSelected: isSelected,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ShowcaseAvatarPhoto(
              imageUrl: lawyer.imageUrl,
              initials: lawyer.avatarInitials,
              fallbackColor: lawyer.avatarColor,
              size: 28,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          lawyer.name,
                          style: TextStyle(
                            fontFamily: 'AppFont',
                            fontFamilyFallback: appFontFallback,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? Colors.white : AppColors.dark,
                          ),
                          maxLines: 1,
                        ),
                      ),
                      if (isNearest) ...[
                        const SizedBox(width: 4),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded, size: 12, color: Color(0xFFEAB308)),
                      const SizedBox(width: 2),
                      Text(
                        lawyer.rating.toString(),
                        style: TextStyle(
                          fontFamily: 'AppFont',
                          fontFamilyFallback: appFontFallback,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.white70 : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// رسام فيكتور لعلامة المحامي مع السهم والظلال الناعمة
class _ShowcaseBubblePainter extends CustomPainter {
  final Color color;
  final Color borderColor;
  final double borderWidth;
  final bool hasBorder;
  final bool isSelected;

  _ShowcaseBubblePainter({
    required this.color,
    required this.borderColor,
    this.borderWidth = 1.2,
    this.hasBorder = true,
    this.isSelected = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double notchHeight = 5.0;
    const double notchWidth = 10.0;
    final double cardBottom = size.height - notchHeight;
    final double midX = size.width / 2;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, cardBottom),
      const Radius.circular(7.0),
    );

    final path = Path()
      ..addRRect(rrect)
      ..moveTo(midX - (notchWidth / 2), cardBottom)
      ..lineTo(midX, size.height)
      ..lineTo(midX + (notchWidth / 2), cardBottom)
      ..close();

    canvas.drawShadow(
      path,
      Colors.black.withOpacity(isSelected ? 0.28 : 0.16),
      isSelected ? 5.0 : 3.5,
      false,
    );

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    if (hasBorder && borderWidth > 0) {
      final strokePaint = Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ShowcaseBubblePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.borderWidth != borderWidth ||
        oldDelegate.hasBorder != hasBorder ||
        oldDelegate.isSelected != isSelected;
  }
}

/// صورة المحامي الدائرية/المربعة بحواف 7.0px مع معالجة التحميل والأخطاء بدون تمدد أو overflow
class _ShowcaseAvatarPhoto extends StatelessWidget {
  final String imageUrl;
  final String initials;
  final Color fallbackColor;
  final double size;

  const _ShowcaseAvatarPhoto({
    required this.imageUrl,
    required this.initials,
    required this.fallbackColor,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fallbackColor,
        borderRadius: BorderRadius.circular(7.0),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl.isNotEmpty
          ? Image.network(
              imageUrl,
              width: size,
              height: size,
              cacheWidth: (size * 2).toInt(),
              cacheHeight: (size * 2).toInt(),
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return _buildFallback();
              },
              errorBuilder: (context, error, stackTrace) {
                return _buildFallback();
              },
            )
          : _buildFallback(),
    );
  }

  Widget _buildFallback() {
    return Center(
      child: Text(
        initials,
        style: TextStyle(
          fontFamily: 'AppFont',
          fontFamilyFallback: appFontFallback,
          fontSize: size * 0.38,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// شريط خط فاصل منقط أنيق
class _ShowcaseDashedLineSeparator extends StatelessWidget {
  const _ShowcaseDashedLineSeparator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const dashWidth = 4.0;
          const dashGap = 4.0;
          final count = (constraints.maxWidth / (dashWidth + dashGap)).floor();
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(count, (_) {
              return Container(
                width: dashWidth,
                height: 1.2,
                color: AppColors.cardBorder,
              );
            }),
          );
        },
      ),
    );
  }
}
