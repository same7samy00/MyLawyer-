part of 'tracking_screen.dart';

extension _TrackingScreenViews on _TrackingScreenState {
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
