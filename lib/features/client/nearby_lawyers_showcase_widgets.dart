part of 'nearby_lawyers_showcase_screen.dart';

/// دبوس المحامي المربع الاحترافي على الخريطة الترويجية (مطابق لـ TrackingScreen لمنع أي Overflow)
class _ShowcaseLawyerPin extends StatelessWidget {
  final MapLawyer lawyer;
  final bool isSelected;
  final bool isNearest;

  const _ShowcaseLawyerPin({
    required this.lawyer,
    required this.isSelected,
    this.isNearest = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color badgeBg = isSelected ? AppColors.dark : Colors.white;
    final Color borderColor = isSelected ? AppColors.primary : Colors.transparent;
    final double borderWidth = isSelected ? 2.0 : 0.0;

    return CustomPaint(
      painter: _ShowcaseBubblePainter(
        color: badgeBg,
        borderColor: borderColor,
        borderWidth: borderWidth,
        hasBorder: isSelected,
        isSelected: isSelected,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ShowcaseAvatarPhoto(
              imageUrl: lawyer.imageUrl,
              initials: lawyer.avatarInitials,
              fallbackColor: lawyer.avatarColor,
              size: 28,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          lawyer.name,
                          style: TextStyle(
                            fontFamily: 'AppFont',
                            fontFamilyFallback: appFontFallback,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? Colors.white : AppColors.dark,
                          ),
                          maxLines: 1,
                        ),
                      ),
                      if (isNearest) ...[
                        const SizedBox(width: 4),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.success,
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
                        style: TextStyle(
                          fontFamily: 'AppFont',
                          fontFamilyFallback: appFontFallback,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.white70 : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// رسام فيكتور لعلامة المحامي مع السهم والظلال الناعمة
class _ShowcaseBubblePainter extends CustomPainter {
  final Color color;
  final Color borderColor;
  final double borderWidth;
  final bool hasBorder;
  final bool isSelected;

  _ShowcaseBubblePainter({
    required this.color,
    required this.borderColor,
    this.borderWidth = 1.2,
    this.hasBorder = true,
    this.isSelected = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double notchHeight = 5.0;
    const double notchWidth = 10.0;
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

    canvas.drawShadow(
      path,
      Colors.black.withOpacity(isSelected ? 0.28 : 0.16),
      isSelected ? 5.0 : 3.5,
      false,
    );

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

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
  bool shouldRepaint(covariant _ShowcaseBubblePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.borderWidth != borderWidth ||
        oldDelegate.hasBorder != hasBorder ||
        oldDelegate.isSelected != isSelected;
  }
}

/// صورة المحامي الدائرية/المربعة بحواف 7.0px مع معالجة التحميل والأخطاء بدون تمدد أو overflow
class _ShowcaseAvatarPhoto extends StatelessWidget {
  final String imageUrl;
  final String initials;
  final Color fallbackColor;
  final double size;

  const _ShowcaseAvatarPhoto({
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
                return _buildFallback();
              },
              errorBuilder: (context, error, stackTrace) {
                return _buildFallback();
              },
            )
          : _buildFallback(),
    );
  }

  Widget _buildFallback() {
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

