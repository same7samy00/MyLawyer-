import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../../data/models/map_lawyer.dart';
import '../constants/app_colors.dart';

/// المحامين على الخريطة كنقط وفوق كل نقطة تقييمه: كلهم مرسومين رسمة واحدة مش widget لكل محامي،
/// والنصوص محفوظة جاهزة، فالخريطة بتفضل ناعمة مهما كان العدد. لمس النقطة بيفتح كارت المحامي (`lawyerAtTap`).
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
    // The dot sits on its point, its rating just above it
    final d = math.sqrt(math.pow(p.x - at.x, 2) + math.pow(p.y - 6 - at.y, 2));
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
  static final Paint _shade = Paint()..color = const Color(0x2E000000);
  static final Paint _normal = Paint()..color = AppColors.primary;
  static final Paint _picked = Paint()..color = AppColors.success;
  static final Paint _rateBack = Paint()..color = Colors.white;
  static final Paint _rateEdge = Paint()
    ..color = const Color(0x1F0F172A)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;
  /// The names are laid out once and kept, not on every frame while the map moves
  static final Map<String, TextPainter> _names = {};
  /// One prepared label per rating («★ 4.8»), about 40 in all, shared by every lawyer
  static final Map<int, TextPainter> _rates = {};

  static TextPainter _rate(double rating) {
    final tenths = (rating * 10).round();
    return _rates.putIfAbsent(tenths, () => TextPainter(
          text: TextSpan(children: [
            const TextSpan(text: '★ ', style: TextStyle(fontSize: 10, color: Color(0xFFF59E0B))),
            TextSpan(text: (tenths / 10).toStringAsFixed(1), style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.dark)),
          ],),
          textDirection: TextDirection.ltr,
        )..layout(),);
  }

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
    for (final (lawyer, point) in pins) {
      if (lawyer.id == selectedId) {
        selected = MapEntry(lawyer, point);
        continue;
      }
      _dotAt(canvas, point, 6, _normal);
    }

    // A label (name, then rating under it) above one lawyer per square of the map. The squares are fixed
    // on the map itself at whole zoom steps, so moving or pinching the map never swaps labels mid-gesture:
    // they change only when the zoom crosses a whole level
    final step = camera.zoom.floorToDouble();
    final best = <int, (MapLawyer, Offset)>{};
    for (final entry in pins) {
      final lawyer = entry.$1;
      if (lawyer.id == selectedId) continue;
      final world = camera.crs.latLngToPoint(lawyer.position, step);
      final cell = (world.x / _cellWidth).floor() * 1000003 + (world.y / _cellHeight).floor();
      final there = best[cell];
      if (there == null || lawyer.rating > there.$1.rating || (lawyer.rating == there.$1.rating && lawyer.id.compareTo(there.$1.id) < 0)) {
        best[cell] = entry;
      }
    }
    for (final (lawyer, point) in best.values) {
      _label(canvas, lawyer, point, 6);
    }

    // The selected lawyer on top and bigger, always with its label
    if (selected != null) {
      _dotAt(canvas, selected.value, 9, _picked);
      _label(canvas, selected.key, selected.value, 9);
    }
  }

  static const double _cellWidth = 130;
  static const double _cellHeight = 56;

  /// The name, with the rating under it, upright above the dot
  void _label(Canvas canvas, MapLawyer lawyer, Offset point, double r) {
    final name = _name(lawyer.name);
    final rate = lawyer.rating > 0 ? _rate(lawyer.rating) : null;
    final width = math.max(name.width, rate?.width ?? 0) + 12;
    final height = name.height + (rate == null ? 0 : rate.height) + 4;
    canvas.save();
    canvas.translate(point.dx, point.dy);
    // The map may turn, the words stay level
    canvas.rotate(-camera.rotationRad);
    final box = Rect.fromLTWH(-width / 2, -r - 5 - height, width, height);
    final rounded = RRect.fromRectAndRadius(box, const Radius.circular(7));
    canvas.drawRRect(rounded, _rateBack);
    canvas.drawRRect(rounded, _rateEdge);
    name.paint(canvas, Offset(-name.width / 2, box.top + 2));
    rate?.paint(canvas, Offset(-rate.width / 2, box.top + 2 + name.height));
    canvas.restore();
  }

  void _dotAt(Canvas canvas, Offset point, double r, Paint fill) {
    canvas.drawCircle(point.translate(0, 1), r + 1.5, _shade);
    canvas.drawCircle(point, r, fill);
    canvas.drawCircle(point, r, _edge);
  }

  @override
  bool shouldRepaint(_PinsPainter old) => old.lawyers != lawyers || old.camera != camera || old.selectedId != selectedId || old.labels != labels;
}
