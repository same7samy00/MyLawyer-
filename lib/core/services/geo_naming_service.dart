import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// اسم المنطقة والمحافظة للموقع من ملف مناطق مصر داخل التطبيق
/// العنوان هنا للتوضيح فقط، والوصول الفعلي يتم بالموقع الدقيق عبر Google Maps
class GeoNamingService {
  GeoNamingService._();
  static final GeoNamingService instance = GeoNamingService._();

  static const String _placesAsset = 'assets/data/egypt_places.json';
  static const double _maxPlaceDistanceKm = 12.0;
  static const String _unknownArea = 'جمهورية مصر العربية';

  _PlacesData? _places;
  final Map<String, String> _cache = {};

  Future<_PlacesData?> _loadPlaces() async {
    if (_places != null) return _places;

    try {
      final bytes = await rootBundle.load(_placesAsset);
      final raw = utf8.decode(bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes));
      return _places = _PlacesData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Egypt places load error: $e');
      return null;
    }
  }

  /// اسم المنطقة والمحافظة، مثال: مدينة طنطا، محافظة الغربية
  Future<String> getCityAndGovernorate(double lat, double lng) async {
    final cacheKey = '${lat.toStringAsFixed(3)},${lng.toStringAsFixed(3)}';
    final cached = _cache[cacheKey];
    if (cached != null) return cached;

    final data = await _loadPlaces();
    if (data == null) return _unknownArea;

    final result = data.areaNameFor(lat, lng, _maxPlaceDistanceKm);
    _cache[cacheKey] = result;
    return result;
  }
}

const double _closePlaceKm = 3.0;

class _Place {
  final String name;
  final double lat;
  final double lon;

  /// المدن تغطي مساحة أكبر من القرى والأحياء
  final int weight;
  final int governorate;

  const _Place(this.name, this.lat, this.lon, this.weight, this.governorate);
}

class _PlacesData {
  final List<String> governorates;
  final List<_Place> places;

  const _PlacesData(this.governorates, this.places);

  factory _PlacesData.fromJson(Map<String, dynamic> json) {
    return _PlacesData(
      (json['governorates'] as List).cast<String>(),
      [
        for (final row in json['places'] as List)
          _Place(
            row[0] as String,
            (row[1] as num).toDouble(),
            (row[2] as num).toDouble(),
            row[3] as int,
            row[4] as int,
          ),
      ],
    );
  }

  String areaNameFor(double lat, double lon, double maxDistanceKm) {
    _Place? best;
    _Place? nearest;
    var bestScore = double.infinity;
    var nearestDistance = double.infinity;
    final lonScale = math.cos(lat * math.pi / 180);

    for (final place in places) {
      final dLat = (place.lat - lat) * 111.0;
      final dLon = (place.lon - lon) * 111.0 * lonScale;
      final distance = math.sqrt(dLat * dLat + dLon * dLon);
      final score = distance / place.weight;

      if (score < bestScore) {
        best = place;
        bestScore = score;
      }
      if (distance < nearestDistance) {
        nearest = place;
        nearestDistance = distance;
      }
    }

    // منطقة قريبة فعلاً أدق من مدينة كبيرة بعيدة
    if (nearestDistance <= _closePlaceKm) {
      best = nearest;
      bestScore = nearestDistance;
    }

    if (best == null) return GeoNamingService._unknownArea;

    final governorate = 'محافظة ${governorates[best.governorate]}';
    if (bestScore > maxDistanceKm) return governorate;

    final isCity = best.weight > 1 && !best.name.startsWith('مدينة') && !best.name.startsWith('مركز');
    return '${isCity ? 'مدينة ${best.name}' : best.name}، $governorate';
  }
}
