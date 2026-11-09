import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../data/models/map_lawyer.dart';
import '../../data/repositories/lawyer_repository.dart';

/// المحامين على الخريطة زي ما جوجل بيعرض الأماكن: بعيد الأهم بس، وكل ما تقرّب يظهر أكتر.
/// - بعيد (أقل من زوم 9): أعلى محامي تقييمًا في كل منطقة حوالي 5 كم.
/// - في النص (9 لـ 12): أعلى محامي في كل حوالي 500 متر.
/// - قريب (12 وأكتر): كل المحامين.
/// عدد المحامين على الشاشة بيفضل قريب من بعضه في كل المستويات، مهما كان عدد المحامين.
/// كل مربع واحد لكل الناس والسيرفر بيجهزه كل 5 دقايق، والموبايل بيطلب بس اللي ظاهر ومش معاه.
class MapLawyerLoader {
  static const _waitAfterMove = Duration(milliseconds: 350);
  static const midFromZoom = 9.0;
  static const allFromZoom = 12.0;
  static const _maxCellsPerAsk = 150;

  final void Function() onChanged;
  final Map<_Level, Map<String, _Cell>> _cells = {for (final level in _Level.values) level: {}};
  Map<String, MapLawyer> _shown = {};
  _Level _level = _Level.all;
  Timer? _timer;
  bool _closed = false;
  Duration _keepFor = const Duration(minutes: 5);

  MapLawyerLoader({required this.onChanged});

  /// المحامين اللي يترسموا دلوقتي حسب القرب
  Iterable<MapLawyer> get lawyers => _shown.values;

  static _Level _levelFor(double zoom) => zoom >= allFromZoom ? _Level.all : zoom >= midFromZoom ? _Level.mid : _Level.far;

  /// بعد ما الخريطة توقف لحظة
  void cameraMoved(MapCamera camera) {
    _timer?.cancel();
    _timer = Timer(_waitAfterMove, () => load(camera));
  }

  /// المنطقة الظاهرة وربعها حواليها، بالمستوى اللي يناسب القرب
  Future<bool> load(MapCamera camera) {
    final visible = camera.visibleBounds;
    final padLat = (visible.north - visible.south) / 4;
    final padLon = (visible.east - visible.west) / 4;
    final level = _levelFor(camera.zoom);
    if (level != _level) {
      _level = level;
      _rebuild();
      onChanged();
    }
    return _load(level, visible.south - padLat, visible.north + padLat, visible.west - padLon, visible.east + padLon);
  }

  /// كل المحامين حوالين نقطة، قبل ما الخريطة تترسم. بترجع false لو السيرفر ما ردش
  Future<bool> loadAround(LatLng center, {double radiusKm = 25}) {
    final latSpan = radiusKm / 111.0;
    final lonSpan = radiusKm / (111.0 * math.cos(center.latitude * math.pi / 180));
    return _load(_Level.all, center.latitude - latSpan, center.latitude + latSpan, center.longitude - lonSpan, center.longitude + lonSpan);
  }

  /// أقرب المحامين لنقطة من كل اللي اتحمّلوا، مع المسافة، من غير ما نسأل السيرفر
  List<MapLawyer> nearest(LatLng from, {int count = 30}) {
    const distance = Distance();
    final all = {for (final cell in _cells[_Level.all]!.values) for (final l in cell.lawyers) l.id: l};
    final list = [for (final lawyer in all.values) lawyer.withDistance(distance(from, lawyer.position))]
      ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return list.take(count).toList();
  }

  Future<bool> _load(_Level level, double south, double north, double west, double east) async {
    final store = _cells[level]!;
    final degrees = level == _Level.far ? 0.5 : 0.1;
    final now = DateTime.now();
    final wanted = <String>[];
    for (var x = (west / degrees).floor(); x <= (east / degrees).floor(); x++) {
      for (var y = (south / degrees).floor(); y <= (north / degrees).floor(); y++) {
        final cell = store['${x}_$y'];
        if (cell == null || now.difference(cell.at) >= _keepFor) wanted.add('${x}_$y');
      }
    }
    if (wanted.isEmpty) return true;

    var changed = false;
    for (var start = 0; start < wanted.length; start += _maxCellsPerAsk) {
      final part = wanted.sublist(start, math.min(start + _maxCellsPerAsk, wanted.length));
      final res = await LawyerRepository.getMapCells(
        size: level == _Level.far ? 'l' : 's',
        cells: part,
        kind: level == _Level.all ? null : 'top',
      );
      if (_closed) return false;
      final data = res.data;
      if (!res.isOk || data == null) continue;
      _keepFor = Duration(seconds: data.seconds);
      final at = DateTime.now();
      for (final entry in data.cells.entries) {
        store[entry.key] = _Cell(at, [for (final model in entry.value) MapLawyer.fromModel(model)]);
      }
      changed = true;
    }
    if (!changed) return false;
    if (level == _level) {
      _rebuild();
      onChanged();
    }
    return true;
  }

  void _rebuild() {
    _shown = {for (final cell in _cells[_level]!.values) for (final lawyer in cell.lawyers) lawyer.id: lawyer};
  }

  void dispose() {
    _closed = true;
    _timer?.cancel();
  }
}

enum _Level { far, mid, all }

class _Cell {
  final DateTime at;
  final List<MapLawyer> lawyers;
  const _Cell(this.at, this.lawyers);
}
