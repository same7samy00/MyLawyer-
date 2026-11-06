part of 'tracking_screen.dart';

extension _TrackingScreenViews on _TrackingScreenState {
  /// قبل الطلب: ملخص المحامين القريبين وزرار واحد بيبعت الطلب لأقرب 5. ملف المحامي بيظهر لما تلمس كارته بس
  Widget _buildLawyerProfileCard() {
    return AppSwitcher(
      child: _isViewingLawyer && _selectedLawyer != null ? _buildChosenLawyer() : _buildNearbySummary(),
    );
  }

  Widget _buildNearbySummary() {
    if (!_isLoading && _nearbyLawyers.isEmpty) {
      return KeyedSubtree(
        key: const ValueKey('no_lawyers'),
        child: AppStateMessage(
          icon: _lawyersError != null ? Icons.wifi_off_rounded : Icons.person_search_rounded,
          title: _lawyersError != null ? 'تعذر تحميل المحامين' : 'لا يوجد محامون متاحون حالياً',
          message: _lawyersError,
          onRetry: _fetchCurrentLocation,
        ),
      );
    }
    if (_isLoading) return const SheetLoading(key: ValueKey('loading_lawyers'), text: 'جاري البحث عن المحامين القريبين');

    final lawyers = [..._nearbyLawyers]..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return Column(
      key: const ValueKey('nearby_summary'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${lawyers.length} محامي متاح قريب منك',
          style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.dark),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 128,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: lawyers.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) => _buildNearbyLawyerCard(lawyers[i]),
          ),
        ),
        const SizedBox(height: 14),
        AppButton.primary(
          text: 'اطلب عروض أسعار',
          icon: Icons.send_rounded,
          height: 48,
          fontSize: 14,
          onPressed: _startOrderFlow,
        ),
        const SizedBox(height: 8),
        const Text(
          'طلبك هيوصل لأقرب 5 محامين، وانت تختار العرض اللي يناسبك',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 12, height: 1.4, color: AppColors.textMuted),
        ),
      ],
    );
  }

  /// كارت محامي صغير في صف القريبين، لمسه بيفتح ملفه
  Widget _buildNearbyLawyerCard(MapLawyer lawyer) {
    final distance = lawyer.distanceMeters < 1000
        ? '${lawyer.distanceMeters.round()} م'
        : '${(lawyer.distanceMeters / 1000).toStringAsFixed(1)} كم';
    const small = TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textMuted);
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(7.0),
        side: BorderSide(color: lawyer.id == _nearestLawyerId ? AppColors.primary : AppColors.cardBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(7.0),
        onTap: () => _onLawyerTapped(lawyer),
        child: SizedBox(
          width: 118,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                _LawyerAvatarPhoto(imageUrl: lawyer.imageUrl, initials: lawyer.avatarInitials, fallbackColor: lawyer.avatarColor, size: 46),
                const SizedBox(height: 6),
                Text(
                  lawyer.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.dark),
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF5B301)),
                    Flexible(
                      child: Text(' ${lawyer.rating.toStringAsFixed(1)}  ·  $distance', maxLines: 1, overflow: TextOverflow.ellipsis, style: small),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// ملف محامي لمسته على الخريطة، للتعرف عليه بس
  Widget _buildChosenLawyer() {
    return Column(
      key: ValueKey('lawyer_${_selectedLawyer!.id}'),
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
        const SizedBox(height: 10),
        AppButton.outlined(text: 'رجوع', height: 44, onPressed: _closeLawyerProfile),
      ],
    );
  }

  Widget _buildOrderFlowContent() {
    return AppSwitcher(child: _buildStageWidget());
  }

  Widget _buildStageWidget() {
    switch (_orderFlowStage) {
      case _OrderFlowStage.idle:
        return const SizedBox.shrink();

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
              'جاري تجهيز طلبك',
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
              'السعر المتوقع',
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
              'من $_minPrice لـ $_maxPrice ج.م',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'AppFont',
                fontFamilyFallback: appFontFallback,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: AppColors.dark,
              ),
            ),
            const Text(
              'أقرب المحامين هيبعتولك أسعارهم، وإنت تختار',
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
                  child: AppButton.primary(text: 'ابعت الطلب', height: 48, onPressed: _sendRequest),
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

      case _OrderFlowStage.waitingOffers:
        final offers = _activeRequest?.offers ?? const <RequestOffer>[];
        return Column(
          key: const ValueKey('stage_waiting_offers'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              offers.isEmpty ? 'مستنيين عروض المحامين' : 'اختار العرض المناسب ليك',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'AppFont',
                fontFamilyFallback: appFontFallback,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: AppColors.dark,
              ),
            ),
            const SizedBox(height: 10),
            if (offers.isEmpty && (_activeRequest?.secondsLeft ?? 120) > 0)
              ResponseCountdown(
                key: ValueKey('round-${_activeRequest?.round ?? 1}'),
                secondsLeft: _activeRequest?.secondsLeft ?? 120,
              ),
            if (offers.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'لو ما اخترتش خلال ${_activeRequest?.chooseMinutesLeft ?? 0} دقيقة، الطلب هيتلغي',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'AppFont',
                    fontFamilyFallback: appFontFallback,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.danger,
                  ),
                ),
              ),
            for (final offer in offers)
              _OfferCard(
                key: ValueKey(offer.id),
                offer: offer,
                isBusy: _isChoosingOffer,
                onChoose: () => _chooseOffer(offer),
                onReviews: () => _showOfferReviews(offer),
              ),
            const SizedBox(height: 10),
            AppButton.outlined(text: 'إلغاء الطلب', height: 46, onPressed: _returnToLawyerProfile),
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
                  'إلغاء الطلب',
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
