import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../../core/constants/app_colors.dart';
import '../../core/services/geo_naming_service.dart';
import '../../core/services/location_service.dart';
import '../../core/services/map_lawyer_loader.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_sheet.dart';
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
import '../lawyer/lawyer_navigation_shell.dart';
import '../auth/session_router.dart';

part 'nearby_lawyers_showcase_widgets.dart';
part 'nearby_lawyers_showcase_sheet.dart';

/// الخريطة الترويجية: تظهر للموكل كل مرة يدخل فيها التطبيق، وزر الإغلاق فوق يوديه للرئيسية.
/// البوتن شيت ثابت ويعرض أعلى المحامين تقييماً في نطاق 50 كم، وملف المحامي يفتح جواه بنفس الحجم.
/// الخريطة للعرض بس، ومفيش منها أي طلب خدمة.
const double _showcaseRadiusKm = 50;
/// أول تقدير لطول الشيت قبل ما يتقاس محتواه
const double _showcaseSheetHeight = 360;

class NearbyLawyersShowcaseScreen extends StatefulWidget {
  /// المحامي برضه بيشوف الخريطة، وزرار الإغلاق بيوديه لصفحاته
  final bool forLawyer;

  const NearbyLawyersShowcaseScreen({super.key, this.forLawyer = false});

  @override
  State<NearbyLawyersShowcaseScreen> createState() => _NearbyLawyersShowcaseScreenState();
}

class _NearbyLawyersShowcaseScreenState extends State<NearbyLawyersShowcaseScreen>
    with TickerProviderStateMixin {
  double _mapZoom = 14.5;
  double _sheetHeight = _showcaseSheetHeight;
  MapCamera? _lastCamera;
  final MapController _mapController = MapController();
  AnimationController? _cameraAnimController;

  Position? _currentPosition;
  String _locationName = 'جاري تحديد موقعك';
  bool _isInitialLoading = true;

  List<MapLawyer> _nearbyLawyers = [];
  MapLawyer? _selectedLawyer;
  bool _showReviews = false;
  late final MapLawyerLoader _mapLawyers = MapLawyerLoader(onChanged: () {
    if (mounted) setState(() {});
  });

  @override
  void initState() {
    super.initState();
    _fetchCurrentLocation();
  }

  @override
  void dispose() {
    _cameraAnimController?.stop();
    _cameraAnimController?.dispose();
    _mapLawyers.dispose();
    super.dispose();
  }

  Future<void> _fetchCurrentLocation() async {
    Position? position;
    try {
      final result = await LocationService.instance.checkAndRequestPermission().timeout(
        const Duration(seconds: 4),
        onTimeout: () => const LocationResult(
          status: LocationServiceStatus.error,
          errorMessage: 'تحديد الموقع أخد وقت طويل، حاول تاني',
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

    final res = await LawyerRepository.getNearbyLawyers(lat: center.latitude, lon: center.longitude, radiusKm: _showcaseRadiusKm, byRating: true);
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
    final camera = _lastCamera;
    if (camera != null) _mapLawyers.load(camera);
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
    SessionRouter.replaceStack(
      Navigator.of(context),
      widget.forLawyer ? const LawyerNavigationShell() : const MainNavigationShell(),
    );
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
              onMapReady: () => _lastCamera = _mapController.camera,
              onPositionChanged: (camera, _) {
                _lastCamera = camera;
                if (camera.zoom.floor() != _mapZoom.floor()) {
                  setState(() => _mapZoom = camera.zoom);
                }
                if (!_isInitialLoading) _mapLawyers.cameraMoved(camera);
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

                  ..._buildLawyerMarkers(),
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
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
          ),

          // 3. أزرار التحكم بالخريطة (تكبير / تصغير / إعادة التمركز)
          Positioned(
            right: 16,
            bottom: _sheetHeight + 12,
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

        ],
      ),
    ),
    );
  }

  /// قائمة أعلى المحامين تقييماً ومحامو المنطقة الظاهرة، وكل محامٍ بكارته
  List<Marker> _buildLawyerMarkers() {
    final scale = mapCardScaleFor(_mapZoom);
    final shown = {for (final lawyer in _nearbyLawyers) lawyer.id: lawyer};
    for (final lawyer in _mapLawyers.lawyers) {
      shown.putIfAbsent(lawyer.id, () => lawyer);
    }

    return [
      for (final lawyer in shown.values)
        Marker(
          point: lawyer.position,
          width: 140 * scale,
          height: 52 * scale,
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
    ];
  }

  void _update(VoidCallback change) => setState(change);
}
