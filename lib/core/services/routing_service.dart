import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../constants/map_config.dart';

/// تقدير المسار وزمن الوصول ونقاط الرسم المحسوبة عبر محرك OSRM على خادم My Lawyer
class RouteEstimate {
  final double distanceMeters;
  final double durationSeconds;
  final List<LatLng> geometryPoints;
  final bool isSuccess;

  /// معامل الزحمة المتوقعة، لأن محرك المسارات يحسب الوقت على طريق فاضي
  final double trafficFactor;

  const RouteEstimate({
    required this.distanceMeters,
    required this.durationSeconds,
    this.geometryPoints = const [],
    this.isSuccess = true,
    this.trafficFactor = 1.0,
  });

  const RouteEstimate.failed()
      : distanceMeters = 0.0,
        durationSeconds = 0.0,
        geometryPoints = const [],
        isSuccess = false,
        trafficFactor = 1.0;

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

  /// مدى زمن الوصول بعد الزحمة المتوقعة، بأقرب 5 دقايق (مثال: حوالي 15 إلى 20 دقيقة)
  String get arrivalRangeText {
    final minutes = durationSeconds * trafficFactor / 60.0;
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

/// تقدير الزحمة حسب الساعة والمنطقة، لحد ما تتظبط الأرقام من رحلات المحامين الفعلية
double trafficFactorFor(DateTime time, LatLng point) {
  final isBigCity = (point.latitude >= 29.75 && point.latitude <= 30.35 && point.longitude >= 30.85 && point.longitude <= 31.75) ||
      (point.latitude >= 30.95 && point.latitude <= 31.35 && point.longitude >= 29.7 && point.longitude <= 30.15);
  final hour = time.hour;
  final isNight = hour < 6;
  final isPeak = (hour >= 8 && hour < 11) || (hour >= 14 && hour < 20);

  if (isNight) return isBigCity ? 1.15 : 1.05;
  if (isPeak) return isBigCity ? 1.8 : 1.4;
  return isBigCity ? 1.35 : 1.2;
}

/// خدمة حساب المسافات والملاحة القانونية عبر خادم OSRM الذاتي
class RoutingService {
  final http.Client _client;

  RoutingService({http.Client? client}) : _client = client ?? http.Client();

  /// حساب المسافة والزمن التقريبي ومسار الطريق بين نقطتين بالسيارة عبر شبكة طرق مصر المحملة على السيرفر
  Future<RouteEstimate> calculateDrivingRoute({
    required LatLng start,
    required LatLng destination,
    bool fetchGeometry = false,
  }) async {
    final String queryParams = fetchGeometry
        ? '?overview=full&geometries=geojson'
        : '?overview=false';

    final uri = Uri.parse(
      '${MapConfig.osrmBaseUrl}/route/v1/driving/'
      '${start.longitude},${start.latitude};'
      '${destination.longitude},${destination.latitude}'
      '$queryParams',
    );

    try {
      final response = await _client.get(uri).timeout(
        const Duration(seconds: 4),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data['code'] == 'Ok' &&
            data['routes'] != null &&
            (data['routes'] as List).isNotEmpty) {
          final firstRoute = data['routes'][0];
          final double distance = (firstRoute['distance'] as num).toDouble();
          final double duration = (firstRoute['duration'] as num).toDouble();

          final List<LatLng> points = [];
          if (fetchGeometry &&
              firstRoute['geometry'] != null &&
              firstRoute['geometry']['coordinates'] != null) {
            final coords = firstRoute['geometry']['coordinates'] as List;
            for (final coord in coords) {
              if (coord is List && coord.length >= 2) {
                final double lng = (coord[0] as num).toDouble();
                final double lat = (coord[1] as num).toDouble();
                points.add(LatLng(lat, lng));
              }
            }
          }

          if (fetchGeometry && points.isEmpty) {
            points.addAll([start, destination]);
          }

          return RouteEstimate(
            distanceMeters: distance,
            durationSeconds: duration,
            geometryPoints: points,
            trafficFactor: trafficFactorFor(DateTime.now(), start),
          );
        }
      }
    } catch (_) {
      // التعامل الآمن مع انقطاع الشبكة دون إيقاف التطبيق
    }

    // بديل احتياطي برسم خط مستقيم مباشر إذا تعذر جلب المسار من الخادم
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
