import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:workmanager/workmanager.dart';
import 'api_service.dart';

const String _oldTaskName = 'lawyer_location_update';

/// المحامي «المتاح» بيقول «أنا لسه هنا» كل 3 دقايق حتى لو واقف، والسيرفر بيصحّيه بتنبيه صامت لو سكت 5 دقايق
/// (قرار 2026-11-09). الدقة متوسطة، كفاية لتوزيع الطلبات وأخف على البطارية
const Duration _availableEvery = Duration(minutes: 3);
const int _availableMoveMeters = 100;

/// الطريق للمقابلة: التحديث على قد المسافة للموكل، والدقة عالية. المكان للوقت المكتوب، وزرار «وصلت»، ونقطة المحامي على خريطة الموكل
typedef _Pace = ({Duration every, int meters});
const _Pace _far = (every: Duration(seconds: 30), meters: 150);
const _Pace _closer = (every: Duration(seconds: 15), meters: 50);
const _Pace _near = (every: Duration(seconds: 5), meters: 10);
const _Pace _client = (every: Duration(seconds: 60), meters: 30);

/// النسخ القديمة سجلت مهمة دورية، والدالة دي موجودة عشان تتقفل من على الموبايلات
@pragma('vm:entry-point')
void backgroundLocationDispatcher() {
  Workmanager().executeTask((task, inputData) async => true);
}

/// مصدر واحد للموقع بيخدم حاجتين:
/// - المحامي «المتاح»: مكانه بيتبعت لو اتحرك 100 متر، و«أنا لسه هنا» كل 3 دقايق، والتطبيق مفتوح أو في الخلفية
///   بإشعار ثابت. لو الموبايل سكت، السيرفر بيبعت تنبيه صامت (`answerWake`) والموبايل بيرد بمكانه حتى لو التطبيق مقفول.
/// - الطريق للمقابلة (للمحامي والموكل): من الدفع لحد «وصلت». المحامي بيبعت على قد بعده عن الموكل (بعيد كل 30 ثانية،
///   قرّب كل 15، أقل من 500 متر كل 5)، والموكل كل دقيقة أو لو اتحرك 30 متر.
/// مفيش غير اشتراك موقع واحد في نفس الوقت.
class BackgroundLocationService {
  BackgroundLocationService._();

  /// آخر مكان للموبايل ده، لوقت الوصول وزرار «وصلت»
  static final ValueNotifier<Position?> latest = ValueNotifier<Position?>(null);

  static StreamSubscription<Position>? _subscription;
  static Timer? _availableTimer;
  static Timer? _missionTimer;
  static bool _available = false;
  static String? _missionOrderId;
  static double? _targetLat;
  static double? _targetLon;
  static bool _missionIsLawyer = false;
  static _Pace _pace = _far;
  static DateTime? _lastMissionSend;
  static bool _oldTaskCancelled = false;

  static bool get _onMission => _missionOrderId != null;

  static LocationSettings _settings() {
    final distance = _onMission ? _pace.meters : _availableMoveMeters;
    final accuracy = _onMission ? LocationAccuracy.high : LocationAccuracy.medium;
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: accuracy,
        distanceFilter: distance,
        intervalDuration: _onMission ? _pace.every : _availableEvery,
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: _onMission ? 'في الطريق للمقابلة' : 'أنت متاح لاستقبال الطلبات',
          notificationText: _onMission
              ? 'بنحسب وقت الوصول لحد ما توصل'
              : 'بنحدث مكانك عشان توصلك طلبات قريبة منك',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }
    return LocationSettings(accuracy: accuracy, distanceFilter: distance);
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

  /// الطلب المدفوع اللي لسه المحامي ما وصلش فيه، أو null لما الطريق يخلص.
  /// [targetLat]/[targetLon] مكان الموكل، والمحامي بيبعت أسرع كل ما يقرّب منه
  static Future<void> setMission(String? orderId, {double? targetLat, double? targetLon, bool isLawyer = false}) async {
    if (orderId == _missionOrderId) return;
    _missionOrderId = orderId;
    _targetLat = targetLat;
    _targetLon = targetLon;
    _missionIsLawyer = isLawyer;
    _pace = isLawyer ? _far : _client;
    _lastMissionSend = null;
    await _restart();
  }

  /// السيرفر ما سمعش من الموبايل شوية وبعت تنبيه صامت: الرد بالمكان، حتى لو التطبيق مقفول والشاشة مطفية
  static Future<void> answerWake() async {
    try {
      Position? position = latest.value;
      position ??= await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 20)),
      ).catchError((_) => Geolocator.getLastKnownPosition().then((p) => p!));
      await ApiService.post('/lawyers/me/location', {'latitude': position.latitude, 'longitude': position.longitude, 'mocked': position.isMocked});
    } catch (e) {
      debugPrint('Wake answer error: $e');
    }
  }

  /// المحامي في الطريق: السرعة على قد البعد عن الموكل
  static _Pace _paceFor(Position position) {
    final lat = _targetLat;
    final lon = _targetLon;
    if (!_missionIsLawyer) return _client;
    if (lat == null || lon == null) return _far;
    final meters = Geolocator.distanceBetween(position.latitude, position.longitude, lat, lon);
    if (meters < 500) return _near;
    if (meters < 3000) return _closer;
    return _far;
  }

  static AppLifecycleListener? _lifecycle;

  /// من أندرويد 14 أي حد يقدر يمسح إشعار «أنت متاح» من لوحة الإشعارات، والنظام بيسيب الخدمة شغالة.
  /// فأول ما التطبيق يرجع قدام، الإشعار الثابت بيرجع تاني زي تطبيقات التوصيل
  static void _keepNotificationShown() {
    _lifecycle ??= AppLifecycleListener(onResume: () {
      if (_available || _onMission) unawaited(_restart());
    },);
  }

  static Future<void> _restart() async {
    _keepNotificationShown();
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
            // Getting closer changes the pace; the stream starts again with the new one
            final pace = _paceFor(position);
            if (pace != _pace) {
              _pace = pace;
              unawaited(_restart());
            }
            unawaited(_sendMission(position));
            // بيبدأ بعد أول مكان حقيقي بس، فموبايل من غير موقع ما يفضلش فيه مؤقت شغال
            _missionTimer ??= Timer.periodic(_pace.every * 2, (_) {
              final last = latest.value;
              if (last != null) unawaited(_sendMission(last));
            });
          }
        },
        onError: (Object e) => debugPrint('Live location error: $e'),
      );
      // الواقف مكانه ما بيتحركش، فـ«أنا لسه هنا» بيأكد إنه لسه موجود
      if (_available) _availableTimer = Timer.periodic(_availableEvery, (_) => _sendAvailable());
    } catch (e) {
      debugPrint('Live location start error: $e');
    }
  }

  static Future<void> _sendAvailable() async {
    final position = latest.value;
    if (position == null) {
      await answerWake();
      return;
    }
    await ApiService.post('/lawyers/me/location', {
      'latitude': position.latitude,
      'longitude': position.longitude,
      'mocked': position.isMocked,
    });
  }

  static Future<void> _sendMission(Position position) async {
    final orderId = _missionOrderId;
    if (orderId == null) return;
    final now = DateTime.now();
    final last = _lastMissionSend;
    if (last != null && now.difference(last) < _pace.every) return;
    _lastMissionSend = now;

    final res = await ApiService.post('/orders/$orderId/position', {
      'latitude': position.latitude,
      'longitude': position.longitude,
      'mocked': position.isMocked,
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
