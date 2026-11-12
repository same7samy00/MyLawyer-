import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../../core/constants/app_colors.dart';
import '../../core/constants/rating_rules.dart';
import '../../core/services/app_visibility.dart';
import '../../core/services/geo_naming_service.dart';
import '../../core/services/live_updates.dart';
import '../../core/services/location_service.dart';
import '../../core/services/map_lawyer_loader.dart';
import '../../core/services/routing_service.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/app_header.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/app_map_layer.dart';
import '../../core/widgets/app_message.dart';
import '../../core/widgets/app_pressable.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/app_state_message.dart';
import '../../core/widgets/app_switcher.dart';
import '../../core/widgets/lawyer_map_layers.dart';
import '../../core/widgets/lawyer_profile_summary.dart';
import '../../core/widgets/lawyer_reviews_panel.dart';
import '../../core/widgets/line_illustration.dart';
import '../../core/widgets/map_cards.dart';
import '../../data/models/field_info.dart';
import '../../data/models/map_lawyer.dart';
import '../../data/models/service_request.dart';
import '../../data/repositories/field_repository.dart';
import '../../data/repositories/order_repository.dart';
import '../../data/repositories/request_repository.dart';
import '../client/legal_services.dart';
import 'lawyer_google_profile_screen.dart';
import 'payment_screen.dart';

part 'tracking_screen_map.dart';
part 'tracking_screen_order_flow.dart';
part 'tracking_screen_views.dart';
part 'tracking_screen_widgets.dart';

class TrackingScreen extends StatefulWidget {
  final String? problemTitle;
  final String? problemDescription;

  /// طلب مفتوح من صفحة الطلبات: الشاشة بتفتح على عروضه على طول
  final String? resumeRequestId;

  /// طلب ميداني (محضر، نيابة...): المحامين بيتدوّر عليهم حوالين المكان مش حوالين الموكل
  final FieldDraft? field;

  const TrackingScreen({
    super.key,
    this.problemTitle,
    this.problemDescription,
    this.resumeRequestId,
    this.field,
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
  /// قايمة «المحامين القريبين منك» بحد أقصى العدد ده
  static const int _nearbyCount = 100;

  /// قايمة القريبين بتظهر 20 بس، و«المزيد» بيزوّد 20
  String? _lawyersError;

  /// الشيت طوله ثابت طول الوقت، ومحتواه بيتمرر جواه
  double get _expandedHeight {
    final screen = MediaQuery.sizeOf(context).height;
    // طول ما فيه خريطة، الشيت ما يعديش نص الشاشة
    return math.min(screen * 0.5, math.max(screen * 0.42, 320.0));
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
  /// الطلب اللي الموكل اختار منه العرض، عشان يرجعله لو المحامي اتشغل قبل الدفع
  String? _chosenFromRequestId;
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
  double _mapZoom = appMapStartZoom;
  /// محامين الخريطة من المربعات الجاهزة، وقايمة «القريبين منك» بتتحسب منهم على الموبايل
  late final MapLawyerLoader _mapLawyers = MapLawyerLoader(onChanged: () {
    if (mounted) setState(_refreshNearby);
  },);

  @override
  void initState() {
    super.initState();
    _fetchCurrentLocation();
    RequestRepository.backToOffers.addListener(_resumeOffers);
    final resume = widget.resumeRequestId;
    if (resume != null) {
      _chosenFromRequestId = resume;
      WidgetsBinding.instance.addPostFrameCallback((_) => _resumeOffers());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sheetHeight = _expandedHeight;
  }

  @override
  void dispose() {
    RequestRepository.backToOffers.removeListener(_resumeOffers);
    _orderPollTimer?.cancel();
    _roundEndTimer?.cancel();
    _followedRequestId = null;
    LiveUpdates.changes.removeListener(_checkRequest);
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
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        // زي التطبيقات الكبيرة: الخروج اللي بيلغي حاجة بيتأكد الأول، ويقول بالظبط هيلغي إيه.
        // زرار النص أو قفل الشاشة ما بيلغوش حاجة: النداءات بتكمل والإشعارات بتوصل
        final searching = _orderFlowStage == _OrderFlowStage.waitingOffers;
        final chosen = _orderFlowStage == _OrderFlowStage.priceReady;
        if (searching || chosen) {
          final leave = await AppDialog.confirm(
            context,
            icon: Icons.logout_rounded,
            title: searching ? 'توقف البحث عن محامي؟' : 'تلغي اختيارك للمحامي؟',
            message: searching
                ? 'المحامين مش هيقدروا يبعتوا عروض، وطلبك هيتلغي'
                : 'لسه ما دفعتش، فمش هيتخصم منك حاجة، والطلب هيتلغي',
            confirmText: searching ? 'وقف البحث' : 'الغي الطلب',
            cancelText: searching ? 'كمّل البحث' : 'كمّل الدفع',
            isDanger: true,
          );
          if (!leave || !mounted) return;
        }
        _returnToLawyerProfile();
      },
      child: Scaffold(
      backgroundColor: AppColors.background,
      // الهيدر باسم الخدمة اللي الموكل اختارها
      appBar: AppHeader(title: LegalService.titleFor(widget.problemTitle), isInnerPage: true),
      body: Stack(
        children: [
          // 1. خريطة تفاعلية مستضافة على السيرفر
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: currentLatLng,
              initialZoom: appMapStartZoom,
              minZoom: appMapMinZoom,
              maxZoom: appMapMaxZoom,
              // الخريطة ما بتلفش، فكل حاجة عليها ثابتة
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
              cameraConstraint: appMapBounds,
              backgroundColor: appMapBackground,
              onPositionChanged: _onMapMoved,
              // A tap near a pin opens that lawyer in the sheet
              onTap: (_, point) {
                if (_orderFlowStage != _OrderFlowStage.idle) return;
                final hit = lawyerAtTap(_mapController.camera, point, _pinLawyers, selectedId: _selectedLawyer?.id);
                if (hit != null) _onLawyerTapped(hit);
              },
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

              // بعيد عدد في كل منطقة، وفي النص دبابيس صغيرة، وقريب كروت (MapLawyerLoader)
              if (_orderFlowStage == _OrderFlowStage.idle) LawyerPinsLayer(lawyers: _pinLawyers, selectedId: _selectedLawyer?.id),

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
                    '© TomTom',
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
                        showHandle: false,
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
                        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.5),
                        child: _showReviews && (_reviewsLawyerId ?? _selectedLawyer?.id) != null
                            ? SizedBox(
                                height: MediaQuery.sizeOf(context).height * 0.45,
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
