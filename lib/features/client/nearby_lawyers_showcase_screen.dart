import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:lottie/lottie.dart' hide Marker;
import '../../core/constants/app_colors.dart';
import '../../core/services/geo_naming_service.dart';
import '../../core/services/location_service.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_state_message.dart';
import '../../core/widgets/app_map_layer.dart';
import '../../core/widgets/lawyer_profile_summary.dart';
import '../../core/widgets/lawyer_reviews_panel.dart';
import '../../core/widgets/map_cards.dart';
import '../../core/widgets/line_illustration.dart';
import '../../data/models/map_lawyer.dart';
import '../../data/repositories/lawyer_repository.dart';
import '../urgent_service/lawyer_google_profile_screen.dart';
import 'main_navigation_shell.dart';
import '../auth/session_router.dart';

part 'nearby_lawyers_showcase_widgets.dart';

/// الخريطة الترويجية: تظهر للموكل كل مرة يدخل فيها التطبيق، وزر الإغلاق فوق يوديه للرئيسية.
/// البوتن شيت ثابت ويعرض أعلى المحامين تقييماً في نطاق 50 كم، وملف المحامي يفتح جواه بنفس الحجم.
/// الخريطة للعرض بس، ومفيش منها أي طلب خدمة.
const double _showcaseRadiusKm = 50;
const double _showcaseSheetHeight = 360;

class NearbyLawyersShowcaseScreen extends StatefulWidget {
  const NearbyLawyersShowcaseScreen({super.key});

  @override
  State<NearbyLawyersShowcaseScreen> createState() => _NearbyLawyersShowcaseScreenState();
}

