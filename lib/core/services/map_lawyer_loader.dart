import 'dart:async';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../data/models/map_lawyer.dart';
import '../../data/repositories/lawyer_repository.dart';

/// يجيب محامي الجزء الظاهر من الخريطة بعد ما المستخدم يوقف تحريكها، ويحتفظ باللي شافهم
class MapLawyerLoader {
  static const _waitAfterMove = Duration(milliseconds: 500);
  static const _maxKept = 600;

  final void Function() onChanged;
  final Map<String, MapLawyer> _lawyers = {};
  Timer? _timer;
  LatLngBounds? _loaded;
  double _loadedZoom = 0;
  LatLng _center = const LatLng(30.0444, 31.2357);
  int _turn = 0;

  MapLawyerLoader({required this.onChanged});

  Iterable<MapLawyer> get lawyers => _lawyers.values;

  /// التحريك جوه المنطقة اللي اتحملت ما بيطلبش من الخادم تاني
  void cameraMoved(MapCamera camera) {
    _timer?.cancel();
    _timer = Timer(_waitAfterMove, () => _loadIfNeeded(camera));
  }

  void _loadIfNeeded(MapCamera camera) {
    final loaded = _loaded;
    final visible = camera.visibleBounds;
    final isInside = loaded != null && loaded.contains(visible.northWest) && loaded.contains(visible.southEast);
    if (isInside && camera.zoom >= _loadedZoom - 1) return;
    load(camera);
  }

  /// بيجيب المنطقة الظاهرة وربعها حواليها، عشان الحركة الصغيرة ما تطلبش من جديد
  Future<void> load(MapCamera camera) async {
    final visible = camera.visibleBounds;
    final padLat = (visible.north - visible.south) / 4;
    final padLon = (visible.east - visible.west) / 4;
    final area = LatLngBounds(
      LatLng(visible.south - padLat, visible.west - padLon),
      LatLng(visible.north + padLat, visible.east + padLon),
    );
    final turn = ++_turn;
    _center = camera.center;

    final res = await LawyerRepository.getLawyersInArea(
      center: camera.center,
      north: area.north,
      south: area.south,
      east: area.east,
      west: area.west,
    );
    if (turn != _turn || !res.isOk) return;

    _lawyers.removeWhere((_, lawyer) => area.contains(lawyer.position));
    for (final model in res.data ?? const []) {
      final lawyer = MapLawyer.fromModel(model);
      _lawyers[lawyer.id] = lawyer;
    }
    _trim();
    _loaded = area;
    _loadedZoom = camera.zoom;
    onChanged();
  }

  void _trim() {
    if (_lawyers.length <= _maxKept) return;
    const distance = Distance();
    final byDistance = _lawyers.values.toList()
      ..sort((a, b) => distance(_center, a.position).compareTo(distance(_center, b.position)));
    for (final lawyer in byDistance.skip(_maxKept)) {
      _lawyers.remove(lawyer.id);
    }
  }

  void dispose() {
    _timer?.cancel();
    _turn++;
  }
}
