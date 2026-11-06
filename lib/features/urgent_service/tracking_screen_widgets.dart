part of 'tracking_screen.dart';

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
          ? CachedNetworkImage(
              imageUrl: imageUrl,
              width: size,
              height: size,
              memCacheWidth: (size * 2).toInt(),
              memCacheHeight: (size * 2).toInt(),
              fit: BoxFit.cover,
              placeholder: (_, __) => _initials(),
              errorWidget: (_, __, ___) => _initials(),
            )
          : _initials(),
    );
  }

  Widget _initials() {
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
  }
}

/// كارت الموكل على خريطة المحامي، بنفس شكل كارت المحامي
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
/// عرض محامي: اسمه وتقييمه ومسافته وسعره
class _OfferCard extends StatelessWidget {
  final RequestOffer offer;
  final bool isBusy;
  final VoidCallback onChoose;
  final VoidCallback onProfile;

  const _OfferCard({super.key, required this.offer, required this.isBusy, required this.onChoose, required this.onProfile});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _LawyerAvatarPhoto(
                imageUrl: offer.avatarUrl,
                initials: offer.name.isEmpty ? 'م' : offer.name.characters.first,
                fallbackColor: AppColors.primary,
                size: 44,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      offer.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.dark),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '★ ${offer.rating.toStringAsFixed(1)} • ${offer.distanceKm} كم • يوصل خلال ${offer.minutesAway} دقيقة تقريبًا',
                      style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              Text(
                '${offer.price} ج.م',
                style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(flex: 6, child: AppButton.primary(text: 'اختار العرض', height: 40, fontSize: 13, onPressed: isBusy ? null : onChoose)),
              const SizedBox(width: 8),
              Expanded(flex: 4, child: AppButton.outlined(text: 'عرض الملف', height: 40, fontSize: 12, onPressed: onProfile)),
            ],
          ),
        ],
      ),
    );
  }
}