class _NearbyLawyersShowcaseScreenState extends State<NearbyLawyersShowcaseScreen>
    with TickerProviderStateMixin {
  double _mapZoom = 14.5;
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
          errorMessage: 'تحديد الموقع أخد وقت طويل، حاول تاني.',
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

    final res = await LawyerRepository.getNearbyLawyers(lat: center.latitude, lon: center.longitude, radiusKm: _showcaseRadiusKm);
    if (!mounted) return;

    setState(() {
      _currentPosition = position;
      _locationName = locationName;
      _nearbyLawyers = (res.data ?? const []).map(MapLawyer.fromModel).toList()
        ..sort((a, b) {
          final byRating = b.rating.compareTo(a.rating);
          return byRating != 0 ? byRating : a.distanceMeters.compareTo(b.distanceMeters);
        });
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
    final zoomTween = Tween<double>(begin: camera.zoom, end: destZoom.clamp(appMapMinZoom, appMapMaxZoom));

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
    const double targetZoom = appMapMaxZoom;
    const double latShift = 0.0042;
    final targetCenter = LatLng(lawyer.position.latitude - latShift, lawyer.position.longitude);

    _animatedMapMove(targetCenter, targetZoom);
  }

  void _closeLawyerProfile() {
    setState(() {
      _selectedLawyer = null;
      _showReviews = false;
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
              minZoom: appMapMinZoom,
              maxZoom: appMapMaxZoom,
              cameraConstraint: appMapBounds,
              onPositionChanged: (camera, _) {
                if (camera.zoom.floor() != _mapZoom.floor()) {
                  setState(() => _mapZoom = camera.zoom);
                }
              },
              backgroundColor: appMapBackground,
              onTap: (_, __) {
                if (_selectedLawyer != null) {
                  _closeLawyerProfile();
                }
              },
            ),
            children: [
              const AppMapLayer(),

              // علامات المحامين وعلامة المستخدم
              MarkerLayer(
                markers: [
                  // نقطة موقع المستخدم
                  Marker(
                    point: centerLatLng,
                    width: 140 * mapCardScaleFor(_mapZoom),
                    height: 52 * mapCardScaleFor(_mapZoom),
                    alignment: Alignment.topCenter,
                    child: const ScaledMapCard(width: 140, height: 52, child: MyLocationMapCard()),
                  ),

                  // علامات المحامين القريبين (بأبعاد متناسقة 140x52 لمنع الـ Overflow نهائياً)
                  for (final lawyer in _nearbyLawyers)
                    Marker(
                      point: lawyer.position,
                      width: 140 * mapCardScaleFor(_mapZoom),
                      height: 52 * mapCardScaleFor(_mapZoom),
                      alignment: Alignment.topCenter,
                      child: GestureDetector(
                        onTap: () => _onLawyerMarkerTapped(lawyer),
                        child: ScaledMapCard(
                          width: 140,
                          height: 52,
                          child: _ShowcaseLawyerPin(
                            lawyer: lawyer,
                            isSelected: _selectedLawyer?.id == lawyer.id,
                            isNearest: false,
                          ),
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
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                child: Row(
                  children: [
                    const SizedBox(width: 44),
                    Expanded(
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
                    Material(
                      color: Colors.white,
                      elevation: 3,
                      shadowColor: Colors.black.withOpacity(0.12),
                      shape: const CircleBorder(),
                      child: IconButton(
                        icon: const Icon(Icons.close_rounded, color: AppColors.dark),
                        tooltip: 'إغلاق',
                        onPressed: _proceedToMainApp,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. أزرار التحكم بالخريطة (تكبير / تصغير / إعادة التمركز)
          Positioned(
            right: 16,
            bottom: _showcaseSheetHeight + MediaQuery.paddingOf(context).bottom + 12,
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

          // 4. البوتن شيت الثابت
          _buildFixedSheet(),

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

  Widget _buildFixedSheet() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: double.infinity,
        height: _showcaseSheetHeight + MediaQuery.paddingOf(context).bottom,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28.0)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 24, offset: const Offset(0, -6)),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSheetTitle(),
              const _ShowcaseDashedLineSeparator(),
              Expanded(
                child: _selectedLawyer == null ? _buildTopLawyersList() : _buildLawyerProfile(_selectedLawyer!),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSheetTitle() {
    final hasLawyer = _selectedLawyer != null;
    return SizedBox(
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            hasLawyer ? 'ملف المحامي' : 'الأعلى تقييماً حولك',
            style: const TextStyle(
              fontFamily: 'AppFont',
              fontFamilyFallback: appFontFallback,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: AppColors.dark,
            ),
          ),
          if (hasLawyer)
            PositionedDirectional(
              start: 6,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: AppColors.dark),
                tooltip: 'رجوع',
                onPressed: _closeLawyerProfile,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopLawyersList() {
    if (_nearbyLawyers.isEmpty) {
      return const SingleChildScrollView(
        child: AppStateMessage(icon: Icons.location_on_rounded, title: 'لا يوجد محامون في نطاق 50 كم حالياً'),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      physics: const BouncingScrollPhysics(),
      itemCount: _nearbyLawyers.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final lawyer = _nearbyLawyers[index];
        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(7.0),
          child: InkWell(
            borderRadius: BorderRadius.circular(7.0),
            onTap: () => _onLawyerMarkerTapped(lawyer),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(7.0),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Row(
                children: [
                  _ShowcaseAvatarPhoto(
                    imageUrl: lawyer.imageUrl,
                    initials: lawyer.avatarInitials,
                    fallbackColor: lawyer.avatarColor,
                    size: 46,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lawyer.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                          '${lawyer.experienceYears} سنوات خبرة • ${_distanceText(lawyer)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'AppFont',
                            fontFamilyFallback: appFontFallback,
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.star_rounded, color: Color(0xFFEAB308), size: 18),
                  const SizedBox(width: 3),
                  Text(
                    lawyer.rating.toStringAsFixed(1),
                    style: const TextStyle(
                      fontFamily: 'AppFont',
                      fontFamilyFallback: appFontFallback,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.dark,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _distanceText(MapLawyer lawyer) {
    final meters = lawyer.distanceMeters;
    return meters < 1000 ? '${meters.round()} م' : '${(meters / 1000).toStringAsFixed(1)} كم';
  }

  Widget _buildLawyerProfile(MapLawyer lawyer) {
    if (_showReviews) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
        child: LawyerReviewsPanel(lawyerId: lawyer.id, onClose: () => setState(() => _showReviews = false)),
      );
    }
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LawyerProfileSummary(
            avatar: _ShowcaseAvatarPhoto(
              imageUrl: lawyer.imageUrl,
              initials: lawyer.avatarInitials,
              fallbackColor: lawyer.avatarColor,
              size: 56,
            ),
            name: lawyer.name,
            title: lawyer.title,
            rating: lawyer.rating,
            reviewsCount: lawyer.reviewsCount,
            experienceYears: lawyer.experienceYears,
            distanceText: _distanceText(lawyer),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: AppButton.outlined(
                  text: 'ملف Google',
                  customIcon: const GoogleMark(),
                  onPressed: _openGoogleProfile,
                  height: 44,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton.outlined(
                  text: 'التقييمات (${lawyer.reviewsCount})',
                  onPressed: () => setState(() => _showReviews = true),
                  height: 44,
                ),
              ),
            ],
          ),
        ],
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
