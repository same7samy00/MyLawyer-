import 'dart:async';
import 'dart:math' as math;
import '../../core/widgets/app_pressable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:lottie/lottie.dart' hide Marker;
import '../../core/constants/app_colors.dart';
import '../../core/constants/map_config.dart';
import '../../core/services/api_service.dart';
import '../../core/services/app_cached_tile_provider.dart';
import '../../core/services/external_navigation.dart';
import '../../core/services/geo_naming_service.dart';
import '../../core/services/location_service.dart';
import '../../core/services/routing_service.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_header.dart';
import '../../core/widgets/app_state_message.dart';
import '../../core/widgets/lawyer_profile_summary.dart';
import '../../core/widgets/lawyer_reviews_panel.dart';
import '../../core/widgets/response_countdown.dart';
import '../../core/widgets/sheet_lines.dart';
import '../../data/models/map_lawyer.dart';
import '../../data/models/order_model.dart';
import '../../data/repositories/lawyer_repository.dart';
import '../../data/repositories/order_repository.dart';
import 'payment_screen.dart';
import 'lawyer_google_profile_screen.dart';

class TrackingScreen extends StatefulWidget {
  final String? problemTitle;
  final String? problemDescription;
  final bool isLawyerView;
  final OrderModel? lawyerOrder;

