import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../data/models/map_lawyer.dart';
import '../../data/repositories/lawyer_repository.dart';

/// اللي بيظهر على الخريطة حسب القرب، زي تطبيقات الخرايط الكبيرة، عشان تشيل مئات الآلاف من غير تعليق:
/// بعيد = عدد في كل منطقة، وفي النص = دبوس صغير لكل مكان، وقريب = كروت كاملة.
enum LawyerMapMode { counts, pins, cards }

/// مكان فيه محامي أو أكتر (دبوس)، أو منطقة بعدد محاميها
class LawyerSpot {
  final LatLng position;
  final int count;
  const LawyerSpot(this.position, this.count);
}

/// محامين الخريطة من مربعات ثابتة، كل مربع واحد لكل الناس والسيرفر بيجهزه كل 5 دقايق.
/// الموبايل بيطلب بس المربعات اللي ظاهرة ومش معاه أو عدّى عليها 5 دقايق، والباقي من عنده.
class MapLawyerLoader {
  static const _waitAfterMove = Duration(milliseconds: 400);
  /// من الزوم ده الدبابيس، ومن اللي بعده الكروت
  static const pinsFromZoom = 11.0;
  static const cardsFromZoom = 14.0;
  /// أقصى عدد كروت مرسومة في نفس الوقت، الأقرب لنص الشاشة
  static const maxCards = 150;
  static const _maxCellsPerAsk = 150;

  final void Function() onChanged;
  final Map<String, _Cell> _cells = {};
  final Map<String, MapLawyer> _lawyers = {};
  final Map<String, _Spots> _pins = {};
  final Map<String, _Spots> _counts = {};
  Timer? _timer;
  bool _closed = false;
  Duration _keepFor = const Duration(minutes: 5);

  MapLawyerLoader({required this.onChanged});

  Iterable<MapLawyer> get lawyers => _lawyers.values;
  Iterable<LawyerSpot> get pins => _pins.values.expand((s) => s.spots);
  Iterable<LawyerSpot> get counts => _counts.values.expand((s) => s.spots);

  static LawyerMapMode modeFor(double zoom) =>
      zoom >= cardsFromZoom ? LawyerMapMode.cards : zoom >= pinsFromZoom ? LawyerMapMode.pins : LawyerMapMode.counts;

  /// الكروت الأقرب لنص الشاشة بس، عشان الموبايل ما يرسمش مئات الكروت مرة واحدة
  List<MapLawyer> cardsNear(LatLng center, {int max = maxCards}) {
    if (_lawyers.length <= max) return _lawyers.values.toList();
    const distance = Distance();
    final list = _lawyers.values.toList()
      ..sort((a, b) => distance(center, a.position).compareTo(distance(center, b.position)));
    return list.take(max).toList();
  }

  /// بعد ما الخريطة توقف لحظة
  void cameraMoved(MapCamera camera) {
    _timer?.cancel();
    _timer = Timer(_waitAfterMove, () => load(camera));
  }

  /// المنطقة الظاهرة وربعها حواليها، بالنوع اللي يناسب القرب
  Future<bool> load(MapCamera camera) {
    final visible = camera.visibleBounds;
    final padLat = (visible.north - visible.south) / 4;
    final padLon = (visible.east - visible.west) / 4;
    final south = visible.south - padLat, north = visible.north + padLat;
    final west = visible.west - padLon, east = visible.east + padLon;
    return switch (modeFor(camera.zoom)) {
      LawyerMapMode.cards => _loadCards(south: south, north: north, west: west, east: east),
      LawyerMapMode.pins => _loadLight('pins', 's', 0.1, _pins, south: south, north: north, west: west, east: east),
      LawyerMapMode.counts => _loadLight('counts', 'l', 0.5, _counts, south: south, north: north, west: west, east: east),
    };
  }

