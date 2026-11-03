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
import '../../core/services/geo_naming_service.dart';
import '../../core/services/location_service.dart';
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
    _stageTimer?.cancel();
    _cameraAnimController?.dispose();
    _sheetCurve.dispose();
    _sheetAnimController.dispose();
    _sheetHeightNotifier.dispose();
    super.dispose();
  }

  /// الشيت والكاميرا يتحركوا مع بعض مرة واحدة، و[moveCamera] يتقفل لو الكاميرا اتحركت فعلاً
  void _snapSheetTo(double targetHeight, {bool moveCamera = true}) {
    final hasChanged = (targetHeight - _sheetHeight).abs() > 1;
    _sheetTween = Tween<double>(begin: _sheetHeight, end: targetHeight);
    _sheetAnimController.forward(from: 0.0);

    final selected = _selectedLawyer;
    if (moveCamera && hasChanged && selected != null) {
      _zoomFitRouteAndLawyer(_searchCenter, selected.position, sheetHeight: targetHeight);
    }
  }

  /// كل حركات الكاميرا تمر من هنا: حركة واحدة تلغي اللي قبلها ومدتها حسب المسافة
  void _animatedMapMove(LatLng destLocation, double destZoom) {
    _stopCamera();

    final camera = _mapController.camera;
    final targetZoom = destZoom.clamp(appMapMinZoom, appMapMaxZoom);
    final zoomChange = (targetZoom - camera.zoom).abs();
    final distanceKm = const Distance().as(LengthUnit.Kilometer, camera.center, destLocation);
    final distanceMeters = const Distance().as(LengthUnit.Meter, camera.center, destLocation);
    if (distanceMeters < 5 && zoomChange < 0.05) return;

    final latTween = Tween<double>(begin: camera.center.latitude, end: destLocation.latitude);
    final lngTween = Tween<double>(begin: camera.center.longitude, end: destLocation.longitude);
    final zoomTween = Tween<double>(begin: camera.zoom, end: targetZoom);

    final controller = AnimationController(
      duration: Duration(milliseconds: (350 + zoomChange * 90 + distanceKm * 4).clamp(350, 800).round()),
      vsync: this,
    );
    _cameraAnimController = controller;

    final animation = CurvedAnimation(parent: controller, curve: Curves.easeOutCubic);

    controller.addListener(() {
      _mapController.move(
        LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
        zoomTween.evaluate(animation),
      );
    });

    controller.forward();
  }

  /// لمس الخريطة يوقف أي حركة تلقائية فوراً، فالتحكم يرجع للمستخدم
  void _stopCamera() {
    _cameraAnimController?.dispose();
    _cameraAnimController = null;
  }

  /// يوضع النقطة في نص الجزء الظاهر من الخريطة فوق الشيت
  void _focusPoint(LatLng point, double zoom) {
    final camera = _mapController.camera;
    final target = camera.project(point, zoom) + math.Point<double>(0, _sheetHeight / 2);
    _animatedMapMove(camera.unproject(target, zoom), zoom);
  }

  /// حساب ورسم المسار بين المستخدم والمحامي والتأكد من اتصاله بمربع المحامي مباشرة
  Future<void> _calculateRouteToLawyer(MapLawyer lawyer) async {
    final userPos = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : const LatLng(30.0444, 31.2357);

    setState(() {
      _selectedLawyer = lawyer;
    });

    await _drawRoute(userPos, lawyer.position);
  }

  /// خط منحني يوضح اتصال الطرفين، ويترسم على الموبايل فقط
  List<LatLng> _connectionLine(LatLng start, LatLng end) {
    const segments = 24;
    final control = LatLng(
      (start.latitude + end.latitude) / 2 + (end.longitude - start.longitude) * 0.14,
      (start.longitude + end.longitude) / 2 - (end.latitude - start.latitude) * 0.14,
    );

    return [
      for (var i = 0; i <= segments; i++)
        () {
          final t = i / segments;
          final rest = 1 - t;
          return LatLng(
            rest * rest * start.latitude + 2 * rest * t * control.latitude + t * t * end.latitude,
            rest * rest * start.longitude + 2 * rest * t * control.longitude + t * t * end.longitude,
          );
        }(),
    ];
  }

  /// حساب الوقت والمسافة على الطرق بين نقطتين، ورسم خط الاتصال بينهما
  Future<void> _drawRoute(LatLng start, LatLng destination) async {
    // الخط يظهر فوراً، والوقت يكمل لما الخادم يرد
    setState(() {
      _routePoints = _connectionLine(start, destination);
      _isInitialLoading = false;
    });

    final estimate = await _routingService.calculateDrivingRoute(
      start: start,
      destination: destination,
    );

    if (mounted) {
      setState(() {
        _routeEstimate = estimate;
      });
    }
  }

  /// ضبط كاميرا الخريطة لعرض المسار كاملاً بين موقعي وموقع المحامي المختار مهما كانت المسافة مع مراعاة البوتن شيت
  void _zoomFitRouteAndLawyer(LatLng userPos, LatLng lawyerPos, {double? sheetHeight}) {
    if (!mounted) return;
    final effectiveSheetHeight = sheetHeight ?? _sheetHeight;
    try {
      final List<LatLng> fitCoordinates = [userPos, lawyerPos];
      if (_routePoints.isNotEmpty) {
        fitCoordinates.addAll(_routePoints);
      }

      final fit = CameraFit.coordinates(
        coordinates: fitCoordinates,
        padding: EdgeInsets.only(
          bottom: effectiveSheetHeight + 45.0, // مساحة البوتن شيت الفعلية + هامش مريح لعدم حجب أي جزء من المسار
          top: 80.0,                           // هامش أسفل الهيدر العلوي الثابت
          left: 55.0,
          right: 55.0,
        ),
        maxZoom: appMapMaxZoom,
        minZoom: appMapMinZoom,
      );

      final fittedCamera = fit.fit(_mapController.camera);
      _animatedMapMove(fittedCamera.center, fittedCamera.zoom);
    } catch (_) {
      final midLat = (userPos.latitude + lawyerPos.latitude) / 2 - (effectiveSheetHeight / 85000.0);
      final midLng = (userPos.longitude + lawyerPos.longitude) / 2;
      _animatedMapMove(LatLng(midLat, midLng), 14.2);
    }
  }

  /// التفاعل عند الضغط على محامٍ من الخريطة: تحديث بيانات البوتن شيت المثبت وفتحه إذا كان مغلقاً
  void _onLawyerTapped(MapLawyer lawyer) {
    _currentLawyerIndex = _nearbyLawyers.indexWhere((l) => l.id == lawyer.id);
    if (_currentLawyerIndex < 0) _currentLawyerIndex = 0;

    _calculateRouteToLawyer(lawyer);

    if (_orderFlowStage != _OrderFlowStage.idle) {
      _returnToLawyerProfile();
    }

    // حركة كاميرا واحدة تضبط المحامي والموكل فوق ارتفاع الشيت النهائي
    if (_sheetHeight < _expandedHeight) {
      _snapSheetTo(_expandedHeight, moveCamera: false);
    }
    _zoomFitRouteAndLawyer(_searchCenter, lawyer.position, sheetHeight: _expandedHeight);
  }

  LatLng get _searchCenter => _currentPosition != null
      ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
      : const LatLng(30.0444, 31.2357);

  /// زر «بحث جديد»: يبحث فعلياً من السيرفر ثم يعرض المحامي التالي أو يوضح أنه لا يوجد غيره
  Future<void> _searchForNewLawyer() async {
    if (_isSearchingAgain) return;
    final currentId = _selectedLawyer?.id;

    setState(() {
      _isSearchingAgain = true;
    });

    final res = await LawyerRepository.getNearbyLawyers(
      lat: _searchCenter.latitude,
      lon: _searchCenter.longitude,
      radiusKm: _allEgyptRadiusKm,
    );
    if (!mounted) return;

    setState(() {
      _isSearchingAgain = false;
    });

    if (!res.isOk) {
      _showMessage(res.error ?? 'تعذر البحث، جرب تاني');
      return;
    }

    final lawyers = (res.data ?? const []).map(MapLawyer.fromModel).toList();
    setState(() {
      _nearbyLawyers = lawyers;
      _lawyersError = null;
      if (lawyers.isEmpty) {
        _selectedLawyer = null;
        _routePoints = [];
      }
    });

    if (lawyers.isEmpty) {
      _showMessage('مفيش محامين متاحين دلوقتي');
      return;
    }

    if (lawyers.length == 1 && lawyers.first.id == currentId) {
      _showMessage('مفيش محامي تاني متاح دلوقتي، ده المحامي الوحيد المتاح');
      return;
    }

    final currentIndex = lawyers.indexWhere((lawyer) => lawyer.id == currentId);
    _onLawyerTapped(lawyers[(currentIndex + 1) % lawyers.length]);
  }

  /// جلب الموقع الفعلي والمحامين المتاحين وحساب المسار لأقربهم تلقائياً
  Future<void> _fetchCurrentLocation() async {
    setState(() {
      _isLoading = true;
      _isInitialLoading = true;
      _lawyersError = null;
    });

    // تعذر الموقع لا يترك الخريطة في التحميل إلى ما لا نهاية
    final result = await LocationService.instance.checkAndRequestPermission().timeout(
      const Duration(seconds: 10),
      onTimeout: () => const LocationResult(
        status: LocationServiceStatus.error,
        errorMessage: 'تحديد الموقع أخد وقت طويل، حاول تاني.',
      ),
    );
    if (!mounted) return;

    LatLng centerLatLng = const LatLng(30.0444, 31.2357);

    if (result.isSuccess && result.position != null) {
      _currentPosition = result.position;
      centerLatLng = LatLng(result.position!.latitude, result.position!.longitude);

      try {
        _mapController.move(centerLatLng, appMapMaxZoom);
      } catch (_) {}

      final resolvedName = await GeoNamingService.instance.getCityAndGovernorate(
        result.position!.latitude,
        result.position!.longitude,
      );

      if (mounted) {
        setState(() {
          _locationName = resolvedName;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _locationName = 'محافظة القاهرة';
        });
      }
    }

    if (!mounted) return;

    final res = await LawyerRepository.getNearbyLawyers(
      lat: centerLatLng.latitude,
      lon: centerLatLng.longitude,
    );
    if (!mounted) return;

    final lawyers = (res.data ?? const []).map(MapLawyer.fromModel).toList();

    setState(() {
      _nearbyLawyers = lawyers;
      _isLoading = false;
      _isInitialLoading = lawyers.isNotEmpty;
      _lawyersError = res.isOk ? null : (res.error ?? 'تعذر البحث عن المحامين المتاحين');
    });

    if (lawyers.isNotEmpty) {
      _currentLawyerIndex = 0;
      _calculateRouteToLawyer(lawyers.first);
      _zoomFitRouteAndLawyer(centerLatLng, lawyers.first.position);
    }

    // المحامون يتحدثون وهو فاتح الخريطة ليظهر الموجود فعلاً فقط
    _lawyersRefreshTimer?.cancel();
    _lawyersRefreshTimer = Timer.periodic(const Duration(seconds: 60), (_) => _loadAllLawyers());
    _loadAllLawyers();
  }

  void _onMapMoved(MapCamera camera, bool hasGesture) {
    if (camera.zoom.floor() != _mapZoom.floor()) {
      setState(() {
        _mapZoom = camera.zoom;
      });
    }
  }

  /// كل المحامين المتاحين في مصر، فكل دبوس يفضل مكانه مهما اتحركت الخريطة
  Future<void> _loadAllLawyers() async {
    if (!mounted || _orderFlowStage != _OrderFlowStage.idle) return;

    final res = await LawyerRepository.getNearbyLawyers(
      lat: _searchCenter.latitude,
      lon: _searchCenter.longitude,
      radiusKm: _allEgyptRadiusKm,
    );
    if (!mounted || !res.isOk || _orderFlowStage != _OrderFlowStage.idle) return;

    final lawyers = (res.data ?? const []).map(MapLawyer.fromModel).toList();

    // المحامي المختار يفضل ظاهر حتى لو المنطقة الحالية بعيدة عنه
    final selected = _selectedLawyer;
    if (selected != null && !lawyers.any((lawyer) => lawyer.id == selected.id)) {
      lawyers.add(selected);
    }

    setState(() {
      _nearbyLawyers = lawyers;
      _lawyersError = null;
    });
  }

  /// أقرب محامي لموقع الموكل، والقائمة نفسها ممكن تكون لمنطقة تانية على الخريطة
  String? get _nearestLawyerId {
    MapLawyer? nearest;
    var nearestDistance = double.infinity;
    for (final lawyer in _nearbyLawyers) {
      final distance = const Distance().as(LengthUnit.Meter, _searchCenter, lawyer.position);
      if (distance < nearestDistance) {
        nearest = lawyer;
        nearestDistance = distance;
      }
    }
    return nearest?.id;
  }

  /// دبوس الموكل يختفي لو محامي في نفس مكانه عشان ما يبانش ورا الكارت
  bool get _isLawyerAtClientSpot => _nearbyLawyers.any(
        (lawyer) => const Distance().as(LengthUnit.Meter, _searchCenter, lawyer.position) < 40,
      );

  /// كل محامٍ يظهر بكارته، والكروت تصغر مع تصغير الخريطة
  List<Marker> _buildLawyerMarkers(double zoom) {
    final nearestId = _nearestLawyerId;
    final scale = mapCardScaleFor(zoom);

    return [
      for (final lawyer in _nearbyLawyers)
        Marker(
          point: lawyer.position,
          width: _cardWidth * scale,
          height: _cardHeight * scale,
          alignment: Alignment.topCenter,
          child: GestureDetector(
            onTap: () => _onLawyerTapped(lawyer),
            child: ScaledMapCard(
              width: _cardWidth,
              height: _cardHeight,
              child: _LawyerMapSquareMarker(
                lawyer: lawyer,
                isSelected: _selectedLawyer?.id == lawyer.id,
                isNearest: lawyer.id == nearestId,
              ),
            ),
          ),
        ),
    ];
  }

  void _centerMapOnCurrentPosition() {
    _focusPoint(_searchCenter, appMapMaxZoom);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback))),
    );
  }

  /// مراقبة وتحديث حالة الطلب الحقيقية من السيرفر لحظياً
  void _startLiveOrderPolling(String orderId) {
    _orderPollTimer?.cancel();
    bool isChecking = false;

    _orderPollTimer = Timer.periodic(const Duration(seconds: 4), (timer) async {
      if (!mounted || _orderFlowStage == _OrderFlowStage.idle) {
        timer.cancel();
        return;
      }
      // بطء الشبكة لا يراكم طلبات متزامنة
      if (isChecking) return;
      isChecking = true;

      final res = await OrderRepository.getOrderById(orderId);
      isChecking = false;
      if (!mounted || !res.isOk) return;

      final order = res.data!;
      if (order.isAccepted && _orderFlowStage == _OrderFlowStage.waitingAcceptance) {
        timer.cancel();
        setState(() {
          _orderFlowStage = _OrderFlowStage.lawyerAccepted;
        });

        // المحامي ممكن يكون اتحرك، فالوقت يتحسب من مكانه وقت القبول قبل الدفع
        final lawyerLat = order.lawyerLat;
        final lawyerLon = order.lawyerLon;
        if (lawyerLat != null && lawyerLon != null) {
          _drawRoute(_searchCenter, LatLng(lawyerLat, lawyerLon));
        }

        _stageTimer = Timer(const Duration(milliseconds: 1400), () {
          if (mounted && _orderFlowStage != _OrderFlowStage.idle) {
            setState(() {
              _orderFlowStage = _OrderFlowStage.priceReady;
            });
          }
        });
      } else if (order.isRejected || order.isCancelled || order.isNoResponse) {
        timer.cancel();
        _activeOrderId = null;
        _declineTitle = order.isNoResponse ? 'المحامي ما ردش' : 'اعتذر المحامي';
        _showDeclineThenNextLawyer();
      }
    });
  }

  /// يوضح سبب انتهاء الطلب داخل الشيت ثم يرسله تلقائياً لأقرب محامٍ تاني بنفس السعر
  void _showDeclineThenNextLawyer() {
    final declinedId = _selectedLawyer?.id;
    if (declinedId != null) _triedLawyerIds.add(declinedId);

    setState(() {
      _orderFlowStage = _OrderFlowStage.lawyerDeclined;
    });

    _stageTimer = Timer(const Duration(milliseconds: 1800), _sendToNextLawyer);
  }

  Future<void> _sendToNextLawyer() async {
    final res = await LawyerRepository.getNearbyLawyers(lat: _searchCenter.latitude, lon: _searchCenter.longitude);
    if (!mounted || _orderFlowStage != _OrderFlowStage.lawyerDeclined) return;

    final lawyers = (res.data ?? const []).map(MapLawyer.fromModel).toList();
    final remaining = lawyers.where((lawyer) => !_triedLawyerIds.contains(lawyer.id)).toList();

    if (remaining.isEmpty) {
      setState(() {
        _nearbyLawyers = lawyers;
        _orderFlowStage = _OrderFlowStage.idle;
        _currentLawyerIndex = 0;
        _selectedLawyer = lawyers.firstOrNull;
        if (lawyers.isEmpty) _routePoints = [];
      });
      _showMessage('مفيش محامي تاني متاح دلوقتي، جرب بعد شوية');
      return;
    }

    final next = remaining.first;
    setState(() {
      _nearbyLawyers = remaining;
      _currentLawyerIndex = 0;
    });

    await _calculateRouteToLawyer(next);
    if (!mounted || _orderFlowStage != _OrderFlowStage.lawyerDeclined) return;

    _zoomFitRouteAndLawyer(_searchCenter, next.position);
    await _sendOrder();
  }

  void _setReviewsVisible(bool visible) {
    setState(() {
      _showReviews = visible;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _snapSheetTo(_expandedHeight);
    });
  }

  /// «طلب الآن»: تقييم السعر أولاً، والطلب لا يصل للمحامي قبل موافقة الموكل
  Future<void> _startOrderFlow() async {
    final selected = _selectedLawyer;
    if (selected == null) return;

    _triedLawyerIds.clear();
    setState(() {
      _orderFlowStage = _OrderFlowStage.evaluatingPrice;
    });

    final results = await Future.wait([
      OrderRepository.getQuote(widget.problemTitle),
      Future<void>.delayed(const Duration(milliseconds: 1800)),
    ]);
    if (!mounted || _orderFlowStage != _OrderFlowStage.evaluatingPrice) return;

    final quote = results[0] as ApiResponse<int>;
    if (!quote.isOk) {
      setState(() {
        _orderFlowStage = _OrderFlowStage.idle;
      });
      _showMessage(quote.error ?? 'تعذر تقييم سعر الخدمة');
      return;
    }

    setState(() {
      _servicePrice = quote.data ?? 0;
      _orderFlowStage = _OrderFlowStage.priceApproval;
    });
  }

  /// موافقة الموكل على السعر تنشئ الطلب وترسله للمحامي
  Future<void> _sendOrder() async {
    final lawyer = _selectedLawyer;
    if (lawyer == null) return;

    final res = await OrderRepository.createOrder(
      lawyerId: lawyer.id,
      serviceTitle: widget.problemTitle ?? 'محاميك حالاً - استشارة وحضور عاجل',
      problemType: widget.problemTitle ?? 'استشارة وتمثيل فوري',
      problemDescription: widget.problemDescription ?? 'طلب حضور عاجل واستشارة فورية من خلال خدمة محاميك حالاً',
      clientLat: _currentPosition?.latitude ?? 30.0444,
      clientLon: _currentPosition?.longitude ?? 31.2357,
      clientAddress: _locationName,
    );

    if (!mounted) return;

    final order = res.data;
    if (!res.isOk || order == null) {
      setState(() {
        _orderFlowStage = _OrderFlowStage.idle;
      });
      _showMessage(res.error ?? 'تعذر إرسال طلبك، يرجى المحاولة مرة أخرى.');
      return;
    }

    _activeOrderId = order.id;
    _activeOrderNumber = order.orderNumber;
    setState(() {
      _servicePrice = order.price.round();
      _orderSecondsLeft = order.responseSecondsLeft > 0 ? order.responseSecondsLeft : 120;
      _orderFlowStage = _OrderFlowStage.waitingAcceptance;
    });
    _startLiveOrderPolling(order.id);
  }

  /// الرجوع لملف المحامي من مراحل الطلب: الطلب الذي لم يكتمل يُلغى حتى لا يبقى معلقاً عند المحامي
  void _returnToLawyerProfile() {
    final pendingOrderId = _activeOrderId;
    _orderPollTimer?.cancel();
    _stageTimer?.cancel();
    _activeOrderId = null;
    _activeOrderNumber = null;

    setState(() {
      _orderFlowStage = _OrderFlowStage.idle;
    });

    if (pendingOrderId != null) {
      OrderRepository.cancelOrder(pendingOrderId);
    }
  }

  void _openPayment() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PaymentScreen(
          orderId: _activeOrderId,
          orderNumber: _activeOrderNumber,
          locationName: _locationName,
          lawyer: _selectedLawyer,
          routeEstimate: _routeEstimate,
          problemTitle: widget.problemTitle,
          problemDescription: widget.problemDescription,
          price: _servicePrice,
        ),
      ),
    );
  }

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

  Widget _buildLawyerProfileCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // مساحة الملف التعريفي / حالة التحميل الثابتة
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: !_isLoading && _nearbyLawyers.isEmpty
              ? KeyedSubtree(key: const ValueKey('no_lawyers'), child: AppStateMessage(
                  icon: _lawyersError != null ? Icons.wifi_off_rounded : Icons.person_search_rounded,
                  title: _lawyersError != null ? 'تعذر تحميل المحامين' : 'لا يوجد محامون متاحون حالياً',
                  message: _lawyersError,
                  onRetry: _fetchCurrentLocation,
                ))
              : _selectedLawyer == null
              ? Container(
                  key: const ValueKey('loading_lawyer'),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Lottie.asset(
                        'assets/images/splash_gif.json',
                        width: 80,
                        height: 80,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'جاري البحث عن أقرب محامٍ متاح',
                        style: TextStyle(
                          fontFamily: 'AppFont',
                          fontFamilyFallback: appFontFallback,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.dark,
                        ),
                      ),
                    ],
                  ),
                )
              : KeyedSubtree(key: ValueKey(_selectedLawyer!.id), child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LawyerProfileSummary(
                      avatar: _LawyerAvatarPhoto(
                        imageUrl: _selectedLawyer!.imageUrl,
                        initials: _selectedLawyer!.avatarInitials,
                        fallbackColor: _selectedLawyer!.avatarColor,
                        size: 56,
                      ),
                      name: _selectedLawyer!.name,
                      title: _selectedLawyer!.title,
                      rating: _selectedLawyer!.rating,
                      reviewsCount: _selectedLawyer!.reviewsCount,
                      experienceYears: _selectedLawyer!.experienceYears,
                      distanceText: _routeEstimate != null && _routeEstimate!.isSuccess
                          ? _routeEstimate!.distanceText
                          : '${_selectedLawyer!.distanceMeters.round()} م',
                      distanceCaption: _routeEstimate != null && _routeEstimate!.isSuccess
                          ? _routeEstimate!.arrivalRangeText
                          : 'مسافة تقريبية',
                      isNearest: _selectedLawyer!.id == _nearestLawyerId,
                    ),
                    const SizedBox(height: 12),

                    // ملف Google والتقييمات جنب بعض
                    Row(
                      children: [
                        Expanded(
                          child: AppButton.outlined(
                            text: 'ملف Google',
                            height: 44,
                            customIcon: const GoogleMark(),
                            onPressed: () {
                              if (_selectedLawyer == null) return;
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => LawyerGoogleProfileScreen(
                                    lawyer: _selectedLawyer!,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: AppButton.outlined(
                            text: 'التقييمات (${_selectedLawyer!.reviewsCount})',
                            height: 44,
                            onPressed: () => _setReviewsVisible(true),
                          ),
                        ),
                      ],
                    ),
                  ],
                )),
        ),
        const SizedBox(height: 10),

        // 7. زرين بجوار بعضهما: «طلب الآن» و «بحث جديد»
        Row(
          children: [
            // الزر الأول: طلب الآن (الرئيسي)
            Expanded(
              flex: 6,
              child: AppButton.primary(
                text: 'طلب الآن',
                icon: Icons.check_circle_outline_rounded,
                height: 48,
                fontSize: 14,
                onPressed: (_isLoading || _selectedLawyer == null) ? null : _startOrderFlow,
              ),
            ),
            const SizedBox(width: 10),

            // الزر الثاني: بحث جديد من السيرفر عن محامٍ تاني
            Expanded(
              flex: 4,
              child: AppPressable(
                child: OutlinedButton.icon(
                  onPressed: (_isLoading || _isSearchingAgain) ? null : _searchForNewLawyer,
                  icon: _isSearchingAgain
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                        )
                      : const Icon(Icons.refresh_rounded, color: AppColors.primary, size: 18),
                  label: const Text(
                    'بحث جديد',
                    style: TextStyle(
                      fontFamily: 'AppFont',
                      fontFamilyFallback: appFontFallback,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    overlayColor: Colors.transparent,
                    foregroundColor: AppColors.primary,
                    side: BorderSide(color: AppColors.primary.withOpacity(0.35), width: 1.2),
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24.0),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOrderFlowContent() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      child: _buildStageWidget(),
    );
  }

  Widget _buildStageWidget() {
    switch (_orderFlowStage) {
      case _OrderFlowStage.idle:
        return const SizedBox.shrink();

      case _OrderFlowStage.lawyerDeclined:
        return Column(
          key: const ValueKey('stage_lawyer_declined'),
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const LineIllustration(icon: Icons.help_outline_rounded, height: 72),
            const SizedBox(height: 14),
            Text(
              _declineTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'AppFont',
                fontFamilyFallback: appFontFallback,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.danger,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'بندورلك على محامي تاني',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'AppFont',
                fontFamilyFallback: appFontFallback,
                fontSize: 13,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );

      case _OrderFlowStage.waitingAcceptance:
        return Column(
          key: const ValueKey('stage_waiting_acceptance'),
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const LineIllustration(icon: Icons.hourglass_top_rounded, height: 64),
            const SizedBox(height: 10),
            const Text(
              'في انتظار قبول المحامي',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'AppFont',
                fontFamilyFallback: appFontFallback,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.dark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'وصل طلبك إلى ${_selectedLawyer?.name ?? 'المحامي'}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'AppFont',
                fontFamilyFallback: appFontFallback,
                fontSize: 13,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            ResponseCountdown(key: ValueKey(_activeOrderId), secondsLeft: _orderSecondsLeft),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: AppButton.outlined(text: 'إلغاء الطلب', height: 46, onPressed: _returnToLawyerProfile),
            ),
          ],
        );

      case _OrderFlowStage.lawyerAccepted:
        return Column(
          key: const ValueKey('stage_lawyer_accepted'),
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const LineIllustration(icon: Icons.verified_rounded, height: 72),
            const SizedBox(height: 14),
            Text(
              'وافق ${_selectedLawyer?.name ?? 'المحامي'} على طلبك',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'AppFont',
                fontFamilyFallback: appFontFallback,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.success,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'المحامي جاهز لمساعدتك',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'AppFont',
                fontFamilyFallback: appFontFallback,
                fontSize: 13,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );

      case _OrderFlowStage.evaluatingPrice:
        return Column(
          key: const ValueKey('stage_evaluating_price'),
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const RepaintBoundary(
              child: LineIllustration(icon: Icons.payments_rounded, height: 72),
            ),
            const SizedBox(height: 14),
            const Text(
              'جاري تقييم السعر',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'AppFont',
                fontFamilyFallback: appFontFallback,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.dark,
              ),
            ),
            if (widget.problemTitle != null) ...[
              const SizedBox(height: 6),
              Text(
                widget.problemTitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'AppFont',
                  fontFamilyFallback: appFontFallback,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ],
        );

      case _OrderFlowStage.priceApproval:
        return Column(
          key: const ValueKey('stage_price_approval'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const LineIllustration(icon: Icons.payments_rounded, height: 72),
            const SizedBox(height: 6),
            const Text(
              'سعر الخدمة',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'AppFont',
                fontFamilyFallback: appFontFallback,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: AppColors.dark,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$_servicePrice ج.م',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'AppFont',
                fontFamilyFallback: appFontFallback,
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: AppColors.dark,
              ),
            ),
            const Text(
              'شامل أتعاب المحامي وانتقالاته والضريبة',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'AppFont',
                fontFamilyFallback: appFontFallback,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.success,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 6,
                  child: AppButton.primary(text: 'موافق', height: 48, onPressed: _sendOrder),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 4,
                  child: AppButton.outlined(text: 'إلغاء', height: 48, onPressed: _returnToLawyerProfile),
                ),
              ],
            ),
          ],
        );

      case _OrderFlowStage.priceReady:
        return Column(
          key: const ValueKey('stage_price_ready'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const LineIllustration(icon: Icons.credit_card_rounded, height: 60),
            const SizedBox(height: 6),
            const Text(
              'أتعاب الخدمة',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'AppFont',
                fontFamilyFallback: appFontFallback,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: AppColors.dark,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$_servicePrice ج.م',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'AppFont',
                fontFamilyFallback: appFontFallback,
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: AppColors.dark,
              ),
            ),
            // نص السعر الشامل تحت الرقم
            const Text(
              'شاملة أتعاب المحامي وانتقالاته والضريبة خلال 24 ساعة',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'AppFont',
                fontFamilyFallback: appFontFallback,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.success,
              ),
            ),
            const SizedBox(height: 16),
            // زر دفع وتأكيد الطلب ينقل لصفحة الدفع المنفصلة مع مؤشر تحميل مدمج
            AppButton.primary(
              text: 'دفع $_servicePrice ج.م وتأكيد الطلب',
              icon: Icons.payment_rounded,
              onPressed: _openPayment,
              height: 48,
            ),
            const SizedBox(height: 4),
            Center(
              child: AppPressable(
                child: TextButton(
                onPressed: _returnToLawyerProfile,
                child: const Text(
                  'رجوع لملف المحامي',
                  style: TextStyle(
                    fontFamily: 'AppFont',
                    fontFamilyFallback: appFontFallback,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              ),
            ),
          ],
        );
    }
  }

  Widget _buildMapControlBtn({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(7.0),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: AppPressable(
        child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 20, color: color),
        onPressed: onPressed,
      ),
      ),
    );
  }
}
