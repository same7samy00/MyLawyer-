part of 'tracking_screen.dart';

extension _TrackingOrderFlow on _TrackingScreenState {
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
        _update(() {
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
            _update(() {
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

    _update(() {
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
      _update(() {
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
    _update(() {
      _nearbyLawyers = remaining;
      _currentLawyerIndex = 0;
    });

    await _calculateRouteToLawyer(next);
    if (!mounted || _orderFlowStage != _OrderFlowStage.lawyerDeclined) return;

    _zoomFitRouteAndLawyer(_searchCenter, next.position);
    await _sendOrder();
  }

  void _setReviewsVisible(bool visible) {
    _update(() {
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
    _update(() {
      _orderFlowStage = _OrderFlowStage.evaluatingPrice;
    });

    final results = await Future.wait([
      OrderRepository.getQuote(widget.problemTitle),
      Future<void>.delayed(const Duration(milliseconds: 1800)),
    ]);
    if (!mounted || _orderFlowStage != _OrderFlowStage.evaluatingPrice) return;

    final quote = results[0] as ApiResponse<int>;
    if (!quote.isOk) {
      _update(() {
        _orderFlowStage = _OrderFlowStage.idle;
      });
      _showMessage(quote.error ?? 'تعذر تقييم سعر الخدمة');
      return;
    }

    _update(() {
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
      _update(() {
        _orderFlowStage = _OrderFlowStage.idle;
      });
      _showMessage(res.error ?? 'تعذر إرسال طلبك، يرجى المحاولة مرة أخرى.');
      return;
    }

    _activeOrderId = order.id;
    _activeOrderNumber = order.orderNumber;
    _update(() {
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

    _update(() {
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
}
