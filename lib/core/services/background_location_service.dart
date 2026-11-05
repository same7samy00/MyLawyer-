import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:workmanager/workmanager.dart';
import 'api_service.dart';

const String _oldTaskName = 'lawyer_location_update';
const Duration _sendEvery = Duration(minutes: 1);
const int _moveMeters = 100;

/// النسخ القديمة سجلت مهمة دورية، والدالة دي موجودة عشان تتقفل من على الموبايلات
@pragma('vm:entry-point')
void backgroundLocationDispatcher() {
  Workmanager().executeTask((task, inputData) async => true);
}

/// طول ما المحامي «متاح»، مكانه بيتبعت كل دقيقة تقريبًا والتطبيق مفتوح أو في الخلفية.
/// لو التطبيق اتقفل التحديث يقف، والخادم يحوله لغير متاح بعد 10 دقايق.
class BackgroundLocationService {
  BackgroundLocationService._();

  static StreamSubscription<Position>? _subscription;
  static Timer? _timer;
  static Position? _latest;
  static bool _oldTaskCancelled = false;

  static LocationSettings _settings() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: _moveMeters,
        intervalDuration: _sendEvery,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'أنت متاح لاستقبال الطلبات',
          notificationText: 'بنحدث مكانك عشان توصلك طلبات قريبة منك',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }
    return const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: _moveMeters);
  }

  static Future<void> _send() async {
    final position = _latest;
    if (position == null) return;
    await ApiService.post('/lawyers/me/location', {
      'latitude': position.latitude,
      'longitude': position.longitude,
    });
  }

  static Future<void> start() async {
    await _cancelOldTask();
    if (_subscription != null) return;
    try {
      _subscription = Geolocator.getPositionStream(locationSettings: _settings()).listen(
        (position) {
          final isFirst = _latest == null;
          _latest = position;
          if (isFirst) unawaited(_send());
        },
        onError: (Object e) => debugPrint('Live location error: $e'),
      );
      // المحامي الواقف مكانه ما بيتغيرش، فالإرسال كل دقيقة بيأكد إنه لسه موجود
      _timer = Timer.periodic(_sendEvery, (_) => _send());
    } catch (e) {
      debugPrint('Live location start error: $e');
    }
  }

  static Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    await _subscription?.cancel();
    _subscription = null;
    _latest = null;
    await _cancelOldTask();
  }

  static Future<void> _cancelOldTask() async {
    if (_oldTaskCancelled) return;
    _oldTaskCancelled = true;
    try {
      await Workmanager().initialize(backgroundLocationDispatcher);
      await Workmanager().cancelByUniqueName(_oldTaskName);
    } catch (e) {
      debugPrint('Old location task error: $e');
    }
  }
}
