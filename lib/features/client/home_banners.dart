import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_pressable.dart';
import '../../core/widgets/lawyer_pin_illustration.dart';

/// بيانات بانر واحد في الرئيسية
class HomeBanner {
  final String title;
  final String body;
  final String action;
  final Widget art;
  final VoidCallback onTap;

  const HomeBanner({required this.title, required this.body, required this.action, required this.art, required this.onTap});
}

/// بانرات الرئيسية: كل بانر بياخد العرض كله، وبيتقلب لوحده للي بعده كل 5 ثواني،
/// والموكل يقدر يسحب بإيده، وتحت النقط بتقول هو فين
class HomeBannersCarousel extends StatefulWidget {
  final List<HomeBanner> banners;

  const HomeBannersCarousel({super.key, required this.banners});

  /// بانرات الموكل: «محاميك حالاً» و«استشارة سريعة»
  factory HomeBannersCarousel.client({Key? key, required VoidCallback onUrgent, required VoidCallback onConsultation}) {
    return HomeBannersCarousel(
      key: key,
      banners: [
        HomeBanner(
          title: 'محاميك حالاً',
          body: 'أقرب محامي متاح\nيوصلك في أسرع وقت',
          action: 'اطلب الآن',
          art: const LawyerPinIllustration(size: 96, white: true),
          onTap: onUrgent,
        ),
        HomeBanner(
          title: 'استشارة سريعة',
          body: 'احكي مشكلتك وادفع\nوفريقنا يكلمك خلال دقايق',
          action: 'ابدأ الاستشارة',
          art: Image.asset('assets/images/consultation_banner.png', width: 104, height: 104, fit: BoxFit.contain, cacheWidth: 312),
          onTap: onConsultation,
        ),
      ],
    );
  }

  @override
  State<HomeBannersCarousel> createState() => _HomeBannersCarouselState();
}

class _HomeBannersCarouselState extends State<HomeBannersCarousel> {
  static const _interval = Duration(seconds: 5);
  final _controller = PageController();
  final _page = ValueNotifier<int>(0);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _restartTimer();
  }

  void _restartTimer() {
    _timer?.cancel();
    if (widget.banners.length < 2) return;
    _timer = Timer.periodic(_interval, (_) {
      if (!_controller.hasClients) return;
      final next = (_page.value + 1) % widget.banners.length;
      _controller.animateToPage(next, duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 150,
          child: LayoutBuilder(
            // البانر بيخرج 6 بكسل من كل ناحية برا هامش الصفحة، عشان المسافة اللي بين البانرات ما تصغرش عرضه
            builder: (context, constraints) => OverflowBox(
              maxWidth: constraints.maxWidth + 12,
              minWidth: constraints.maxWidth + 12,
              maxHeight: 150,
              minHeight: 150,
              child: SizedBox(
                height: 150,
                child: NotificationListener<ScrollStartNotification>(
                  // لو الموكل سحب بإيده، العداد يبدأ من الأول
                  onNotification: (notification) {
                    if (notification.dragDetails != null) _restartTimer();
                    return false;
                  },
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: widget.banners.length,
                    onPageChanged: (index) => _page.value = index,
                    // مسافة بين كل بانر والتاني وهي بتتقلب، فمش لازقين في بعض
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: _BannerCard(banner: widget.banners[index]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (widget.banners.length > 1) ...[
          const SizedBox(height: 8),
          ValueListenableBuilder<int>(
            valueListenable: _page,
            builder: (context, page, _) => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < widget.banners.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == page ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == page ? AppColors.primary : AppColors.cardBorder,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _BannerCard extends StatelessWidget {
  final HomeBanner banner;

  const _BannerCard({required this.banner});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 10, 12),
      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(7.0)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  banner.title,
                  style: const TextStyle(
                      fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white,),
                ),
                const SizedBox(height: 4),
                Text(
                  banner.body,
                  maxLines: 2,
                  style: const TextStyle(
                      fontFamily: 'AppFont',
                      fontFamilyFallback: appFontFallback,
                      fontSize: 12,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primaryLight,),
                ),
                const SizedBox(height: 10),
                AppPressable(
                  child: ElevatedButton(
                    onPressed: banner.onTap,
                    style: ElevatedButton.styleFrom(
                      overlayColor: Colors.transparent,
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                      minimumSize: const Size(96, 34),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7.0)),
                    ),
                    child: Text(
                      banner.action,
                      style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          banner.art,
        ],
      ),
    );
  }
}
