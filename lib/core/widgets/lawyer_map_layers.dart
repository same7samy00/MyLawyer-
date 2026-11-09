import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../../data/models/map_lawyer.dart';
import '../constants/app_colors.dart';

/// المحامين على الخريطة: بعيد دبابيس صغيرة لكل المحامين (عادي تتراكب)، ومن زوم [cardsFromZoom] كروت صغيرة
/// على شكل دبوس (أول حرف والاسم والتقييم، والكارت ومثلثه قطعة واحدة) للأعلى تقييمًا في كل منطقة صغيرة،
/// والباقي دبابيس تحتهم. المناطق ثابتة على الخريطة وبتتغير بس مع كل درجة زوم كاملة، فمفيش رعشة.
/// كله رسمة واحدة مش widget لكل محامي، ومفيش صور على الخريطة، فالخريطة ناعمة مهما كان العدد.
/// لمس الكارت أو الدبوس بيفتح المحامي (`lawyerAtTap`).
class LawyerPinsLayer extends StatelessWidget {
  final Iterable<MapLawyer> lawyers;
  final String? selectedId;

  const LawyerPinsLayer({super.key, required this.lawyers, this.selectedId});

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    return MobileLayerTransformer(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: CustomPaint(
            size: Size.infinite,
            painter: _CardsPainter(camera, lawyers.toList(growable: false), selectedId),
          ),
        ),
      ),
    );
  }
}

/// علامة على الخريطة: المحامي، ومكانه بالبكسل في الزوم الحالي، وهل هو كارت ولا دبوس
typedef MapCard = ({MapLawyer lawyer, Offset point, bool card});

/// من الزوم ده الكروت بتظهر، وقبله دبابيس بس
const double cardsFromZoom = 14;
const double _cardHeight = 34;
const double _pointer = 6;
const double _photo = 24;
const double _pinHeight = 22;

/// العلامات الظاهرة بترتيب الرسم (الدبابيس الأول، بعدها الكروت، والمختار آخر واحد). الرسم واللمس الاتنين
/// بيستخدموها، فاللي يتلمس هو اللي مرسوم
List<MapCard> mapCards(MapCamera camera, Iterable<MapLawyer> lawyers, String? selectedId) {
  final bounds = camera.visibleBounds;
  final withCards = camera.zoom >= cardsFromZoom;
  final carded = withCards ? _cardedAt(camera, lawyers, camera.zoom.floor()) : const <String>{};
  Offset at(MapLawyer lawyer) {
    final p = camera.project(lawyer.position);
    return Offset(p.x.toDouble(), p.y.toDouble());
  }

  final pins = <MapCard>[];
  final cards = <MapCard>[];
  MapCard? selected;
  for (final lawyer in lawyers) {
    if (!bounds.contains(lawyer.position)) continue;
    if (lawyer.id == selectedId) {
      selected = (lawyer: lawyer, point: at(lawyer), card: withCards);
    } else if (carded.contains(lawyer.id)) {
      cards.add((lawyer: lawyer, point: at(lawyer), card: true));
    } else {
      pins.add((lawyer: lawyer, point: at(lawyer), card: false));
    }
  }
  return [...pins, ...cards, if (selected != null) selected];
}

/// Who gets a card, worked out once per zoom step over every loaded lawyer (not just the ones on screen),
/// so moving the map never moves a card to someone else, and the work isn't repeated every frame
List<MapLawyer>? _cardedFor;
int _cardedStep = -1;
Set<String> _carded = const {};

