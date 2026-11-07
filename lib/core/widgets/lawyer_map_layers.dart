import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../constants/app_colors.dart';
import '../services/map_lawyer_loader.dart';

/// الدبابيس الصغيرة: كلها مرسومة رسمة واحدة على الخريطة مش widget لكل دبوس، فآلاف منها ما بتعلّقش الموبايل
class LawyerPinsLayer extends StatelessWidget {
  final Iterable<LawyerSpot> pins;
  const LawyerPinsLayer({super.key, required this.pins});

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    return MobileLayerTransformer(
      child: IgnorePointer(
        child: CustomPaint(
          size: Size.infinite,
          painter: _PinsPainter(camera, pins.toList(growable: false)),
        ),
      ),
    );
  }
}

class _PinsPainter extends CustomPainter {
  final MapCamera camera;
  final List<LawyerSpot> pins;
  _PinsPainter(this.camera, this.pins);

  static final Paint _fill = Paint()..color = AppColors.primary;
  static final Paint _edge = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;
  static final Paint _dot = Paint()..color = Colors.white;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = camera.pixelOrigin;
    final bounds = camera.visibleBounds;
    for (final pin in pins) {
      if (!bounds.contains(pin.position)) continue;
      final p = camera.project(pin.position) - origin;
      // A place with more lawyers gets a slightly bigger pin
      final r = pin.count >= 10 ? 6.5 : pin.count >= 3 ? 5.5 : 4.5;
      final tip = Offset(p.x.toDouble(), p.y.toDouble());
      final head = tip.translate(0, -r * 2.2);
      final path = Path()
        ..moveTo(tip.dx, tip.dy)
        ..quadraticBezierTo(head.dx - r * 1.1, head.dy + r * 0.9, head.dx - r, head.dy)
        ..arcToPoint(Offset(head.dx + r, head.dy), radius: Radius.circular(r))
        ..quadraticBezierTo(head.dx + r * 1.1, head.dy + r * 0.9, tip.dx, tip.dy)
        ..close();
      canvas.drawPath(path, _fill);
      canvas.drawPath(path, _edge);
      canvas.drawCircle(head, r * 0.38, _dot);
    }
  }

  @override
  bool shouldRepaint(_PinsPainter old) => old.pins != pins || old.camera != camera;
}

/// بعيد: دايرة فيها عدد المحامين في المنطقة، ولمسها بيقرّب عليها
List<Marker> lawyerCountMarkers(Iterable<LawyerSpot> counts, void Function(LatLng) onTap) {
  return [
    for (final spot in counts)
      Marker(
        point: spot.position,
        width: 64,
        height: 64,
        child: GestureDetector(
          onTap: () => onTap(spot.position),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.92),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
            ),
            child: FittedBox(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  spot.count >= 1000 ? '${(spot.count / 1000).toStringAsFixed(spot.count >= 10000 ? 0 : 1)}K' : '${spot.count}',
                  style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ),
  ];
}
