import '../../core/widgets/line_illustration.dart';
import 'dart:async';
import 'dart:math' as math;
import '../../core/widgets/app_pressable.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../../core/constants/app_colors.dart';
import '../../core/services/app_visibility.dart';
import '../../core/services/geo_naming_service.dart';
import '../../core/services/live_updates.dart';
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
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/app_switcher.dart';
import '../../data/models/map_lawyer.dart';
import '../../data/repositories/lawyer_repository.dart';
import '../../data/models/service_request.dart';
import '../../data/repositories/order_repository.dart';
import '../../data/repositories/request_repository.dart';
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
  evaluatingPrice,
  priceApproval,
  waitingOffers,
  priceReady,
}

class _TrackingScreenState extends State<TrackingScreen> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  final RoutingService _routingService = RoutingService();

  Position? _currentPosition;
  String _locationName = 'جاري تحديد موقعك';
  bool _isLoading = true;

  static const double _cardWidth = 195.0;
  static const double _cardHeight = 53.0;
  static const double _allEgyptRadiusKm = 1500.0;
  String? _lawyersError;

  /// الشيت طوله ثابت طول الوقت، ومحتواه بيتمرر جواه
  double get _expandedHeight {
    final screen = MediaQuery.sizeOf(context).height;
    return (screen * 0.48).clamp(360.0, screen * 0.6);
  }

  // ارتفاع البوتن شيت منفصل عن حالة الشاشة: سحبه لا يعيد بناء الخريطة مع كل إطار
  final ValueNotifier<double> _sheetHeightNotifier = ValueNotifier<double>(390.0);
  double get _sheetHeight => _sheetHeightNotifier.value;
  set _sheetHeight(double value) => _sheetHeightNotifier.value = value;

  AnimationController? _cameraAnimController;
  _OrderFlowStage _orderFlowStage = _OrderFlowStage.idle;

  int _currentLawyerIndex = 0;
  List<MapLawyer> _nearbyLawyers = [];
  MapLawyer? _selectedLawyer;
  List<LatLng> _routePoints = [];
  RouteEstimate? _routeEstimate;
  Timer? _orderPollTimer;
  Timer? _roundEndTimer;
  Timer? _stageTimer;
  String? _activeOrderId;
  String? _activeOrderNumber;

  int _servicePrice = 0;
  int _minPrice = 0;
  int _maxPrice = 0;
  String? _activeRequestId;
  ClientRequest? _activeRequest;
  String? _reviewsLawyerId;
  bool _isChoosingOffer = false;
  bool _isSearchingAgain = false;
  bool _noOffers = false;
  String? _followedRequestId;
  bool _isCheckingRequest = false;
  bool _showReviews = false;
  /// الموكل لمس كارت محامي وبيتفرج على ملفه
  bool _isViewingLawyer = false;
  Timer? _lawyersRefreshTimer;
  double _mapZoom = appMapMaxZoom;
  MapCamera? _lastCamera;
  late final MapLawyerLoader _mapLawyers = MapLawyerLoader(onChanged: () {
    if (mounted) setState(() {});
  });

  @override
  void initState() {
    super.initState();
    _fetchCurrentLocation();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sheetHeight = _expandedHeight;
  }

  @override
  void dispose() {
    _orderPollTimer?.cancel();
    _roundEndTimer?.cancel();
    _followedRequestId = null;
    LiveUpdates.changes.removeListener(_checkRequest);
    _lawyersRefreshTimer?.cancel();
    _mapLawyers.dispose();
    _stageTimer?.cancel();
    _cameraAnimController?.dispose();
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
          // 5. البوتن شيت طوله على قد محتواه، وأزرار الخريطة بتتحرك معاه
          Align(
            alignment: Alignment.bottomCenter,
            child: MeasuredSize(
              onChange: (size) => _sheetHeight = size.height,
              child: Container(
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
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppSheetHeader(
                        title: _showReviews
                            ? 'التقييمات'
                            : _isViewingLawyer
                                ? 'ملف المحامي'
                                : _orderFlowStage != _OrderFlowStage.idle
                                    ? 'متابعة الطلب'
                                    : 'المحامين القريبين منك',
                        onBack: _showReviews
                            ? () => _setReviewsVisible(false)
                            : _isViewingLawyer
                                ? _closeLawyerProfile
                                : null,
                      ),
                      ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.65),
                        child: _showReviews && (_reviewsLawyerId ?? _selectedLawyer?.id) != null
                            ? SizedBox(
                                height: MediaQuery.sizeOf(context).height * 0.55,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
                                  child: LawyerReviewsPanel(
                                    lawyerId: (_reviewsLawyerId ?? _selectedLawyer?.id)!,
                                    onClose: () => _setReviewsVisible(false),
                                  ),
                                ),
                              )
                            : SingleChildScrollView(
                                padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                                child: _orderFlowStage != _OrderFlowStage.idle && !_isViewingLawyer
                                    ? _buildOrderFlowContent()
                                    : _buildLawyerProfileCard(),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}