Set<String> _cardedAt(MapCamera camera, Iterable<MapLawyer> lawyers, int step) {
  final list = lawyers is List<MapLawyer> ? lawyers : lawyers.toList(growable: false);
  if (identical(list, _cardedFor) && step == _cardedStep) return _carded;
  // The higher rated first; every lawyer gets a card unless it would sit on a card already placed,
  // then it stays a pin under it until you zoom in more
  final order = [...list]
    ..sort((a, b) {
      final byRating = b.rating.compareTo(a.rating);
      return byRating != 0 ? byRating : a.id.compareTo(b.id);
    });
  final grid = <int, List<Rect>>{};
  final carded = <String>{};
  for (final lawyer in order) {
    final w = camera.crs.latLngToPoint(lawyer.position, step.toDouble());
    final rect = _cardRect(lawyer, Offset(w.x.toDouble(), w.y.toDouble()), 1).inflate(2);
    // Only nearby areas can touch, so only they are checked
    final gx = (w.x / 200).floor();
    final gy = (w.y / 100).floor();
    var clash = false;
    for (var dx = -1; dx <= 1 && !clash; dx++) {
      for (var dy = -1; dy <= 1 && !clash; dy++) {
        clash = (grid[(gx + dx) * 1000003 + gy + dy] ?? const []).any((other) => other.overlaps(rect));
      }
    }
    if (clash) continue;
    grid.putIfAbsent(gx * 1000003 + gy, () => []).add(rect);
    carded.add(lawyer.id);
  }
  _cardedFor = list;
  _cardedStep = step;
  return _carded = carded;
}

/// المحامي اللي اتلمس كارته، أو null. المختار والكروت اللي فوق بتتلمس الأول
MapLawyer? lawyerAtTap(MapCamera camera, LatLng tap, Iterable<MapLawyer> lawyers, {String? selectedId}) {
  final p = camera.project(tap);
  final at = Offset(p.x.toDouble(), p.y.toDouble());
  for (final mark in mapCards(camera, lawyers, selectedId).reversed) {
    final scale = mark.lawyer.id == selectedId ? 1.15 : 1.0;
    final rect = mark.card
        ? _cardRect(mark.lawyer, mark.point, scale)
        : Rect.fromCenter(center: mark.point.translate(0, -_pinHeight * scale / 2), width: 22 * scale, height: _pinHeight * scale);
    if (rect.inflate(6).contains(at)) return mark.lawyer;
  }
  return null;
}

Rect _cardRect(MapLawyer lawyer, Offset point, double scale) {
  final width = _cardWidth(lawyer) * scale;
  final height = (_cardHeight + _pointer) * scale;
  return Rect.fromLTWH(point.dx - width / 2, point.dy - height, width, height);
}

double _cardWidth(MapLawyer lawyer) {
  final text = math.max(_Texts.name(lawyer.name).width, _Texts.rate(lawyer.rating).width);
  return 7 + text + 6 + _photo + 5;
}

/// النصوص بتتجهز مرة وتتحفظ، مش في كل إطار والخريطة بتتحرك
abstract class _Texts {
  static final Map<String, TextPainter> _names = {};
  static final Map<int, TextPainter> _rates = {};
  static final Map<String, TextPainter> _letters = {};

  static TextPainter name(String name) {
    if (_names.length > 600) _names.clear();
    return _names.putIfAbsent(name, () => TextPainter(
          text: TextSpan(text: name, style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.dark)),
          textDirection: TextDirection.rtl,
          maxLines: 1,
          ellipsis: '…',
        )..layout(maxWidth: 92),);
  }

  /// «★ 4.8»، أو «جديد» لمحامي لسه ما اتقيمش
  static TextPainter rate(double rating) {
    final tenths = (rating * 10).round();
    return _rates.putIfAbsent(tenths, () => TextPainter(
          text: tenths <= 0
              ? const TextSpan(text: 'جديد', style: TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 9.5, fontWeight: FontWeight.w600, color: AppColors.textMuted))
              : TextSpan(children: [
                  const TextSpan(text: '★ ', style: TextStyle(fontSize: 9.5, color: Color(0xFFF59E0B))),
                  TextSpan(text: (tenths / 10).toStringAsFixed(1), style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 9.5, fontWeight: FontWeight.w700, color: AppColors.textMain)),
                ],),
          textDirection: TextDirection.ltr,
        )..layout(),);
  }

  static TextPainter letter(String letter) => _letters.putIfAbsent(letter, () => TextPainter(
        text: TextSpan(text: letter, style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
        textDirection: TextDirection.rtl,
      )..layout(),);
}

class _CardsPainter extends CustomPainter {
  final MapCamera camera;
  final List<MapLawyer> lawyers;
  final String? selectedId;
  _CardsPainter(this.camera, this.lawyers, this.selectedId);

