part of 'tracking_screen.dart';

extension _TrackingOrderFlow on _TrackingScreenState {
  void _setReviewsVisible(bool visible) {
    _update(() {
      _showReviews = visible;
      if (!visible) _reviewsLawyerId = null;
    });
  }

  void _showOfferReviews(RequestOffer offer) {
    _reviewsLawyerId = offer.lawyerId;
    _setReviewsVisible(true);
  }

  /// «عرض الملف» في كارت العرض: ملف المحامي، والسهم يرجع للعروض
  void _showOfferProfile(RequestOffer offer) {
    final lawyer = _nearbyLawyers.where((item) => item.id == offer.lawyerId).firstOrNull;
    if (lawyer == null) return _showOfferReviews(offer);
    _update(() {
      _selectedLawyer = lawyer;
      _isViewingLawyer = true;
    });
  }

  /// «اطلب عروض أسعار»: الموكل يشوف حدود السعر قبل ما الطلب يتبعت
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
    // «بحث جديد» بعد ما الطلب اتقفل بيبعت من نفس صفحة الانتظار
    if (!mounted || (_orderFlowStage != _OrderFlowStage.priceApproval && !_noOffers)) return;
    final position = location.position;
    if (position == null) {
      _showMessage(location.errorMessage ?? 'تعذر تحديد موقعك، حاول تاني');
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
        _noOffers = false;
        _orderFlowStage = _OrderFlowStage.idle;
      });
      _showMessage(res.error ?? 'تعذر إرسال طلبك، يرجى المحاولة مرة أخرى');
      return;
    }

    _activeRequestId = requestId;
    _update(() {
      _activeRequest = null;
      _noOffers = false;
      _orderFlowStage = _OrderFlowStage.waitingOffers;
    });
    _followRequest(requestId);
  }

  void _followRequest(String requestId) {
    _followedRequestId = requestId;
    LiveUpdates.changes.removeListener(_checkRequest);
    LiveUpdates.changes.addListener(_checkRequest);
    _orderPollTimer?.cancel();
    // احتياطي لو الخط المفتوح قطع
    _orderPollTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (isAppVisible) _checkRequest();
    });
    _checkRequest();
  }

  void _stopFollowingRequest() {
    _followedRequestId = null;
    LiveUpdates.changes.removeListener(_checkRequest);
    _orderPollTimer?.cancel();
    _roundEndTimer?.cancel();
  }

  Future<void> _checkRequest() async {
    final requestId = _followedRequestId;
    if (requestId == null || _isCheckingRequest || !mounted) return;
    _isCheckingRequest = true;
    final res = await RequestRepository.follow(requestId);
    _isCheckingRequest = false;
    final request = res.data;
    if (!mounted || !res.isOk || request == null || _followedRequestId != requestId) return;

    if (!request.isOpen) {
      _stopFollowingRequest();
      _activeRequestId = null;
      // محدش بعت عرض بعد الجولتين: الصفحة تفضل زي ما هي، بجملة توضح وزرار «بحث جديد» بيبعت طلب جديد
      if (request.status == 'NO_OFFERS') {
        _update(() {
          _activeRequest = null;
          _noOffers = true;
        });
        return;
      }
      _update(() {
        _activeRequest = null;
        _orderFlowStage = _OrderFlowStage.idle;
      });
      _showMessage(request.status == 'EXPIRED'
          ? 'الطلب اتلغى عشان ما اخترتش عرض في الوقت المحدد\nتقدر تطلب تاني'
          : 'مفيش محامي متاح دلوقتي، جرب تاني كمان شوية');
      return;
    }

    _update(() {
      _activeRequest = request;
    });
    // التحميل بيخلص لما الجولة تخلص: بعدها بثواني نسأل تاني، يا جولة جديدة يا جملة «محدش بعت عرض»
    _roundEndTimer?.cancel();
    if (request.offers.isEmpty && request.secondsLeft > 0) {
      _roundEndTimer = Timer(Duration(seconds: request.secondsLeft + 4), _checkRequest);
    }
  }

  /// «بحث جديد»: الطلب يروح للـ 10 اللي بعد الأولانيين، والمرة اللي بعدها يرجع للأقرب
  Future<void> _searchAgain() async {
    if (_isSearchingAgain) return;
    // الطلب اتقفل من غير عروض: طلب جديد بنفس البيانات، فيروح للأقرب 10
    if (_noOffers) {
      _update(() => _isSearchingAgain = true);
      await _sendRequest();
      if (mounted) _update(() => _isSearchingAgain = false);
      return;
    }
    final requestId = _activeRequestId;
    if (requestId == null) return;
    _update(() => _isSearchingAgain = true);
    final res = await RequestRepository.searchAgain(requestId);
    if (!mounted) return;
    _update(() => _isSearchingAgain = false);
    _showMessage(res.isOk ? 'بعتنا طلبك لمحامين تانيين قريبين منك' : (res.error ?? 'تعذر البحث، حاول تاني'));
    if (res.isOk) await _checkRequest();
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

    _stopFollowingRequest();
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
    _stopFollowingRequest();
    _stageTimer?.cancel();
    _activeRequestId = null;
    _activeOrderId = null;
    _activeOrderNumber = null;

    _update(() {
      _activeRequest = null;
      _showReviews = false;
      _noOffers = false;
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
