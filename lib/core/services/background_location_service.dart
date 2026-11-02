import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'api_service.dart';

const String _taskName = 'lawyer_location_update';
const String _prefLastLat = 'bg_location_lat';
const String _prefLastLon = 'bg_location_lon';
const String _prefLastSentAt = 'bg_location_sent_at';

const Duration _checkEvery = Duration(minutes: 15);
const Duration _sendEvery = Duration(minutes: 30);
const double _sendAfterMeters = 3000;

@pragma('vm:entry-point')
void backgroundLocationDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await _sendLocationIfDue();
    } catch (e) {
      debugPrint('Background location error: $e');
    }
    return true;
  });
}

/// الموبايل يفحص كل 15 دقيقة، ويبعت لو عدت 30 دقيقة أو المحامي اتحرك 3 كم
Future<void> _sendLocationIfDue() async {
  if (await Geolocator.checkPermission() != LocationPermission.always) return;

  final position = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.medium,
      timeLimit: Duration(seconds: 25),
    ),
  );

  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  final lastLat = prefs.getDouble(_prefLastLat);
  final lastLon = prefs.getDouble(_prefLastLon);
  final lastSentAt = prefs.getInt(_prefLastSentAt) ?? 0;
  final age = DateTime.now().millisecondsSinceEpoch - lastSentAt;

  final hasMoved = lastLat == null ||
      lastLon == null ||
      Geolocator.distanceBetween(lastLat, lastLon, position.latitude, position.longitude) >= _sendAfterMeters;
  if (!hasMoved && age < _sendEvery.inMilliseconds - 60000) return;

  final res = await ApiService.post('/lawyers/me/location', {
    'latitude': position.latitude,
    'longitude': position.longitude,
  });
  if (!res.isOk) return;

  await prefs.setDouble(_prefLastLat, position.latitude);
  await prefs.setDouble(_prefLastLon, position.longitude);
  await prefs.setInt(_prefLastSentAt, DateTime.now().millisecondsSinceEpoch);
}

/// تحديث مكان المحامي والتطبيق مقفول، طول ما هو متاح
class BackgroundLocationService {
  BackgroundLocationService._();

  static bool _isInitialized = false;

  static Future<void> start() async {
    try {
      if (!_isInitialized) {
        await Workmanager().initialize(backgroundLocationDispatcher);
        _isInitialized = true;
      }
      await Workmanager().registerPeriodicTask(
        _taskName,
        _taskName,
        frequency: _checkEvery,
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingWorkPolicy.keep,
      );
    } catch (e) {
      debugPrint('Background location start error: $e');
    }
  }

  static Future<void> stop() async {
    try {
      if (!_isInitialized) {
        await Workmanager().initialize(backgroundLocationDispatcher);
        _isInitialized = true;
      }
      await Workmanager().cancelByUniqueName(_taskName);
    } catch (e) {
      debugPrint('Background location stop error: $e');
    }
  }
}
