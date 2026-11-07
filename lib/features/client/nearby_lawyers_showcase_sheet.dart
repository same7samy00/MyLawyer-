part of 'nearby_lawyers_showcase_screen.dart';

extension _ShowcaseSheetViews on _NearbyLawyersShowcaseScreenState {
  Widget _buildFixedSheet() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: MeasuredSize(
        onChange: (size) {
          if ((size.height - _sheetHeight).abs() > 1) _update(() => _sheetHeight = size.height);
        },
        child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28.0)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 24, offset: const Offset(0, -6)),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppSheetHeader(
                title: _showReviews ? 'التقييمات' : _selectedLawyer != null ? 'ملف المحامي' : 'الأعلى تقييماً حولك',
                onBack: _showReviews
                    ? () => _update(() => _showReviews = false)
                    : _selectedLawyer != null
                        ? _closeLawyerProfile
                        : null,
              ),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.5),
                child: _selectedLawyer == null ? _buildTopLawyersList() : _buildLawyerProfile(_selectedLawyer!),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildTopLawyersList() {
    if (_isInitialLoading) return const SheetLoading(text: 'جاري البحث عن المحامين حواليك');
    if (_locationProblem != null) {
      return SingleChildScrollView(
        child: AppStateMessage(
          icon: Icons.location_on_rounded,
          title: 'محتاجين نحدد مكانك',
          message: 'عشان نعرضلك أعلى المحامين تقييمًا في محافظتك',
          retryText: 'حدد مكاني',
          onRetry: _enableLocation,
        ),
      );
    }
    if (_nearbyLawyers.isEmpty) {
      return const SingleChildScrollView(
        child: AppStateMessage(icon: Icons.location_on_rounded, title: 'لا يوجد محامون في محافظتك حالياً'),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      physics: const BouncingScrollPhysics(),
      itemCount: _nearbyLawyers.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final lawyer = _nearbyLawyers[index];
        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(7.0),
          child: InkWell(
            borderRadius: BorderRadius.circular(7.0),
            onTap: () => _onLawyerMarkerTapped(lawyer),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(7.0),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Row(
                children: [
                  _ShowcaseAvatarPhoto(
                    imageUrl: lawyer.imageUrl,
                    initials: lawyer.avatarInitials,
                    fallbackColor: lawyer.avatarColor,
                    size: 46,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lawyer.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'AppFont',
                            fontFamilyFallback: appFontFallback,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.dark,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${lawyer.experienceYears} سنوات خبرة • ${_distanceText(lawyer)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'AppFont',
                            fontFamilyFallback: appFontFallback,
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.star_rounded, color: Color(0xFFEAB308), size: 18),
                  const SizedBox(width: 3),
                  Text(
                    lawyer.rating.toStringAsFixed(1),
                    style: const TextStyle(
                      fontFamily: 'AppFont',
                      fontFamilyFallback: appFontFallback,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.dark,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// الإذن المرفوض نهائيًا أو الموقع المقفول بيتفتحوا من الإعدادات، والباقي بيتطلب تاني
  Future<void> _enableLocation() async {
    final problem = _locationProblem;
    if (problem == LocationServiceStatus.permissionDeniedForever) {
      await LocationService.instance.openAppSettings();
      return;
    }
    if (problem == LocationServiceStatus.serviceDisabled) {
      await Geolocator.openLocationSettings();
      return;
    }
    _update(() => _isInitialLoading = true);
    await _fetchCurrentLocation();
  }

  String _distanceText(MapLawyer lawyer) {
    final meters = lawyer.distanceMeters;
    return meters < 1000 ? '${meters.round()} م' : '${(meters / 1000).toStringAsFixed(1)} كم';
  }

  Widget _buildLawyerProfile(MapLawyer lawyer) {
    if (_showReviews) {
      return Container(
        height: MediaQuery.sizeOf(context).height * 0.45,
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
        child: LawyerReviewsPanel(lawyerId: lawyer.id, onClose: () => _update(() => _showReviews = false)),
      );
    }
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LawyerProfileSummary(
            avatar: _ShowcaseAvatarPhoto(
              imageUrl: lawyer.imageUrl,
              initials: lawyer.avatarInitials,
              fallbackColor: lawyer.avatarColor,
              size: 56,
            ),
            name: lawyer.name,
            rating: lawyer.rating,
            reviewsCount: lawyer.reviewsCount,
            experienceYears: lawyer.experienceYears,
            distanceText: _distanceText(lawyer),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: AppButton.outlined(
                  text: 'ملف Google',
                  customIcon: const GoogleMark(),
                  onPressed: _openGoogleProfile,
                  height: 44,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton.outlined(
                  text: 'التقييمات (${lawyer.reviewsCount})',
                  onPressed: () => _update(() => _showReviews = true),
                  height: 44,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMapFloatingBtn({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.white,
      elevation: 3,
      shadowColor: Colors.black.withOpacity(0.12),
      borderRadius: BorderRadius.circular(7.0),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(7.0),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }
}
