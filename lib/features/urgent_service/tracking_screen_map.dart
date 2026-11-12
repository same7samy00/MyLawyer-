part of 'tracking_screen.dart';

extension _TrackingMapControls on _TrackingScreenState {
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

    _update(() {
      _selectedLawyer = lawyer.withDistance(const Distance().as(LengthUnit.Meter, userPos, lawyer.position));
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
    _update(() {
      _routePoints = _connectionLine(start, destination);
    });

    final estimate = await _routingService.calculateDrivingRoute(
      start: start,
      destination: destination,
    );

    if (mounted) {
      _update(() {
        _routeEstimate = estimate;
      });
    }
  }

  /// التفاعل عند الضغط على محامٍ من الخريطة: تحديث بيانات البوتن شيت المثبت وفتحه إذا كان مغلقاً
  void _onLawyerTapped(MapLawyer lawyer) {
    // الخريطة للعرض، وأثناء الطلب اللمس ما يغيرش حاجة
    if (_orderFlowStage != _OrderFlowStage.idle) return;

    _currentLawyerIndex = _nearbyLawyers.indexWhere((l) => l.id == lawyer.id);
    if (_currentLawyerIndex < 0) _currentLawyerIndex = 0;

    _calculateRouteToLawyer(lawyer);
    _update(() => _isViewingLawyer = true);

    // Tapping moves the camera so the lawyer sits in the middle above the sheet. A pin far out zooms in just
    // enough for its card to show; otherwise the zoom stays as it is
    final camera = _mapController.camera;
    final zoom = math.max(camera.zoom, cardsFromZoom);
    final point = camera.crs.latLngToPoint(lawyer.position, zoom);
    final center = camera.crs.pointToLatLng(math.Point(point.x, point.y + _sheetHeight / 2), zoom);
    _animatedMapMove(center, zoom);
  }

  void _closeLawyerProfile() {
    _update(() => _isViewingLawyer = false);
  }

  LatLng get _searchCenter => _currentPosition != null
      ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
      : const LatLng(30.0444, 31.2357);

  /// جلب الموقع الفعلي والمحامين المتاحين وحساب المسار لأقربهم تلقائياً
  Future<void> _fetchCurrentLocation() async {
    _update(() {
      _isLoading = true;
      _lawyersError = null;
    });

    // الطلب الميداني مركزه المكان اللي المحامي رايحه، مش موقع الموكل
    final field = widget.field;
    // تعذر الموقع لا يترك الخريطة في التحميل إلى ما لا نهاية
    final result = field != null
        ? LocationResult(status: LocationServiceStatus.ready, position: field.position)
        : await LocationService.instance.checkAndRequestPermission().timeout(
            const Duration(seconds: 10),
            onTimeout: () => const LocationResult(
              status: LocationServiceStatus.error,
              errorMessage: 'تحديد الموقع أخد وقت طويل، حاول تاني',
            ),
          );
    if (!mounted) return;

    LatLng centerLatLng = const LatLng(30.0444, 31.2357);

    if (result.isSuccess && result.position != null) {
      _currentPosition = result.position;
      centerLatLng = LatLng(result.position!.latitude, result.position!.longitude);

      try {
        _mapController.move(centerLatLng, appMapStartZoom);
      } catch (_) {}

      final resolvedName = field?.place.name ??
          await GeoNamingService.instance.getCityAndGovernorate(
            result.position!.latitude,
            result.position!.longitude,
          );

      if (mounted) {
        _update(() {
          _locationName = resolvedName;
        });
      }
    } else {
      if (mounted) {
        _update(() {
          _locationName = 'محافظة القاهرة';
        });
      }
    }

    if (!mounted) return;

    final loaded = await _mapLawyers.loadAround(centerLatLng);
    if (!mounted) return;

    final lawyers = _mapLawyers.nearest(centerLatLng, count: _TrackingScreenState._nearbyCount);

    _update(() {
      _nearbyLawyers = lawyers;
      _isLoading = false;
      _lawyersError = loaded || lawyers.isNotEmpty ? null : 'تعذر البحث عن المحامين';
    });

    if (lawyers.isNotEmpty) {
      _currentLawyerIndex = 0;
      _calculateRouteToLawyer(lawyers.first);
      // The line to the nearest lawyer, with both ends whole above the sheet (the sheet's full height, even
      // while it is still loading)
      final fitted = cameraShowingNearest(_mapController.camera, centerLatLng, [lawyers.first.position, ..._routePoints], sheetHeight: math.max(_sheetHeight, _expandedHeight));
      _animatedMapMove(fitted.center, fitted.zoom);
    }
  }

  void _onMapMoved(MapCamera camera, bool hasGesture) {
    if (camera.zoom.floor() != _mapZoom.floor()) {
      _update(() {
        _mapZoom = camera.zoom;
      });
    }
    if (_orderFlowStage == _OrderFlowStage.idle) _mapLawyers.cameraMoved(camera);
  }

  /// قايمة «القريبين منك» من محامين المربعات اللي على الموبايل، من غير ما نسأل السيرفر.
  /// المربعات بتتجدد لما الخريطة تتحرك لمنطقة جديدة أو يعدّي عليها 5 دقايق.
  void _refreshNearby() {
    if (_orderFlowStage != _OrderFlowStage.idle || _isLoading) return;
    final lawyers = _mapLawyers.nearest(_searchCenter, count: _TrackingScreenState._nearbyCount);
    // المحامي المختار يفضل ظاهر حتى لو المنطقة الحالية بعيدة عنه
    final selected = _selectedLawyer;
    if (selected != null && !lawyers.any((lawyer) => lawyer.id == selected.id)) lawyers.add(selected);
    _nearbyLawyers = lawyers;
    _lawyersError = null;
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

  /// قبل الطلب كل المحامين دبابيس (`LawyerPinsLayer`): محامين الخريطة حسب القرب، والقريبين، والمختار
  List<MapLawyer> get _pinLawyers {
    final selected = _selectedLawyer;
    final all = {for (final lawyer in _mapLawyers.lawyers) lawyer.id: lawyer};
    for (final lawyer in _nearbyLawyers) {
      all.putIfAbsent(lawyer.id, () => lawyer);
    }
    if (selected != null) all[selected.id] = selected;
    return all.values.toList();
  }

  /// أثناء الطلب بس: كارت المحامي المعني على الخريطة
  List<Marker> _buildLawyerMarkers(double zoom) {
    if (_orderFlowStage == _OrderFlowStage.idle) return const [];
    final nearestId = _nearestLawyerId;
    final scale = mapCardScaleFor(zoom);
    final selected = _selectedLawyer;
    final shown = <String, MapLawyer>{
      for (final lawyer in _nearbyLawyers) lawyer.id: lawyer,
      if (selected != null) selected.id: selected,
    };

    return [
      for (final lawyer in shown.values)
        Marker(
          point: lawyer.position,
          width: _TrackingScreenState._cardWidth * scale,
          height: _TrackingScreenState._cardHeight * scale,
          alignment: Alignment.topCenter,
          child: GestureDetector(
            onTap: () => _onLawyerTapped(lawyer),
            child: ScaledMapCard(
              width: _TrackingScreenState._cardWidth,
              height: _TrackingScreenState._cardHeight,
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
    _focusPoint(_searchCenter, appMapStartZoom);
  }

  void _showMessage(String message) {
    showAppMessage(context, 
      SnackBar(content: Text(message, style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback))),
    );
  }
}
