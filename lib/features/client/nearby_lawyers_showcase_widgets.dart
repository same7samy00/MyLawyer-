part of 'nearby_lawyers_showcase_screen.dart';

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
          ? CachedNetworkImage(
              imageUrl: imageUrl,
              width: size,
              height: size,
              // العرض بس، فالصورة تفضل بنسبتها وتتقص من النص (تحديد الطول كمان كان بيمطها)
              memCacheWidth: (size * 3).toInt(),
              fit: BoxFit.cover,
              placeholder: (_, __) => _buildFallback(),
              errorWidget: (_, __, ___) => _buildFallback(),
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

