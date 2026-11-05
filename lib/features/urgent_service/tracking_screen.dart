import '../../core/widgets/line_illustration.dart';
import 'dart:async';
import 'dart:math' as math;
import '../../core/widgets/app_pressable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:lottie/lottie.dart' hide Marker;
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/services/app_visibility.dart';
import '../../core/services/geo_naming_service.dart';
import '../../core/services/location_service.dart';
import '../../core/services/map_lawyer_loader.dart';
import '../../core/services/routing_service.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_header.dart';
import '../../core/widgets/app_map_layer.dart';
import '../../core/widgets/app_state_message.dart';
import '../../core/widgets/lawyer_profile_summary.dart';
import '../../core/widgets/lawyer_reviews_panel.dart';
import '../../core/widgets/map_cards.dart';
import '../../core/widgets/measured_size.dart';
import '../../core/widgets/response_countdown.dart';
import '../../core/widgets/sheet_lines.dart';
import '../../data/models/map_lawyer.dart';
import '../../data/repositories/lawyer_repository.dart';
import '../../data/repositories/order_repository.dart';
import 'payment_screen.dart';
import 'lawyer_google_profile_screen.dart';

part 'tracking_screen_widgets.dart';
part 'tracking_screen_views.dart';
part 'tracking_screen_order_flow.dart';
part 'tracking_screen_map.dart';

class TrackingScreen extends StatefulWidget {
  final String? problemTitle;
  final String? problemDescription;

  const TrackingScreen({
    super.key,
    this.problemTitle,
    this.problemDescription,
  });

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

enum _OrderFlowStage {
  idle,
  waitingAcceptance,
  lawyerAccepted,
  evaluatingPrice,
  priceApproval,
  priceReady,
  lawyerDeclined,
}

class _TrackingScreenState extends State<TrackingScreen> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  final RoutingService _routingService = RoutingService();

  Position? _currentPosition;
  String _locationName = 'جاري تحديد موقعك';
  bool _isLoading = true;
  bool _isInitialLoading = true;

  static const double _cardWidth = 195.0;
  static const double _cardHeight = 53.0;
  static const double _allEgyptRadiusKm = 1500.0;
  String? _lawyersError;

  /// الشيت المقفول يظهر منه العنوان فقط
  double get _collapsedHeight => 56.0 + MediaQuery.viewPaddingOf(context).bottom;

  /// طول الشيت هو طول محتواه على أي موبايل
  double? _sheetContentHeight;
  double get _expandedHeight {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;
    return (_sheetContentHeight ?? 390.0).clamp(_collapsedHeight, maxHeight);
  }

  void _onSheetContentSized(Size size) {
    if (!mounted || (size.height - (_sheetContentHeight ?? 0)).abs() < 1) return;
    final isOpen = _sheetHeight > _collapsedHeight + 1;
    _sheetContentHeight = size.height;
    if (isOpen) _snapSheetTo(_expandedHeight, moveCamera: false);
  }
  // ارتفاع البوتن شيت منفصل عن حالة الشاشة: سحبه لا يعيد بناء الخريطة مع كل إطار
  final ValueNotifier<double> _sheetHeightNotifier = ValueNotifier<double>(390.0);
  double get _sheetHeight => _sheetHeightNotifier.value;
  set _sheetHeight(double value) => _sheetHeightNotifier.value = value;

  bool _initializedSheetHeight = false;
  late AnimationController _sheetAnimController;
  late CurvedAnimation _sheetCurve;
  Tween<double> _sheetTween = Tween<double>(begin: 390.0, end: 390.0);
  AnimationController? _cameraAnimController;
  _OrderFlowStage _orderFlowStage = _OrderFlowStage.idle;

  int _currentLawyerIndex = 0;
  List<MapLawyer> _nearbyLawyers = [];
  MapLawyer? _selectedLawyer;
  List<LatLng> _routePoints = [];
  RouteEstimate? _routeEstimate;
  Timer? _orderPollTimer;
  Timer? _stageTimer;
  String? _activeOrderId;
  String? _activeOrderNumber;

