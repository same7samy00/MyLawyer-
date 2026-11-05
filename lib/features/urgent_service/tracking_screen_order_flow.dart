part of 'tracking_screen.dart';

extension _TrackingOrderFlow on _TrackingScreenState {
  void _setReviewsVisible(bool visible) {
    _update(() {
      _showReviews = visible;
      if (!visible) _reviewsLawyerId = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _snapSheetTo(_expandedHeight);
    });
  }

  void _showOfferReviews(RequestOffer offer) {
    _reviewsLawyerId = offer.lawyerId;
    _setReviewsVisible(true);
  }

  /// «اطلب محامي»: الموكل يشوف حدود السعر قبل ما الطلب يتبعت
  Future<void> _startOrderFlow() async {
    _update(() {
      _orderFlowStage = _OrderFlowStage.evaluatingPrice;
    });

    final range = await RequestRepository.getRange(widget.problemTitle);
    if (!mounted || _orderFlowStage != _OrderFlowStage.evaluatingPrice) return;

    final limits = range.data;
    if (!range.isOk || limits == null) {
      _update(() {
        _orderFlowStage = _OrderFlowStage.idle;
      });
      _showMessage(range.error ?? 'تعذر تحميل حدود السعر');
      return;
    }

    _update(() {
      _minPrice = limits.$1;
      _maxPrice = limits.$2;
      _orderFlowStage = _OrderFlowStage.priceApproval;
    });
  }

  /// الطلب يروح لأقرب المحامين، والعروض تظهر أول بأول
  Future<void> _sendRequest() async {
    // الطلب بيروح لأقرب المحامين، فلازم مكان الموكل الحقيقي دلوقتي
    final location = await LocationService.instance.checkAndRequestPermission(fresh: true);
    if (!mounted || _orderFlowStage != _OrderFlowStage.priceApproval) return;
    final position = location.position;
    if (position == null) {
      _showMessage(location.errorMessage ?? 'تعذر تحديد موقعك، حاول تاني.');
      return;
    }
    _currentPosition = position;

    final res = await RequestRepository.send(
      serviceTitle: widget.problemTitle ?? 'محاميك حالاً - استشارة وحضور عاجل',
      problemType: widget.problemTitle ?? 'استشارة وتمثيل فوري',
      problemDescription: widget.problemDescription ?? 'طلب حضور عاجل واستشارة فورية من خلال خدمة محاميك حالاً',
      clientLat: position.latitude,
      clientLon: position.longitude,
      clientAddress: _locationName,
    );
    if (!mounted) return;

    final requestId = res.data;
    if (!res.isOk || requestId == null) {
      _update(() {
        _orderFlowStage = _OrderFlowStage.idle;
      });
      _showMessage(res.error ?? 'تعذر إرسال طلبك، يرجى المحاولة مرة أخرى.');
      return;
    }

    _activeRequestId = requestId;
    _update(() {
      _activeRequest = null;
      _orderFlowStage = _OrderFlowStage.waitingOffers;
    });
    _followRequest(requestId);
  }

  void _followRequest(String requestId) {
    _orderPollTimer?.cancel();
    bool isChecking = false;

    _orderPollTimer = Timer.periodic(const Duration(seconds: 4), (timer) async {
      if (!mounted || _orderFlowStage != _OrderFlowStage.waitingOffers) {
        timer.cancel();
        return;
      }
      // بطء الشبكة لا يراكم طلبات متزامنة
      if (isChecking || !isAppVisible) return;
      isChecking = true;

      final res = await RequestRepository.follow(requestId);
      isChecking = false;
      final request = res.data;
      if (!mounted || !res.isOk || request == null || _orderFlowStage != _OrderFlowStage.waitingOffers) return;

      if (!request.isOpen) {
        timer.cancel();
        _activeRequestId = null;
        _update(() {
          _activeRequest = null;
          _orderFlowStage = _OrderFlowStage.idle;
        });
        _showMessage('مفيش محامي متاح دلوقتي، جرب تاني كمان شوية');
        return;
      }

      _update(() {
        _activeRequest = request;
      });
    });
  }

  /// اختيار العرض يعمل الطلب بسعر المحامي، ويفتح الدفع
  Future<void> _chooseOffer(RequestOffer offer) async {
    final requestId = _activeRequestId;
    if (requestId == null || _isChoosingOffer) return;

    _update(() {
      _isChoosingOffer = true;
    });
    final res = await RequestRepository.select(requestId, offer.id);
    if (!mounted) return;
    _update(() {
      _isChoosingOffer = false;
    });

    final selected = res.data;
    if (!res.isOk || selected == null) {
      _showMessage(res.error ?? 'تعذر اختيار العرض');
      return;
    }

    _orderPollTimer?.cancel();
    _activeRequestId = null;
    _activeOrderId = selected.orderId;
    _activeOrderNumber = selected.orderNumber;
    final lawyer = _nearbyLawyers.where((item) => item.id == selected.lawyerId).firstOrNull;
    _update(() {
      _servicePrice = selected.price;
      _selectedLawyer = lawyer;
      _orderFlowStage = _OrderFlowStage.priceReady;
    });
    if (lawyer != null) _calculateRouteToLawyer(lawyer);
  }

  /// الرجوع من مراحل الطلب يلغي اللي ما اكتملش عشان ما يفضلش معلق عند المحامين
  void _returnToLawyerProfile() {
    final pendingRequestId = _activeRequestId;
    final pendingOrderId = _activeOrderId;
    _orderPollTimer?.cancel();
    _stageTimer?.cancel();
    _activeRequestId = null;
    _activeOrderId = null;
    _activeOrderNumber = null;

    _update(() {
      _activeRequest = null;
      _showReviews = false;
      _reviewsLawyerId = null;
      _orderFlowStage = _OrderFlowStage.idle;
      _selectedLawyer ??= _nearbyLawyers.firstOrNull;
    });

    if (pendingRequestId != null) RequestRepository.cancel(pendingRequestId);
    if (pendingOrderId != null) OrderRepository.cancelOrder(pendingOrderId);
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
