import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../../data/models/map_lawyer.dart';
import '../constants/app_colors.dart';

/// المحامين على الخريطة كدبابيس زي أماكن جوجل ماب: كلهم مرسومين رسمة واحدة مش widget لكل محامي،
/// فالخريطة بتفضل ناعمة مهما كان العدد. لمس الدبوس بيفتح كارت المحامي في الشيت (`lawyerAtTap`).
class LawyerPinsLayer extends StatelessWidget {
  final Iterable<MapLawyer> lawyers;
  final String? selectedId;

  /// من الزوم ده، أقرب [labels] محامي لنص الشاشة جنبهم اسمهم
  final double labelsFromZoom;
  final int labels;

  const LawyerPinsLayer({super.key, required this.lawyers, this.selectedId, this.labelsFromZoom = 14, this.labels = 10});

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    return MobileLayerTransformer(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: CustomPaint(
            size: Size.infinite,
            painter: _PinsPainter(camera, lawyers.toList(growable: false), selectedId, camera.zoom >= labelsFromZoom ? labels : 0),
          ),
        ),
      ),
    );
  }
}

/// المحامي اللي اتلمس دبوسه (لحد 28 نقطة من الصباع)، أو null
MapLawyer? lawyerAtTap(MapCamera camera, LatLng tap, Iterable<MapLawyer> lawyers) {
  final at = camera.project(tap);
  MapLawyer? best;
  var bestDistance = 28.0;
  for (final lawyer in lawyers) {
    final p = camera.project(lawyer.position);
    // The pin's head sits above its point
    final d = math.sqrt(math.pow(p.x - at.x, 2) + math.pow(p.y - 12 - at.y, 2));
    if (d < bestDistance) {
      bestDistance = d;
      best = lawyer;
    }
  }
  return best;
}

class _PinsPainter extends CustomPainter {
  final MapCamera camera;
  final List<MapLawyer> lawyers;
  final String? selectedId;
  final int labels;
  _PinsPainter(this.camera, this.lawyers, this.selectedId, this.labels);

  static final Paint _edge = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  static final Paint _shade = Paint()..color = const Color(0x33000000);
  static final Map<String, TextPainter> _letters = {};

  /// أعلى تقييم أغمق
  static Color _colorFor(double rating) => rating >= 4.5 ? AppColors.primary : rating >= 4 ? const Color(0xFF3B82F6) : const Color(0xFF64748B);

  static TextPainter _letter(String text) => _letters.putIfAbsent(text, () => TextPainter(
        text: TextSpan(text: text, style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
        textDirection: TextDirection.rtl,
      )..layout(),);

  @override
  void paint(Canvas canvas, Size size) {
    final origin = camera.pixelOrigin;
    final bounds = camera.visibleBounds;
    final center = camera.project(camera.center) - origin;
    final visible = <(MapLawyer, Offset)>[];
    for (final lawyer in lawyers) {
      if (!bounds.contains(lawyer.position)) continue;
      final p = camera.project(lawyer.position) - origin;
      visible.add((lawyer, Offset(p.x.toDouble(), p.y.toDouble())));
    }

    // The nearest to the middle of the screen get their name, like shop names on Google Maps
    final named = <String>{};
    if (labels > 0) {
      final byCenter = [...visible]..sort((a, b) => (a.$2 - Offset(center.x.toDouble(), center.y.toDouble())).distanceSquared
          .compareTo((b.$2 - Offset(center.x.toDouble(), center.y.toDouble())).distanceSquared),);
      named.addAll(byCenter.take(labels).map((v) => v.$1.id));
    }

    MapEntry<MapLawyer, Offset>? selected;
    for (final (lawyer, tip) in visible) {
      if (lawyer.id == selectedId) {
        selected = MapEntry(lawyer, tip);
        continue;
      }
      _pin(canvas, lawyer, tip, 9, named.contains(lawyer.id));
    }
    // The selected lawyer on top and bigger
    if (selected != null) _pin(canvas, selected.key, selected.value, 13, true, selected: true);
  }

  void _pin(Canvas canvas, MapLawyer lawyer, Offset tip, double r, bool withName, {bool selected = false}) {
    final head = tip.translate(0, -r * 2.1);
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..quadraticBezierTo(head.dx - r * 1.05, head.dy + r * 0.95, head.dx - r, head.dy)
      ..arcToPoint(Offset(head.dx + r, head.dy), radius: Radius.circular(r))
      ..quadraticBezierTo(head.dx + r * 1.05, head.dy + r * 0.95, tip.dx, tip.dy)
      ..close();
    canvas.drawCircle(tip, r * 0.35, _shade);
    canvas.drawPath(path, Paint()..color = selected ? AppColors.success : _colorFor(lawyer.rating));
    canvas.drawPath(path, _edge);
    final letter = _letter(lawyer.avatarInitials);
    letter.paint(canvas, head - Offset(letter.width / 2, letter.height / 2));

    if (!withName) return;
    final label = TextPainter(
      text: TextSpan(
        text: lawyer.name,
        style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.dark,
            shadows: [Shadow(color: Colors.white, blurRadius: 3), Shadow(color: Colors.white, blurRadius: 3)],),
      ),
      textDirection: TextDirection.rtl,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 120);
    label.paint(canvas, head + Offset(r + 4, -label.height / 2));
  }

  @override
  bool shouldRepaint(_PinsPainter old) => old.lawyers != lawyers || old.camera != camera || old.selectedId != selectedId || old.labels != labels;
}
