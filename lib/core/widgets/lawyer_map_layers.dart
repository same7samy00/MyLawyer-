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

/// المحامي اللي يمثّل كل مكان على الخريطة: لو كذا محامي في نفس المكان دبوس واحد بس،
/// المختار ليه الأولوية دايمًا، وبعده الأعلى تقييمًا. الرسم واللمس الاتنين بيستخدموها فاللي يتلمس هو اللي مرسوم
List<MapLawyer> pinSpots(Iterable<MapLawyer> lawyers, String? selectedId) {
  final spots = <LatLng, MapLawyer>{};
  for (final lawyer in lawyers) {
    final there = spots[lawyer.position];
    if (there == null || (there.id != selectedId && (lawyer.id == selectedId || lawyer.rating > there.rating))) {
      spots[lawyer.position] = lawyer;
    }
  }
  return spots.values.toList(growable: false);
}

/// المحامي اللي اتلمس دبوسه (لحد 28 نقطة من الصباع)، أو null
MapLawyer? lawyerAtTap(MapCamera camera, LatLng tap, Iterable<MapLawyer> lawyers, {String? selectedId}) {
  final at = camera.project(tap);
  MapLawyer? best;
  var bestDistance = 28.0;
  for (final lawyer in pinSpots(lawyers, selectedId)) {
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
  static final Paint _dot = Paint()..color = Colors.white;
  static final Paint _shade = Paint()..color = const Color(0x2E000000);
  static final Paint _normal = Paint()..color = AppColors.primary;
  static final Paint _picked = Paint()..color = AppColors.success;
  static final Paint _labelBack = Paint()..color = const Color(0xF2FFFFFF);
  static final Map<double, Path> _shapes = {};
  /// The names are laid out once and kept, not on every frame while the map moves
  static final Map<String, TextPainter> _names = {};

  /// A simple pin, its tip at (0, 0)
  static Path _shape(double r) => _shapes.putIfAbsent(r, () {
        final head = Offset(0, -r * 2.1);
        return Path()
          ..moveTo(0, 0)
          ..quadraticBezierTo(head.dx - r * 1.05, head.dy + r * 0.95, head.dx - r, head.dy)
          ..arcToPoint(Offset(head.dx + r, head.dy), radius: Radius.circular(r))
          ..quadraticBezierTo(head.dx + r * 1.05, head.dy + r * 0.95, 0, 0)
          ..close();
      });

  static TextPainter _name(String name) {
    if (_names.length > 400) _names.clear();
    return _names.putIfAbsent(name, () => TextPainter(
          text: TextSpan(text: name, style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.dark)),
          textDirection: TextDirection.rtl,
          maxLines: 1,
          ellipsis: '…',
        )..layout(maxWidth: 120),);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final origin = camera.pixelOrigin;
    final bounds = camera.visibleBounds;
    // Lawyers on the same spot share one pin, the same one a tap picks
    final pins = <(MapLawyer, Offset)>[
      for (final lawyer in pinSpots(lawyers.where((l) => bounds.contains(l.position)), selectedId)) (lawyer, () {
        final p = camera.project(lawyer.position) - origin;
        return Offset(p.x.toDouble(), p.y.toDouble());
      }()),
    ];

    MapEntry<MapLawyer, Offset>? selected;
    for (final (lawyer, tip) in pins) {
      if (lawyer.id == selectedId) {
        selected = MapEntry(lawyer, tip);
        continue;
      }
      _pin(canvas, tip, 8, _normal);
    }

    // Names next to the spots nearest the middle of the screen, never two names on top of each other
    if (labels > 0) {
      final c = camera.project(camera.center) - origin;
      final middle = Offset(c.x.toDouble(), c.y.toDouble());
      final byCenter = [...pins]..sort((a, b) => (a.$2 - middle).distanceSquared.compareTo((b.$2 - middle).distanceSquared));
      final taken = <Rect>[];
      for (final (lawyer, tip) in byCenter) {
        if (taken.length >= labels) break;
        final text = _name(lawyer.name);
        final box = Rect.fromLTWH(tip.dx + 10, tip.dy - 17 - text.height / 2, text.width + 8, text.height + 2);
        if (taken.any((other) => other.overlaps(box))) continue;
        taken.add(box);
        canvas.drawRRect(RRect.fromRectAndRadius(box, const Radius.circular(4)), _labelBack);
        text.paint(canvas, box.topLeft + const Offset(4, 1));
      }
    }

    // The selected lawyer on top and bigger
    if (selected != null) _pin(canvas, selected.value, 12, _picked);
  }

  void _pin(Canvas canvas, Offset tip, double r, Paint fill) {
    final shape = _shape(r);
    canvas.drawOval(Rect.fromCenter(center: tip, width: r * 1.2, height: r * 0.5), _shade);
    canvas.save();
    canvas.translate(tip.dx, tip.dy);
    canvas.drawPath(shape, fill);
    canvas.drawPath(shape, _edge);
    canvas.drawCircle(Offset(0, -r * 2.1), r * 0.36, _dot);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PinsPainter old) => old.lawyers != lawyers || old.camera != camera || old.selectedId != selectedId || old.labels != labels;
}