  const TrackingScreen({
    super.key,
    this.problemTitle,
    this.problemDescription,
    this.isLawyerView = false,
    this.lawyerOrder,
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

  static const double _cardsFromZoom = 14.0;
  static const double _lawyerFocusZoom = 15.5;
  static const double _orderRadiusKm = 25.0;
  static const double _allEgyptRadiusKm = 1500.0;
  String? _lawyersError;

  static const double _collapsedHeight = 74.0;
  double get _expandedHeight {
    final screenH = MediaQuery.sizeOf(context).height;
    if (widget.isLawyerView) {
      // تفاصيل الطلب تظهر كاملة من غير سكرول، والخريطة تفضل ظاهرة فوقها
      return (screenH * 0.74).clamp(540.0, 680.0);
    }
    if (_showReviews) return screenH * 0.8;
    return 390.0;
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
  late String? _lawyerOrderStatus = widget.lawyerOrder?.status;
  late int _lawyerSecondsLeft = widget.lawyerOrder?.responseSecondsLeft ?? 0;
  bool _lawyerResponseTimeOver = false;
  Timer? _lawyerOrderPollTimer;

  int _servicePrice = 0;
  int _orderSecondsLeft = 120;
  String _declineTitle = 'اعتذر المحامي';
  bool _showReviews = false;
  bool _isSearchingAgain = false;
  Timer? _lawyersRefreshTimer;
  double _mapZoom = 15.2;

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
    if (widget.isLawyerView && _lawyerOrderStatus == 'PENDING') _watchLawyerOrder();
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
    _lawyerOrderPollTimer?.cancel();
    _lawyersRefreshTimer?.cancel();
    _stageTimer?.cancel();
    _cameraAnimController?.dispose();
    _sheetCurve.dispose();
    _sheetAnimController.dispose();
    _sheetHeightNotifier.dispose();
    super.dispose();
  }

  void _snapSheetTo(double targetHeight) {
    _sheetTween = Tween<double>(begin: _sheetHeight, end: targetHeight);
    _sheetAnimController.forward(from: 0.0).then((_) {
      if (mounted && _selectedLawyer != null && _currentPosition != null) {
        _zoomFitRouteAndLawyer(
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          _selectedLawyer!.position,
          sheetHeight: targetHeight,
        );
      }
    });
  }

  /// تحريك كاميرا الخريطة بشكل سلس وتدريجي مع إلغاء أي حركة سابقة لمنع التداخل والقفز
  void _animatedMapMove(LatLng destLocation, double destZoom) {
    _cameraAnimController?.dispose();
    _cameraAnimController = null;

    final camera = _mapController.camera;
    final latTween = Tween<double>(begin: camera.center.latitude, end: destLocation.latitude);
    final lngTween = Tween<double>(begin: camera.center.longitude, end: destLocation.longitude);
    final zoomTween = Tween<double>(begin: camera.zoom, end: destZoom);

    final controller = AnimationController(
      duration: const Duration(milliseconds: 650),
      vsync: this,
    );
    _cameraAnimController = controller;

    final Animation<double> animation = CurvedAnimation(
      parent: controller,
      curve: Curves.easeInOutCubic,
    );

    controller.addListener(() {
      _mapController.move(
        LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
        zoomTween.evaluate(animation),
      );
    });

    controller.forward();
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
    final estimate = await _routingService.calculateDrivingRoute(
      start: start,
      destination: destination,
    );

    if (mounted) {
      final finalPoints = _connectionLine(start, destination);

      setState(() {
        _routeEstimate = estimate;
        _routePoints = finalPoints;
        _isInitialLoading = false;
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
        maxZoom: 16.5,
        minZoom: 9.0, // زوم أوت مناسب مهما طالت المسافة
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

    // إذا كان البوتن شيت مغلقاً أو مصغراً، يتم فتحه بسلاسة
    if (_sheetHeight < _expandedHeight) {
      _snapSheetTo(_expandedHeight);
    }

    if (_orderFlowStage != _OrderFlowStage.idle) {
      _returnToLawyerProfile();
    }

    // الضغط على الدبوس يقرب الكاميرا فيتحول لكارت المحامي
    if (_mapController.camera.zoom < _cardsFromZoom) {
      _zoomToLawyer(lawyer);
      return;
    }

    final userPos = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : const LatLng(30.0444, 31.2357);

    _zoomFitRouteAndLawyer(userPos, lawyer.position, sheetHeight: _expandedHeight);
  }

  LatLng get _searchCenter => _currentPosition != null
      ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
      : const LatLng(30.0444, 31.2357);

  void _zoomToLawyer(MapLawyer lawyer) {
    final camera = _mapController.camera;
    // الكارت يظهر فوق البوتن شيت، فمركز الكاميرا ينزل بنص ارتفاعها
    final target = camera.project(lawyer.position, _lawyerFocusZoom) + math.Point<double>(0, _expandedHeight / 2 - 30);
    _animatedMapMove(camera.unproject(target, _lawyerFocusZoom), _lawyerFocusZoom);
  }

  /// زر «بحث جديد»: يبحث فعلياً من السيرفر ثم يعرض المحامي التالي أو يوضح أنه لا يوجد غيره
  Future<void> _searchForNewLawyer() async {
    if (_isSearchingAgain) return;
    final currentId = _selectedLawyer?.id;

    setState(() {
      _isSearchingAgain = true;
    });

    final res = await LawyerRepository.getNearbyLawyers(lat: _searchCenter.latitude, lon: _searchCenter.longitude);
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
      _showMessage('مفيش محامين متاحين حواليك دلوقتي');
      return;
    }

    if (lawyers.length == 1 && lawyers.first.id == currentId) {
      _showMessage('مفيش محامي تاني متاح دلوقتي، ده أقرب محامي ليك');
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
        errorMessage: 'Location request timed out',
      ),
    );
    if (!mounted) return;

    LatLng centerLatLng = const LatLng(30.0444, 31.2357);

    if (result.isSuccess && result.position != null) {
      _currentPosition = result.position;
      centerLatLng = LatLng(result.position!.latitude, result.position!.longitude);

      try {
        _mapController.move(centerLatLng, 15.4);
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

    // المحامي يتابع موقع موكله في طلبه المفتوح ولا يبحث عن محامين آخرين
    if (widget.isLawyerView) {
      setState(() {
        _isLoading = false;
        _isInitialLoading = false;
      });
      await _showRouteToClient();
      return;
    }

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
      await _calculateRouteToLawyer(lawyers.first);
      _zoomFitRouteAndLawyer(centerLatLng, lawyers.first.position);
    }

    // المحامون يتحدثون وهو فاتح الخريطة ليظهر الموجود فعلاً فقط
    _lawyersRefreshTimer?.cancel();
    _lawyersRefreshTimer = Timer.periodic(const Duration(seconds: 20), (_) => _loadAllLawyers());
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

  /// الدبوس يصغر مع التصغير عشان ما يغطيش الخريطة
  double _pinSizeFor(double zoom) => zoom < 8 ? 24 : (zoom < 11 ? 32 : 42);

  Marker _buildLawyerPin(MapLawyer lawyer, double size) {
    return Marker(
      point: lawyer.position,
      width: size,
      height: size * 58 / 52,
      alignment: Alignment.topCenter,
      child: GestureDetector(
        onTap: () => _onLawyerTapped(lawyer),
        child: FittedBox(child: _LawyerMapPin(isSelected: _selectedLawyer?.id == lawyer.id)),
      ),
    );
  }

  /// التقريب يعرض كارت المحامي، والتصغير يعرض دبوس لكل محامٍ
  List<Marker> _buildLawyerMarkers(double zoom) {
    if (zoom >= _cardsFromZoom) {
      final nearestId = _nearestLawyerId;
      return [
        for (final lawyer in _nearbyLawyers)
          Marker(
            point: lawyer.position,
            width: 195,
            height: 53,
            alignment: Alignment.topCenter,
            child: GestureDetector(
              onTap: () => _onLawyerTapped(lawyer),
              child: _LawyerMapSquareMarker(
                lawyer: lawyer,
                isSelected: _selectedLawyer?.id == lawyer.id,
                isNearest: lawyer.id == nearestId,
              ),
            ),
          ),
      ];
    }

    final pinSize = _pinSizeFor(zoom);
    return [for (final lawyer in _nearbyLawyers) _buildLawyerPin(lawyer, pinSize)];
  }

  /// مسار المحامي إلى موكله، من موقعه الحالي أو آخر موقع مسجل للطلب
  Future<void> _showRouteToClient() async {
    final order = widget.lawyerOrder;
    if (order == null) return;

    final LatLng? lawyerPos = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : order.lawyerLat != null && order.lawyerLon != null
            ? LatLng(order.lawyerLat!, order.lawyerLon!)
            : null;
    if (lawyerPos == null) return;

    final clientPos = LatLng(order.clientLat, order.clientLon);
    await _drawRoute(lawyerPos, clientPos);
    if (mounted) _zoomFitRouteAndLawyer(lawyerPos, clientPos);
  }

  /// متابعة طلب المحامي لحد ما يترد عليه أو يتقفل
  void _watchLawyerOrder() {
    _lawyerOrderPollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      final res = await OrderRepository.getOrderById(widget.lawyerOrder!.id);
      if (!mounted || !res.isOk) return;

      final order = res.data!;
      if (order.status != 'PENDING') timer.cancel();
      setState(() {
        _lawyerOrderStatus = order.status;
        _lawyerSecondsLeft = order.responseSecondsLeft;
      });
    });
  }

  void _centerMapOnCurrentPosition() {
    final LatLng target = _currentPosition != null
        ? LatLng(_currentPosition!.latitude - 0.0015, _currentPosition!.longitude)
        : const LatLng(30.0444, 31.2357);
    _animatedMapMove(target, 16.0);
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

    _orderPollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
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

    // الخريطة بتعرض محامين أبعد، لكن الخدمة العاجلة في نطاق الموكل
    final distanceKm = const Distance().as(LengthUnit.Kilometer, _searchCenter, selected.position);
    if (distanceKm > _orderRadiusKm) {
      _showMessage('المحامي ده بعيد عن موقعك، اختار محامي قريب منك');
      return;
    }

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

    final clientOrder = widget.lawyerOrder;

    // الرجوع أثناء مراحل الطلب يعود لملف المحامي أولاً قبل مغادرة الخريطة
    return PopScope(
      canPop: _orderFlowStage == _OrderFlowStage.idle,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _returnToLawyerProfile();
      },
      child: Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppHeader(
        title: widget.isLawyerView ? 'تفاصيل الطلب' : 'محاميك حالاً',
        isInnerPage: true,
      ),
      body: Stack(
        children: [
          // 1. خريطة تفاعلية مستضافة على السيرفر
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: currentLatLng,
              initialZoom: 15.2,
              minZoom: 3.0,
              maxZoom: 19.0,
              onPositionChanged: _onMapMoved,
            ),
            children: [
              TileLayer(
                urlTemplate: MapConfig.serverTileUrl,
                fallbackUrl: MapConfig.fallbackTileUrl,
                userAgentPackageName: MapConfig.userAgentPackage,
                tileProvider: AppCachedTileProvider.instance,
                maxNativeZoom: 18,
              ),

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
                      width: 50,
                      height: 56,
                      alignment: Alignment.topCenter,
                      child: const _UserLocationPin(),
                    ),

                  if (clientOrder != null)
                    Marker(
                      point: LatLng(clientOrder.clientLat, clientOrder.clientLon),
                      width: 195,
                      height: 53,
                      alignment: Alignment.topCenter,
                      child: _ClientMapCard(order: clientOrder),
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
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const SheetLines(top: 62),
                    SafeArea(
                  top: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      sheetHeader!,

                      // محتوى الملف التعريفي بمساحة ثابتة ومريحة لا تتغير أبعادها مع البحث أو تبديل المحامي
                      if (sheetHeight > _collapsedHeight + 30)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
                            child: widget.isLawyerView
                                ? _buildLawyerOrderReviewCard()
                                : (_showReviews && _selectedLawyer != null
                                    ? LawyerReviewsPanel(
                                        lawyerId: _selectedLawyer!.id,
                                        onClose: () => _setReviewsVisible(false),
                                      )
                                    : _orderFlowStage != _OrderFlowStage.idle
                                        ? _buildOrderFlowContent()
                                        : _buildLawyerProfileCard()),
                          ),
                        ),
                    ],
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
                widget.isLawyerView
                    ? 'تفاصيل الطلب العاجل'
                    : (_showReviews
                        ? 'التقييمات'
                        : _orderFlowStage == _OrderFlowStage.idle
                            ? 'أقرب المحامين إليك'
                            : 'متابعة الطلب'),
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

  Widget _buildLawyerOrderReviewCard() {
    final order = widget.lawyerOrder!;
    final clientName = order.clientName ?? 'الموكل';
    final ref = order.orderNumber;
    final problem = order.problemType ?? order.serviceTitle;
    final desc = order.problemDescription;
    final isPaid = _lawyerOrderStatus == 'ACTIVE';
    final location = order.clientAddress ?? '';
    final price = order.priceText;
    final isPending = _lawyerOrderStatus == 'PENDING' && !_lawyerResponseTimeOver;

    if (_isLawyerOrderOver) return _buildLawyerOrderEnded();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isPending) ...[
                  ResponseCountdown(
                    secondsLeft: _lawyerSecondsLeft,
                    onFinished: () => setState(() => _lawyerResponseTimeOver = true),
                  ),
                  const SizedBox(height: 12),
                ],

                // 1. بيانات الموكل ورقم المعاملة
                Center(
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(7.0),
                      border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                    ),
                    child: const Icon(Icons.person_rounded, color: AppColors.primary, size: 26),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        clientName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'AppFont',
                          fontFamilyFallback: appFontFallback,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: AppColors.dark,
                        ),
                        maxLines: 2,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 16),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'المعاملة: $ref',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'AppFont',
                    fontFamilyFallback: appFontFallback,
                    fontSize: 11,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$price ج.م',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'AppFont',
                    fontFamilyFallback: appFontFallback,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(height: 12),

                // 2. تفاصيل ونوع المشكلة القانونية مباشرة دون حاويات
                Text(
                  problem,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'AppFont',
                    fontFamilyFallback: appFontFallback,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.dark,
                  ),
                ),
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'AppFont',
                      fontFamilyFallback: appFontFallback,
                      fontSize: 12,
                      color: AppColors.textMuted,
                      height: 1.45,
                    ),
                  ),
                ],
                const SizedBox(height: 10),

                // 3. نطاق موقع الموكل مباشرة دون حاوية
                Text(
                  location,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'AppFont',
                    fontFamilyFallback: appFontFallback,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.dark,
                  ),
                ),
                if (_routeEstimate?.isSuccess == true) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${_routeEstimate!.distanceText} • ${_routeEstimate!.arrivalRangeText}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'AppFont',
                      fontFamilyFallback: appFontFallback,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
                const SizedBox(height: 14),

              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        if (isPaid)
          AppButton.primary(
            text: 'افتح مكان الموكل في Google Maps',
            icon: Icons.navigation_rounded,
            fontSize: 14,
            onPressed: () {
              _openGoogleMaps(order);
            },
          ),

        // 4. أزرار التعامل مع الطلب: قبول الطلب أساسي + اعتذار ثانوي، وتظهر فقط لطلب لم يُرد عليه
        if (isPending)
          Row(
            children: [
              // قبول الطلب (الرئيسي)
              Expanded(
                flex: 6,
                child: AppButton.primary(
                  text: 'قبول الطلب',
                  icon: Icons.check_circle_rounded,
                  fontSize: 14,
                  onPressed: _acceptLawyerOrder,
                ),
              ),
              const SizedBox(width: 10),

              // اعتذار (ثانوي 24.0px)
              Expanded(
                flex: 4,
                child: AppButton.outlined(
                  text: 'اعتذار',
                  icon: Icons.cancel_outlined,
                  height: 50,
                  textColor: AppColors.danger,
                  borderColor: AppColors.danger.withOpacity(0.35),
                  onPressed: _confirmLawyerDecline,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Future<void> _openGoogleMaps(OrderModel order) async {
    final opened = await ExternalNavigation.openDirections(order.clientLat, order.clientLon);
    if (!opened && mounted) _showMessage('تعذر فتح الخرائط');
  }

  bool get _isLawyerOrderOver =>
      _lawyerResponseTimeOver || !const ['PENDING', 'ACCEPTED', 'ACTIVE', 'COMPLETED'].contains(_lawyerOrderStatus);

  /// شاشة انتهاء الطلب عند المحامي بدل أزرار القبول والاعتذار
  Widget _buildLawyerOrderEnded() {
    final title = _lawyerOrderStatus == 'CANCELLED'
        ? 'الموكل لغى الطلب'
        : _lawyerOrderStatus == 'PENDING' || _lawyerOrderStatus == 'NO_RESPONSE'
            ? 'انتهى وقت الرد'
            : 'الطلب انتهى';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset('assets/images/questions_rafiki.svg', height: 110, fit: BoxFit.contain),
              const SizedBox(height: 14),
              Text(
                title,
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
                'الطلب اتقفل',
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
          ),
        ),
        const SizedBox(height: 12),
        AppButton.primary(
          text: 'رجوع للطلبات',
          fontSize: 14,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Future<void> _acceptLawyerOrder() async {
    // تعذر الموقع لا يمنع القبول، والموكل يشوف وقت آخر مكان معروف
    final location = await LocationService.instance.checkAndRequestPermission(fresh: true);
    if (!mounted) return;

    final res = await OrderRepository.acceptOrder(
      widget.lawyerOrder!.id,
      lat: location.position?.latitude,
      lon: location.position?.longitude,
    );
    if (!mounted) return;

    if (!res.isOk) {
      _showMessage(res.error ?? 'تعذر قبول الطلب، يرجى المحاولة مرة أخرى.');
      return;
    }

    _lawyerOrderPollTimer?.cancel();
    setState(() {
      _lawyerOrderStatus = 'ACCEPTED';
    });

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(7.0),
        ),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.success, size: 22),
            SizedBox(width: 8),
            Text(
              'قبول الطلب',
              style: TextStyle(
                fontFamily: 'AppFont',
                fontFamilyFallback: appFontFallback,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        content: const Text(
          'تم تسجيل موافقتك على تولي هذا الطلب، يمكنك الآن التواصل مع الموكل والتوجه لموقعه.',
          style: TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 13, height: 1.45),
        ),
        actions: [
          AppPressable(
            child: TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('حسناً', style: TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontWeight: FontWeight.w700)),
          ),
          ),
        ],
      ),
    );
  }

  void _confirmLawyerDecline() {
    final screenNavigator = Navigator.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        title: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: AppColors.danger, size: 22),
            SizedBox(width: 8),
            Text(
              'تأكيد الاعتذار',
              style: TextStyle(
                fontFamily: 'AppFont',
                fontFamilyFallback: appFontFallback,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        content: const Text(
          'هل أنت متأكد من الاعتذار عن قبول هذا الطلب؟',
          style: TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 13),
        ),
        actions: [
          AppPressable(
            child: TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('تراجع', style: TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback)),
          ),
          ),
          AppButton.outlined(
            text: 'اعتذار',
            width: 96,
            height: 40,
            textColor: AppColors.danger,
            borderColor: AppColors.danger.withOpacity(0.35),
            onPressed: () async {
              final dialogNavigator = Navigator.of(ctx);
              final res = await OrderRepository.rejectOrder(widget.lawyerOrder!.id);
              dialogNavigator.pop();
              if (!mounted) return;

              if (res.isOk) {
                screenNavigator.pop();
              } else {
                _showMessage(res.error ?? 'تعذر الاعتذار عن الطلب، يرجى المحاولة مرة أخرى.');
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLawyerProfileCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // مساحة الملف التعريفي / حالة التحميل الثابتة
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: !_isLoading && _nearbyLawyers.isEmpty
                ? SingleChildScrollView(
                    key: const ValueKey('no_lawyers'),
                    child: AppStateMessage(
                      icon: _lawyersError != null ? Icons.wifi_off_rounded : Icons.person_search_rounded,
                      title: _lawyersError != null ? 'تعذر تحميل المحامين' : 'لا يوجد محامون متاحون حالياً',
                      message: _lawyersError,
                      onRetry: _fetchCurrentLocation,
                    ),
                  )
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
                : SingleChildScrollView(
                    key: ValueKey(_selectedLawyer!.id),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
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
                          specialization: _selectedLawyer!.specialization,
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
                                customIcon: SvgPicture.asset(
                                  'assets/images/google_logo.svg',
                                  width: 17,
                                  height: 17,
                                ),
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
                    ),
                  ),
          ),
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
            SvgPicture.asset(
              'assets/images/questions_rafiki.svg',
              height: 110,
              fit: BoxFit.contain,
            ),
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
            SvgPicture.asset(
              'assets/images/loading_rafiki.svg',
              height: 84,
              fit: BoxFit.contain,
            ),
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
          ],
        );

      case _OrderFlowStage.lawyerAccepted:
        return Column(
          key: const ValueKey('stage_lawyer_accepted'),
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'assets/images/done_rafiki.svg',
              height: 110,
              fit: BoxFit.contain,
            ),
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
            RepaintBoundary(
              child: SvgPicture.asset(
                'assets/images/coins_rafiki.svg',
                height: 110,
                fit: BoxFit.contain,
              ),
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
            SvgPicture.asset(
              'assets/images/coins_rafiki.svg',
              height: 72,
              fit: BoxFit.contain,
            ),
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
              'شامل الانتقال والأوراق',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'AppFont',
                fontFamilyFallback: appFontFallback,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.success,
              ),
            ),
            const Spacer(),
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
            SvgPicture.asset(
              'assets/images/credit_card_rafiki.svg',
              height: 72,
              fit: BoxFit.contain,
            ),
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
            // نص شامل الانتقال موضوع تحت السعر
            const Text(
              'شاملة الانتقال والمتابعة خلال 24 ساعة',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'AppFont',
                fontFamilyFallback: appFontFallback,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.success,
              ),
            ),
            const Spacer(),
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

