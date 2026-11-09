import 'package:latlong2/latlong.dart';
import 'api_service.dart';

/// المسار وزمن الوصول مع الزحمة الحقيقية، بيحسبه سيرفرنا من TomTom
class RouteEstimate {
  final double distanceMeters;
  final double durationSeconds;
  final List<LatLng> geometryPoints;
  final bool isSuccess;


  const RouteEstimate({
    required this.distanceMeters,
    required this.durationSeconds,
    this.geometryPoints = const [],
    this.isSuccess = true,
  });

  const RouteEstimate.failed()
      : distanceMeters = 0.0,
        durationSeconds = 0.0,
        geometryPoints = const [],
        isSuccess = false;

  /// المسافة بالكيلومتر
  double get distanceKm => distanceMeters / 1000.0;

  /// مدة الوصول بالدقائق
  int get durationMinutes => (durationSeconds / 60.0).round();

  /// نص منسق للمسافة (مثال: 4.2 كم)
  String get distanceText {
    if (distanceKm < 1.0) {
      return '${distanceMeters.round()} م';
    }
    return '${distanceKm.toStringAsFixed(1)} كم';
  }

  /// مدى زمن الوصول بالزحمة الحقيقية، بأقرب 5 دقايق (مثال: حوالي 15 إلى 20 دقيقة)
  String get arrivalRangeText {
    final minutes = durationSeconds / 60.0;
    final low = (minutes * 0.9 / 5).floor() * 5;
    final high = (minutes * 1.2 / 5).ceil() * 5;
    if (high <= 5) return 'أقل من 5 دقايق';
    return 'حوالي ${low < 5 ? 5 : low} إلى $high دقيقة';
  }

  /// نص منسق لزمن الوصول التقريبي (مثال: 12 دقيقة)
  String get durationText {
    if (durationMinutes <= 1) {
      return 'دقيقة واحدة تقريباً';
    }
    if (durationMinutes == 2) {
      return 'دقيقتان تقريباً';
    }
    if (durationMinutes <= 10) {
      return '$durationMinutes دقائق تقريباً';
    }
    return '$durationMinutes دقيقة تقريباً';
  }
}

/// حساب الطريق من سيرفرنا، والمفتاح فاضل على السيرفر بس
class RoutingService {
  RoutingService();

  /// المسافة والوقت مع الزحمة، ونقاط الطريق لو مطلوبة
  Future<RouteEstimate> calculateDrivingRoute({
    required LatLng start,
    required LatLng destination,
    bool fetchGeometry = false,
  }) async {
    try {
      final res = await ApiService.get(
        '/routes',
        queryParams: {
          'fromLat': start.latitude.toStringAsFixed(6),
          'fromLon': start.longitude.toStringAsFixed(6),
          'toLat': destination.latitude.toStringAsFixed(6),
          'toLon': destination.longitude.toStringAsFixed(6),
          if (fetchGeometry) 'points': '1',
        },
        timeout: const Duration(seconds: 8),
      );

      if (res.isOk && res.data is Map<String, dynamic>) {
        final data = res.data as Map<String, dynamic>;
        final points = <LatLng>[
          for (final p in (data['points'] as List? ?? const []))
            if (p is List && p.length >= 2) LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()),
        ];
        if (fetchGeometry && points.isEmpty) points.addAll([start, destination]);
        return RouteEstimate(
          distanceMeters: (data['distanceMeters'] as num).toDouble(),
          durationSeconds: (data['durationSeconds'] as num).toDouble(),
          geometryPoints: points,
        );
      }
    } catch (_) {
      // انقطاع الشبكة ما يوقفش التطبيق
    }

    // خط مستقيم لو السيرفر ما ردش
    if (fetchGeometry) {
      return RouteEstimate(
        distanceMeters: const Distance().as(LengthUnit.Meter, start, destination),
        durationSeconds: 300,
        geometryPoints: [start, destination],
        isSuccess: false,
      );
    }

    return const RouteEstimate.failed();
  }
}