  /// كروت المحامين حوالين نقطة، قبل ما الخريطة تترسم. بترجع false لو السيرفر ما ردش
  Future<bool> loadAround(LatLng center, {double radiusKm = 25}) {
    final latSpan = radiusKm / 111.0;
    final lonSpan = radiusKm / (111.0 * math.cos(center.latitude * math.pi / 180));
    return _loadCards(
      south: center.latitude - latSpan,
      north: center.latitude + latSpan,
      west: center.longitude - lonSpan,
      east: center.longitude + lonSpan,
    );
  }

  /// أقرب المحامين لنقطة من اللي على الخريطة، مع المسافة، من غير ما نسأل السيرفر
  List<MapLawyer> nearest(LatLng from, {int count = 30}) {
    const distance = Distance();
    final list = [for (final lawyer in _lawyers.values) lawyer.withDistance(distance(from, lawyer.position))]
      ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return list.take(count).toList();
  }

  List<String> _wanted(Map<String, DateTime> have, double degrees, double south, double north, double west, double east) {
    final now = DateTime.now();
    final wanted = <String>[];
    for (var x = (west / degrees).floor(); x <= (east / degrees).floor(); x++) {
      for (var y = (south / degrees).floor(); y <= (north / degrees).floor(); y++) {
        final at = have['${x}_$y'];
        if (at == null || now.difference(at) >= _keepFor) wanted.add('${x}_$y');
      }
    }
    return wanted;
  }

  Future<bool> _loadCards({required double south, required double north, required double west, required double east}) async {
    final wanted = _wanted({for (final e in _cells.entries) e.key: e.value.at}, 0.1, south, north, west, east);
    if (wanted.isEmpty) return true;
    var changed = false;
    for (var start = 0; start < wanted.length; start += _maxCellsPerAsk) {
      final part = wanted.sublist(start, math.min(start + _maxCellsPerAsk, wanted.length));
      final res = await LawyerRepository.getMapCells(size: 's', cells: part);
      if (_closed) return false;
      final data = res.data;
      if (!res.isOk || data == null) continue;
      _keepFor = Duration(seconds: data.seconds);
      final at = DateTime.now();
      for (final entry in data.cells.entries) {
        _cells[entry.key] = _Cell(at, [for (final model in entry.value) MapLawyer.fromModel(model)]);
      }
      changed = true;
    }
    if (!changed) return false;
    _lawyers
      ..clear()
      ..addEntries([
        for (final cell in _cells.values)
          for (final lawyer in cell.lawyers) MapEntry(lawyer.id, lawyer),
      ]);
    onChanged();
    return true;
  }

  Future<bool> _loadLight(String kind, String size, double degrees, Map<String, _Spots> store,
      {required double south, required double north, required double west, required double east,}) async {
    final wanted = _wanted({for (final e in store.entries) e.key: e.value.at}, degrees, south, north, west, east);
    if (wanted.isEmpty) return true;
    var changed = false;
    for (var start = 0; start < wanted.length; start += _maxCellsPerAsk) {
      final part = wanted.sublist(start, math.min(start + _maxCellsPerAsk, wanted.length));
      final res = await LawyerRepository.getMapLight(kind: kind, size: size, cells: part);
      if (_closed) return false;
      final data = res.data;
      if (!res.isOk || data == null) continue;
      final at = DateTime.now();
      for (final entry in data.entries) {
        final raw = entry.value;
        final spots = <LawyerSpot>[];
        if (kind == 'pins') {
          for (final p in raw) {
            final v = p as List;
            spots.add(LawyerSpot(LatLng((v[0] as num).toDouble(), (v[1] as num).toDouble()), (v[2] as num).toInt()));
          }
        } else if (raw.length >= 3) {
          spots.add(LawyerSpot(LatLng((raw[1] as num).toDouble(), (raw[2] as num).toDouble()), (raw[0] as num).toInt()));
        }
        store[entry.key] = _Spots(at, spots);
      }
      changed = true;
    }
    if (changed) onChanged();
    return changed;
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

class _Spots {
  final DateTime at;
  final List<LawyerSpot> spots;
  const _Spots(this.at, this.spots);
}
