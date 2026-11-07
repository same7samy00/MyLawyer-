import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../data/models/map_lawyer.dart';
import '../../data/repositories/lawyer_repository.dart';

/// محامين الخريطة من مربعات ثابتة، كل مربع واحد لكل الناس والسيرفر بيجهزه كل 5 دقايق.
/// الموبايل بيطلب بس المربعات اللي ظاهرة ومش معاه أو عدّى عليها 5 دقايق، والباقي من عنده.
class MapLawyerLoader {
  static const _waitAfterMove = Duration(milliseconds: 500);
  /// قريب = مربعات صغيرة (حوالي 10 كم)، وبعيد = مربعات كبيرة (حوالي 50 كم)
  static const _smallFromZoom = 11.0;
  static const _maxCellsPerAsk = 150;

  final void Function() onChanged;
  final Map<String, _Cell> _cells = {};
  final Map<String, MapLawyer> _lawyers = {};
  Timer? _timer;
  bool _closed = false;
  Duration _keepFor = const Duration(minutes: 5);

  MapLawyerLoader({required this.onChanged});

  Iterable<MapLawyer> get lawyers => _lawyers.values;

  /// بعد ما الخريطة توقف نص ثانية
  void cameraMoved(MapCamera camera) {
    _timer?.cancel();
    _timer = Timer(_waitAfterMove, () => load(camera));
  }

  /// المنطقة الظاهرة وربعها حواليها، عشان الحركة الصغيرة ما تطلبش من جديد
  Future<bool> load(MapCamera camera) {
    final visible = camera.visibleBounds;
    final padLat = (visible.north - visible.south) / 4;
    final padLon = (visible.east - visible.west) / 4;
    return _loadArea(
      south: visible.south - padLat,
      north: visible.north + padLat,
      west: visible.west - padLon,
      east: visible.east + padLon,
      small: camera.zoom >= _smallFromZoom,
    );
  }

  /// المربعات حوالين نقطة، قبل ما الخريطة تترسم. بترجع false لو السيرفر ما ردش
  Future<bool> loadAround(LatLng center, {double radiusKm = 25}) {
    final latSpan = radiusKm / 111.0;
    final lonSpan = radiusKm / (111.0 * math.cos(center.latitude * math.pi / 180));
    return _loadArea(
      south: center.latitude - latSpan,
      north: center.latitude + latSpan,
      west: center.longitude - lonSpan,
      east: center.longitude + lonSpan,
      small: true,
    );
  }

  /// أقرب المحامين لنقطة من اللي على الخريطة، مع المسافة، من غير ما نسأل السيرفر
  List<MapLawyer> nearest(LatLng from, {int count = 30}) {
    const distance = Distance();
    final list = [for (final lawyer in _lawyers.values) lawyer.withDistance(distance(from, lawyer.position))]
      ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return list.take(count).toList();
  }

  Future<bool> _loadArea({required double south, required double north, required double west, required double east, required bool small}) async {
    final size = small ? 's' : 'l';
    final degrees = small ? 0.1 : 0.5;
    final now = DateTime.now();
    final wanted = <String>[];
    for (var x = (west / degrees).floor(); x <= (east / degrees).floor(); x++) {
      for (var y = (south / degrees).floor(); y <= (north / degrees).floor(); y++) {
        final cell = _cells['$size:${x}_$y'];
        if (cell == null || now.difference(cell.at) >= _keepFor) wanted.add('${x}_$y');
      }
    }
    if (wanted.isEmpty) return true;

    var changed = false;
    for (var start = 0; start < wanted.length; start += _maxCellsPerAsk) {
      final part = wanted.sublist(start, math.min(start + _maxCellsPerAsk, wanted.length));
      final res = await LawyerRepository.getMapCells(size: size, cells: part);
      if (_closed) return false;
      final data = res.data;
      if (!res.isOk || data == null) continue;
      _keepFor = Duration(seconds: data.seconds);
      final at = DateTime.now();
      for (final entry in data.cells.entries) {
        _cells['$size:${entry.key}'] = _Cell(at, [for (final model in entry.value) MapLawyer.fromModel(model)]);
      }
      changed = true;
    }
    if (!changed) return false;
    _rebuild();
    onChanged();
    return true;
  }

  /// الأحدث يكسب لو المحامي في مربع صغير ومربع كبير
  void _rebuild() {
    final ordered = _cells.values.toList()..sort((a, b) => a.at.compareTo(b.at));
    _lawyers
      ..clear()
      ..addEntries([
        for (final cell in ordered)
          for (final lawyer in cell.lawyers) MapEntry(lawyer.id, lawyer),
      ]);
  }

  void dispose() {
    _closed = true;
    _timer?.cancel();
  }
}

class _Cell {
  final DateTime at;
  final List<MapLawyer> lawyers;
  const _Cell(this.at, this.lawyers);
}