/// صورة المحامي الواقعية المربعة بحواف 7.0px
class _LawyerAvatarPhoto extends StatelessWidget {
  final String imageUrl;
  final String initials;
  final Color fallbackColor;
  final double size;

  const _LawyerAvatarPhoto({
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
              },
              errorBuilder: (context, error, stackTrace) {
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
              },
            )
          : Center(
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
            ),
    );
  }
}

/// دبوس خريطة حقيقي للمستخدم
class _UserLocationPin extends StatelessWidget {
  const _UserLocationPin();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 50,
      height: 56,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            bottom: 2,
            child: Container(
              width: 14,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.32),
                borderRadius: const BorderRadius.all(Radius.elliptical(14, 5)),
              ),
            ),
          ),
          const Icon(
            Icons.location_on_rounded,
            size: 52,
            color: AppColors.primary,
          ),
          Positioned(
            top: 7,
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: const Center(
                child: Icon(
                  Icons.person_rounded,
                  size: 15,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// دبوس المحامي المربع الاحترافي على الخريطة
/// دبوس المحامي عند تصغير الخريطة، والرسم كله من مركز واحد
class _LawyerMapPin extends StatelessWidget {
  final bool isSelected;

  const _LawyerMapPin({required this.isSelected});

  @override
  Widget build(BuildContext context) {
    final width = isSelected ? 46.0 : 38.0;
    final height = width * 1.24;
    final innerSize = width * 0.56;

    return Align(
      alignment: Alignment.bottomCenter,
      child: CustomPaint(
        painter: const _LawyerPinPainter(),
        child: SizedBox(
          width: width,
          height: height,
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.only(top: (width - innerSize) / 2),
              child: Container(
                width: innerSize,
                height: innerSize,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: Icon(Icons.person_rounded, size: innerSize * 0.74, color: AppColors.primary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LawyerPinPainter extends CustomPainter {
  const _LawyerPinPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width / 2;
    final side = radius * math.sqrt1_2;

    final path = Path()
      ..moveTo(radius - side, radius + side)
      ..arcTo(
        Rect.fromCircle(center: Offset(radius, radius), radius: radius),
        math.pi * 0.75,
        math.pi * 1.5,
        false,
      )
      ..quadraticBezierTo(radius + side * 0.45, size.height * 0.86, radius, size.height)
      ..quadraticBezierTo(radius - side * 0.45, size.height * 0.86, radius - side, radius + side)
      ..close();

    canvas.drawShadow(path, Colors.black.withOpacity(0.35), 3.0, false);
    canvas.drawPath(path, Paint()..color = AppColors.primary);
  }

  @override
  bool shouldRepaint(covariant _LawyerPinPainter oldDelegate) => false;
}

/// كارت الموكل على خريطة المحامي، بنفس شكل كارت المحامي
class _ClientMapCard extends StatelessWidget {
  final OrderModel order;

  const _ClientMapCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final completed = order.clientCompletedOrders;

    return CustomPaint(
      painter: _LawyerBubblePainter(color: AppColors.primary, borderColor: Colors.white, hasBorder: false),
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 4, 6, 13),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(7.0),
              ),
              child: const Icon(Icons.person_rounded, size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 6),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.clientName ?? 'الموكل',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'AppFont',
                    fontFamilyFallback: appFontFallback,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  completed > 0 ? '$completed طلب مكتمل' : 'موكل جديد',
                  style: const TextStyle(
                    fontFamily: 'AppFont',
                    fontFamilyFallback: appFontFallback,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LawyerMapSquareMarker extends StatelessWidget {
  final MapLawyer lawyer;
  final bool isSelected;
  final bool isNearest;

  const _LawyerMapSquareMarker({
    required this.lawyer,
    required this.isSelected,
    required this.isNearest,
  });

  @override
  Widget build(BuildContext context) {
    final Color badgeBg = isSelected ? AppColors.primaryHover : AppColors.primary;
    const Color borderColor = Colors.white;
    final double borderWidth = isSelected ? 1.6 : 0.0;

    return CustomPaint(
      painter: _LawyerBubblePainter(
        color: badgeBg,
        borderColor: borderColor,
        borderWidth: borderWidth,
        hasBorder: isSelected,
        isSelected: isSelected,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 4, 6, 13),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(7.0),
                border: Border.all(color: Colors.white, width: 1.2),
              ),
              child: _LawyerAvatarPhoto(
                imageUrl: lawyer.imageUrl,
                initials: lawyer.avatarInitials,
                fallbackColor: lawyer.avatarColor,
                size: 28,
              ),
            ),
            const SizedBox(width: 6),

            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      lawyer.name,
                      style: const TextStyle(
                        fontFamily: 'AppFont',
                        fontFamilyFallback: appFontFallback,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    if (isNearest) ...[
                      const SizedBox(width: 4),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF4ADE80),
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
                      style: const TextStyle(
                        fontFamily: 'AppFont',
                        fontFamilyFallback: appFontFallback,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// رسام فيكتور موحد للبطاقة والسهم مع ظلال ناعمة وإزالة الحواف للمحامين غير المحددين
class _LawyerBubblePainter extends CustomPainter {
  final Color color;
  final Color borderColor;
  final double borderWidth;
  final bool hasBorder;
  final bool isSelected;

  _LawyerBubblePainter({
    required this.color,
    required this.borderColor,
    this.borderWidth = 1.2,
    this.hasBorder = true,
    this.isSelected = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double notchHeight = 9.0;
    const double notchWidth = 16.0;
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

    // 1. رسم ظل ناعم وخفيف لتحسين الوضوح فوق الخريطة
    canvas.drawShadow(
      path,
      Colors.black.withOpacity(isSelected ? 0.28 : 0.16),
      isSelected ? 5.0 : 3.5,
      false,
    );

    // 2. تعبئة الخلفية
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // 3. رسم الحدود للمحامي المحدد فقط
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
  bool shouldRepaint(covariant _LawyerBubblePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.borderWidth != borderWidth ||
        oldDelegate.hasBorder != hasBorder ||
        oldDelegate.isSelected != isSelected;
  }
}

/// شريط خط فاصل شرط
class _DashedLineSeparator extends StatelessWidget {
  const _DashedLineSeparator();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 1.0),
      painter: _DashedLinePainter(),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.dashedBorder
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const double dashLength = 5.0;
    const double dashGap = 3.5;
    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashLength, 0), paint);
      startX += dashLength + dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
