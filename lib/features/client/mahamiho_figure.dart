import 'package:flutter/material.dart';

/// حالة محاميحو: بيشاور أول ما يظهر، وبيفكّر والموكل بيكتب أو بيتكلم، و«تمام» لما يخلص، وواقف بين ده وده
enum MahamihoMood {
  wave('wave'),
  thinking('thinking'),
  ok('ok'),
  idle('idle');

  final String file;
  const MahamihoMood(this.file);

  String get asset => 'assets/mahamiho/$file.webp';

  /// مدة الحركة الواحدة (48 لقطة × 83 مللي ثانية)
  static const Duration clip = Duration(milliseconds: 4000);
}

/// محاميحو نفسه. [halfBody] بيقص من تحت بس (من الراس لحد الحزام)، ونص الجزء الظاهر من تحت بيختفي في أبيض.
/// من غير قص على الجناب أبدًا: الصورة واخدة كل حركات الإيدين
class MahamihoFigure extends StatelessWidget {
  final MahamihoMood mood;

  /// عرض الصورة، والطول على قده
  final double width;
  final bool halfBody;

  const MahamihoFigure({super.key, required this.mood, required this.width, this.halfBody = false});

  /// نسبة الطول للعرض في ملفات الحركات
  static const double ratio = 440 / 212;

  /// الجزء الظاهر من الطول في نص الجسم
  static const double halfShown = 0.56;

  static void precache(BuildContext context) {
    final config = createLocalImageConfiguration(context);
    for (final mood in MahamihoMood.values) {
      AssetImage(mood.asset).resolve(config);
    }
  }

  @override
  Widget build(BuildContext context) {
    final full = width * ratio;
    final image = Image.asset(
      mood.asset,
      key: ValueKey(mood),
      width: width,
      height: full,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
    );
    if (!halfBody) return SizedBox(width: width, height: full, child: image);

    final shown = full * halfShown;
    return SizedBox(
      width: width,
      height: shown,
      child: Stack(
        children: [
          ClipRect(
            child: OverflowBox(
              alignment: Alignment.topCenter,
              minHeight: full,
              maxHeight: full,
              child: image,
            ),
          ),
          // نص الجزء الظاهر من تحت بيختفي في الأبيض
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: shown * 0.5,
            child: const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00FFFFFF), Colors.white],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