  static final Paint _back = Paint()..color = Colors.white;
  // A plain offset shade, no blur: blur on every mark each frame is what makes a map heavy
  static final Paint _shadow = Paint()..color = const Color(0x1F0F172A);
  static final Paint _edge = Paint()
    ..color = const Color(0x1F0F172A)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;
  static final Paint _pickedEdge = Paint()
    ..color = AppColors.success
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  static final Paint _avatar = Paint()..color = AppColors.primary;
  static final Paint _pickedFill = Paint()..color = AppColors.success;
  static final Paint _white = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final o = camera.pixelOrigin;
    final origin = Offset(o.x.toDouble(), o.y.toDouble());
    for (final mark in mapCards(camera, lawyers, selectedId)) {
      final picked = mark.lawyer.id == selectedId;
      if (mark.card) {
        _card(canvas, mark.lawyer, mark.point - origin, picked);
      } else {
        _pin(canvas, mark.point - origin, picked);
      }
    }
  }

  static final Map<double, Path> _pins = {};

  /// A small pin, its tip on the spot
  static Path _pinShape(double h) => _pins.putIfAbsent(h, () {
        final r = h * 0.36;
        final head = Offset(0, -h + r);
        return Path()
          ..moveTo(0, 0)
          ..quadraticBezierTo(-r * 1.05, head.dy + r * 0.95, -r, head.dy)
          ..arcToPoint(Offset(r, head.dy), radius: Radius.circular(r))
          ..quadraticBezierTo(r * 1.05, head.dy + r * 0.95, 0, 0)
          ..close();
      });

  void _pin(Canvas canvas, Offset tip, bool picked) {
    final h = picked ? _pinHeight * 1.15 : _pinHeight;
    // One prepared shape moved into place, nothing new built per pin
    canvas.save();
    canvas.translate(tip.dx, tip.dy);
    final shape = _pinShape(h);
    canvas.drawPath(shape, picked ? _pickedFill : _avatar);
    canvas.drawPath(shape, _white);
    canvas.drawCircle(Offset(0, -h + h * 0.36), h * 0.13, _back);
    canvas.restore();
  }

  static final Map<int, Path> _cardShapes = {};

  /// The card and its pointer as one piece, with one outline
  static Path _cardShape(double width) => _cardShapes.putIfAbsent(width.round(), () {
        final box = Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-width / 2, -_pointer - _cardHeight, width, _cardHeight), const Radius.circular(5)));
        final pointer = Path()
          ..moveTo(-_pointer, -_pointer - 1)
          ..quadraticBezierTo(-1.5, -2, 0, 0)
          ..quadraticBezierTo(1.5, -2, _pointer, -_pointer - 1)
          ..close();
        return Path.combine(PathOperation.union, box, pointer);
      });

  void _card(Canvas canvas, MapLawyer lawyer, Offset point, bool picked) {
    final scale = picked ? 1.15 : 1.0;
    final width = _cardWidth(lawyer);
    canvas.save();
    canvas.translate(point.dx, point.dy);
    canvas.scale(scale);

    final shape = _cardShape(width);
    canvas.translate(0, 1.5);
    canvas.drawPath(shape, _shadow);
    canvas.translate(0, -1.5);
    canvas.drawPath(shape, _back);
    canvas.drawPath(shape, picked ? _pickedEdge : _edge);

    // The first letter of the name on the right. The photo shows in the lawyer's card, not on the map
    final box = Rect.fromLTWH(-width / 2, -_pointer - _cardHeight, width, _cardHeight);
    final photoCenter = Offset(box.right - 5 - _photo / 2, box.center.dy);
    canvas.drawCircle(photoCenter, _photo / 2, _avatar);
    final letter = _Texts.letter(lawyer.avatarInitials);
    letter.paint(canvas, photoCenter - Offset(letter.width / 2, letter.height / 2));

    // The name, and the rating under it
    final name = _Texts.name(lawyer.name);
    final rate = _Texts.rate(lawyer.rating);
    final textRight = box.right - 5 - _photo - 6;
    final top = box.center.dy - (name.height + rate.height) / 2;
    name.paint(canvas, Offset(textRight - name.width, top));
    rate.paint(canvas, Offset(textRight - rate.width, top + name.height));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CardsPainter old) => old.lawyers != lawyers || old.camera != camera || old.selectedId != selectedId;
}