  int _servicePrice = 0;
  int _orderSecondsLeft = 120;
  String _declineTitle = 'اعتذر المحامي';
  bool _showReviews = false;
  bool _isSearchingAgain = false;
  Timer? _lawyersRefreshTimer;
  double _mapZoom = appMapMaxZoom;
  MapCamera? _lastCamera;
  late final MapLawyerLoader _mapLawyers = MapLawyerLoader(onChanged: () {
    if (mounted) setState(() {});
  });

  /// المحامون اللي الطلب اتبعتلهم ولا ردوا، عشان البحث التلقائي ما يرجعلهمش
  final Set<String> _triedLawyerIds = {};

  @override
  void initState() {
    super.initState();
    _sheetAnimController = AnimationController(
      duration: const Duration(milliseconds: 320),
      vsync: this,
    );
    _sheetCurve = CurvedAnimation(parent: _sheetAnimController, curve: Curves.easeOutCubic);
    _sheetAnimController.addListener(() {
      _sheetHeight = _sheetTween.evaluate(_sheetCurve);
    });
    _fetchCurrentLocation();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedSheetHeight) {
      _sheetHeight = _expandedHeight;
      _initializedSheetHeight = true;
    }
  }

  @override
  void dispose() {
    _orderPollTimer?.cancel();
    _lawyersRefreshTimer?.cancel();
    _mapLawyers.dispose();
    _stageTimer?.cancel();
    _cameraAnimController?.dispose();
    _sheetCurve.dispose();
    _sheetAnimController.dispose();
    _sheetHeightNotifier.dispose();
    super.dispose();
  }

  /// الشيت والكاميرا يتحركوا مع بعض مرة واحدة، و[moveCamera] يتقفل لو الكاميرا اتحركت فعلاً


  void _update(VoidCallback change) => setState(change);

  @override
  Widget build(BuildContext context) {
    final LatLng currentLatLng = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : const LatLng(30.0444, 31.2357);

    // الرجوع أثناء مراحل الطلب يعود لملف المحامي أولاً قبل مغادرة الخريطة
    return PopScope(
      canPop: _orderFlowStage == _OrderFlowStage.idle,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _returnToLawyerProfile();
      },
      child: Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppHeader(title: 'محاميك حالاً', isInnerPage: true),
      body: Stack(
        children: [
          // 1. خريطة تفاعلية مستضافة على السيرفر
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: currentLatLng,
              initialZoom: appMapMaxZoom,
              minZoom: appMapMinZoom,
              maxZoom: appMapMaxZoom,
              cameraConstraint: appMapBounds,
              backgroundColor: appMapBackground,
              onMapReady: () => _lastCamera = _mapController.camera,
              onPositionChanged: _onMapMoved,
              onPointerDown: (_, __) => _stopCamera(),
            ),
            children: [
              const AppMapLayer(),

              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 3.2,
                      color: AppColors.primary,
                      pattern: StrokePattern.dashed(segments: const [8, 5]),
                      borderStrokeWidth: 1.0,
                      borderColor: Colors.white,
                    ),
                  ],
                ),

              MarkerLayer(
                markers: [
                  if (!_isLawyerAtClientSpot)
                    Marker(
                      point: currentLatLng,
                      width: _cardWidth * mapCardScaleFor(_mapZoom),
                      height: _cardHeight * mapCardScaleFor(_mapZoom),
                      alignment: Alignment.topCenter,
                      child: const ScaledMapCard(
                        width: _cardWidth,
                        height: _cardHeight,
                        child: MyLocationMapCard(),
                      ),
                    ),

                  ..._buildLawyerMarkers(_mapZoom),
                ],
              ),

              const Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: EdgeInsets.all(4),
                  child: Text(
                    '© OpenStreetMap',
                    textDirection: TextDirection.ltr,
                    style: TextStyle(fontSize: 9, color: AppColors.textMuted),
                  ),
                ),
              ),
            ],
          ),

          // 2. طبقة التغبيش والتحميل لحين تجميع الخريطة ورسم المسار الأول (تظهر فوق البوتن شيت بوضوح دون أن يحجبها)
          if (_isInitialLoading)
            ValueListenableBuilder<double>(
              valueListenable: _sheetHeightNotifier,
              builder: (context, sheetHeight, child) => Positioned(
                top: 0,
                left: 0,
                right: 0,
                bottom: sheetHeight,
                child: child!,
              ),
              child: Container(
                    color: Colors.white.withOpacity(0.78),
                    alignment: Alignment.center,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
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
                              'جاري تجهيز الخريطة ومسار أقرب محامٍ',
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
                  ),
            ),



          // 4. أزرار التحكم بالخريطة (موجودة فوق البوتن شيت وتتحرك معه بنعومة)
          ValueListenableBuilder<double>(
            valueListenable: _sheetHeightNotifier,
            builder: (context, sheetHeight, child) => Positioned(
              right: 16,
              bottom: sheetHeight + 14.0,
              child: child!,
            ),
            child: Column(
              children: [
                _buildMapControlBtn(
                  icon: Icons.my_location_rounded,
                  color: AppColors.primary,
                  onPressed: _centerMapOnCurrentPosition,
                ),
                const SizedBox(height: 6),
                _buildMapControlBtn(
                  icon: Icons.add,
                  color: AppColors.dark,
                  onPressed: () {
                    _animatedMapMove(_mapController.camera.center, _mapController.camera.zoom + 1);
                  },
                ),
                const SizedBox(height: 6),
                _buildMapControlBtn(
                  icon: Icons.remove,
                  color: AppColors.dark,
                  onPressed: () {
                    _animatedMapMove(_mapController.camera.center, _mapController.camera.zoom - 1);
                  },
                ),
              ],
            ),
          ),

          // 5. بوتن شيت واحد فقط مثبت تلقائياً أسفل الخريطة بارتفاع ثابت وسحب مباشر للأعلى والأسفل بحواف 28px
          ValueListenableBuilder<double>(
            valueListenable: _sheetHeightNotifier,
            child: _buildSheetHeader(),
            builder: (context, sheetHeight, sheetHeader) => Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: sheetHeight,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28.0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 20,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const SheetLines(top: 62),
                    OverflowBox(
                      alignment: Alignment.topCenter,
                      minHeight: 0,
                      maxHeight: double.infinity,
                      child: MeasuredSize(
                        onChange: _onSheetContentSized,
                        child: SafeArea(
                          top: false,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              sheetHeader!,
                              Padding(
                                padding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
                                child: _showReviews && _selectedLawyer != null
                                    ? SizedBox(
                                        height: MediaQuery.sizeOf(context).height * 0.6,
                                        child: LawyerReviewsPanel(
                                          lawyerId: _selectedLawyer!.id,
                                          onClose: () => _setReviewsVisible(false),
                                        ),
                                      )
                                    : _orderFlowStage != _OrderFlowStage.idle
                                        ? _buildOrderFlowContent()
                                        : _buildLawyerProfileCard(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  /// شريط العنوان ومؤشر السحب: قابل للسحب المباشر والنقر للتوسيع أو الإغلاق
  Widget _buildSheetHeader() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: (details) {
        _sheetHeight = (_sheetHeight - details.delta.dy).clamp(_collapsedHeight, _expandedHeight);
      },
      onVerticalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity < -250) {
          _snapSheetTo(_expandedHeight);
        } else if (velocity > 250) {
          _snapSheetTo(_collapsedHeight);
        } else {
          final mid = (_collapsedHeight + _expandedHeight) / 2;
          _snapSheetTo(_sheetHeight >= mid ? _expandedHeight : _collapsedHeight);
        }
      },
      onTap: () {
        final mid = (_collapsedHeight + _expandedHeight) / 2;
        _snapSheetTo(_sheetHeight < mid ? _expandedHeight : _collapsedHeight);
      },
      child: Container(
        padding: const EdgeInsets.only(top: 10, bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // مؤشر السحب العلوي
            Container(
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: AppColors.cardBorder,
                borderRadius: BorderRadius.circular(4.0),
              ),
            ),
            const SizedBox(height: 10),
            // عنوان البوتن شيت في المنتصف تماماً كنص فقط بدون أيقونة وبدون زر تصغير
            Center(
              child: Text(
                _showReviews
                    ? 'التقييمات'
                    : _orderFlowStage == _OrderFlowStage.idle
                        ? 'أقرب المحامين إليك'
                        : 'متابعة الطلب',
                style: const TextStyle(
                  fontFamily: 'AppFont',
                  fontFamilyFallback: appFontFallback,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.dark,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0),
              child: _DashedLineSeparator(),
            ),
          ],
        ),
      ),
    );
  }
}
