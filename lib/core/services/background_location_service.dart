import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:workmanager/workmanager.dart';
import 'api_service.dart';

const String _oldTaskName = 'lawyer_location_update';
const Duration _availableEvery = Duration(minutes: 1);
const int _availableMoveMeters = 100;
// On the way to a meeting the other side watches live, so points go out often but only when the phone moved
const Duration _missionEvery = Duration(seconds: 5);
const Duration _missionKeepAlive = Duration(seconds: 30);
const int _missionMoveMeters = 10;

/// النسخ القديمة سجلت مهمة دورية، والدالة دي موجودة عشان تتقفل من على الموبايلات
@pragma('vm:entry-point')
void backgroundLocationDispatcher() {
  Workmanager().executeTask((task, inputData) async => true);
}

/// مصدر واحد للموقع بيخدم حاجتين:
/// - المحامي «المتاح»: مكانه بيتبعت كل دقيقة تقريبًا والتطبيق مفتوح أو في الخلفية، والخادم يحوله لغير متاح بعد 10 دقايق من غير تحديث.
/// - الطريق للمقابلة (للمحامي والموكل): من الدفع لحد «وصلت»، آخر نقطة بتتبعت كل 5 ثواني لو الموبايل اتحرك، والطرف التاني بيشوفها لحظيًا.
/// مفيش غير اشتراك موقع واحد في نفس الوقت، بإعدادات أسرع بس أثناء الطريق.
class BackgroundLocationService {
  BackgroundLocationService._();

  /// آخر مكان للموبايل ده، للخريطة اللي بتعرض الطرفين
  static final ValueNotifier<Position?> latest = ValueNotifier<Position?>(null);

  static StreamSubscription<Position>? _subscription;
  static Timer? _availableTimer;
  static Timer? _missionTimer;
  static bool _available = false;
  static String? _missionOrderId;
  static DateTime? _lastMissionSend;
  static bool _oldTaskCancelled = false;

  static bool get _onMission => _missionOrderId != null;

  static LocationSettings _settings() {
    final distance = _onMission ? _missionMoveMeters : _availableMoveMeters;
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distance,
        intervalDuration: _onMission ? _missionEvery : _availableEvery,
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: _onMission ? 'في الطريق للمقابلة' : 'أنت متاح لاستقبال الطلبات',
          notificationText: _onMission
              ? 'بنشارك مكانك مع الطرف التاني لحد الوصول'
              : 'بنحدث مكانك عشان توصلك طلبات قريبة منك',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }
    return LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: distance);
  }

  /// المحامي فعّل «متاح»
  static Future<void> start() async {
    _available = true;
    await _restart();
  }

  /// المحامي قفل «متاح»، والطريق للمقابلة لو موجود يكمل
  static Future<void> stop() async {
    _available = false;
    await _restart();
  }

  /// الخروج من الحساب أو إيقافه: كل حاجة تقف
  static Future<void> stopAll() async {
    _available = false;
    _missionOrderId = null;
    await _restart();
  }

  /// الطلب المدفوع اللي لسه المحامي ما وصلش فيه، أو null لما الطريق يخلص
  static Future<void> setMission(String? orderId) async {
    if (orderId == _missionOrderId) return;
    _missionOrderId = orderId;
    _lastMissionSend = null;
    await _restart();
  }

  static Future<void> _restart() async {
    _availableTimer?.cancel();
    _availableTimer = null;
    _missionTimer?.cancel();
    _missionTimer = null;
    await _subscription?.cancel();
    _subscription = null;
    await _cancelOldTask();
    if (!_available && !_onMission) {
      latest.value = null;
      return;
    }

    try {
      var isFirst = true;
      _subscription = Geolocator.getPositionStream(locationSettings: _settings()).listen(
        (position) {
          latest.value = position;
          if (isFirst && _available) unawaited(_sendAvailable());
          isFirst = false;
          if (_onMission) {
            unawaited(_sendMission(position));
            // بيبدأ بعد أول مكان حقيقي بس، فموبايل من غير موقع ما يفضلش فيه مؤقت شغال
            _missionTimer ??= Timer.periodic(_missionKeepAlive, (_) {
              final last = latest.value;
              if (last != null) unawaited(_sendMission(last));
            });
          }
        },
        onError: (Object e) => debugPrint('Live location error: $e'),
      );
      // الواقف مكانه ما بيتحركش، فالإرسال الدوري بيأكد إنه لسه موجود
      if (_available) _availableTimer = Timer.periodic(_availableEvery, (_) => _sendAvailable());
    } catch (e) {
      debugPrint('Live location start error: $e');
    }
  }

  static Future<void> _sendAvailable() async {
    final position = latest.value;
    if (position == null) return;
    await ApiService.post('/lawyers/me/location', {
      'latitude': position.latitude,
      'longitude': position.longitude,
    });
  }

  static Future<void> _sendMission(Position position) async {
    final orderId = _missionOrderId;
    if (orderId == null) return;
    final now = DateTime.now();
    final last = _lastMissionSend;
    if (last != null && now.difference(last) < _missionEvery) return;
    _lastMissionSend = now;

    final res = await ApiService.post('/orders/$orderId/position', {
      'latitude': position.latitude,
      'longitude': position.longitude,
    });
    // الخادم بيقول إن الطريق خلص (وصل، أو الطلب اتقفل)، فالمشاركة تقف
    final data = res.data;
    if (res.isOk && data is Map && data['tracking'] == false && _missionOrderId == orderId) {
      await setMission(null);
    }
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
