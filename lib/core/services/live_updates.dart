import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'api_service.dart';
import 'app_visibility.dart';
import 'saved_data.dart';

/// تغيير واحد بعته السيرفر: نوعه، والطلب أو التذكرة اللي اتغيرت لو معروفة
class LiveChange {
  final String kind;
  final String? entityId;

  const LiveChange(this.kind, [this.entityId]);

  bool get isEverything => kind == 'all';
}

/// آخر مكان للطرف التاني في الطريق للمقابلة
class LivePoint {
  final String orderId;
  final double lat;
  final double lon;

  const LivePoint(this.orderId, this.lat, this.lon);
}

/// خط مفتوح مع السيرفر زي التطبيقات الكبيرة:
/// السيرفر بيبعت إيه اللي اتغير بالظبط، والتطبيق بيحدث الحاجة دي بس.
/// كل تغيير له رقم، ولو الخط قطع، التطبيق بيسأل عن اللي فاته بس أول ما يرجع، من غير شاشة تحميل أو رسالة.
class LiveUpdates {
  LiveUpdates._();

  /// بيزيد مع كل تغيير، للعدادات والإشعارات
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);

  /// الطلبات والفلوس اتغيرت
  static final ValueNotifier<int> orders = ValueNotifier<int>(0);

  /// الطلبات الجديدة والعروض اتغيرت
  static final ValueNotifier<int> requests = ValueNotifier<int>(0);

  /// مكان الطرف التاني بيوصل هنا لحظة بلحظة، ومش بيتسجل كتغيير ولا بيحدث أي شاشة تانية
  static final ValueNotifier<LivePoint?> position = ValueNotifier<LivePoint?>(null);

  static final StreamController<LiveChange> _changes = StreamController<LiveChange>.broadcast();

  /// كل تغيير لوحده، للي محتاج يعرف أنهي طلب اتغير
  static Stream<LiveChange> get stream => _changes.stream;

  static const String _lastIdKey = 'live_last_id';
  static const Duration _firstRetry = Duration(seconds: 2);
  static const Duration _maxRetry = Duration(seconds: 30);
  static const Duration _gatherChanges = Duration(milliseconds: 150);
  static const Duration _alertGap = Duration(seconds: 2);
  static const MethodChannel _device = MethodChannel('mylawyer/device');
  static DateTime? _lastAlert;

  static StreamSubscription<String>? _line;
  static Timer? _retryTimer;
  static Timer? _gatherTimer;
  static AppLifecycleListener? _lifecycle;
  static Duration _nextRetry = _firstRetry;
  static bool _isRunning = false;
  static int _turn = 0;
  static int? _lastId;
  static final Set<String> _pendingKinds = {};

  static void start() {
    if (_isRunning) return;
    _isRunning = true;
    _lifecycle ??= AppLifecycleListener(onResume: _reconnectNow);
    unawaited(_connect());
  }

  static void stop() {
    _isRunning = false;
    _turn++;
    _lastId = null;
    position.value = null;
    _retryTimer?.cancel();
    _gatherTimer?.cancel();
    unawaited(_line?.cancel());
    _line = null;
    _lifecycle?.dispose();
    _lifecycle = null;
  }

  /// الموبايل ممكن يكون قفل الخط وهو في الخلفية
  static void _reconnectNow() {
    if (!_isRunning) return;
    _nextRetry = _firstRetry;
    _retryTimer?.cancel();
    unawaited(_line?.cancel());
    _line = null;
    unawaited(_connect());
  }

  /// صوت واهتزاز والتطبيق مفتوح، والخط والإشعار لو وصلوا مع بعض بيرنوا مرة واحدة
  static void alertUser() {
    final now = DateTime.now();
    final last = _lastAlert;
    if (!isAppVisible || (last != null && now.difference(last) < _alertGap)) return;
    _lastAlert = now;
    unawaited(_device.invokeMethod<void>('alert').catchError((Object _) {}));
  }

  /// تغيير وصل من الإشعار وهو مش على الخط
  static void announce(LiveChange change) => _announce(change);

  static void _announce(LiveChange change) {
    _changes.add(change);
    _pendingKinds.add(change.kind);
    _gatherTimer?.cancel();
    _gatherTimer = Timer(_gatherChanges, () {
      final kinds = Set<String>.of(_pendingKinds);
      _pendingKinds.clear();
      final everything = kinds.contains('all');
      changes.value++;
      if (everything || kinds.contains('orders')) orders.value++;
      if (everything || kinds.contains('requests')) requests.value++;
    });
  }

  static void _remember(int id) {
    _lastId = id;
    unawaited(SavedData.write(_lastIdKey, id));
  }

  /// اللي فات وقت ما الخط كان مقطوع: لو كتير أو قديم، كل حاجة تتحدث مرة واحدة
  static Future<void> _catchUp(int turn) async {
    _lastId ??= (await SavedData.read(_lastIdKey) as num?)?.toInt();
    final known = _lastId;
    final res = await ApiService.get('/events/since', queryParams: {if (known != null) 'after': '$known'});
    if (turn != _turn || !res.isOk || res.data is! Map<String, dynamic>) return;
    final data = res.data as Map<String, dynamic>;
    if (known != null) {
      if (data['reset'] == true) {
        _announce(const LiveChange('all'));
      } else {
        for (final item in (data['changes'] as List? ?? const [])) {
          if (item is Map<String, dynamic>) _announce(LiveChange(item['kind'].toString(), item['entityId']?.toString()));
        }
      }
    }
    final last = (data['last'] as num?)?.toInt();
    if (last != null && last > (_lastId ?? 0)) _remember(last);
  }

  static Future<void> _connect() async {
    final turn = ++_turn;
    try {
      final response = await ApiService.openLine('/events');
      if (turn != _turn || !_isRunning) return;

      if (response.statusCode == 401) {
        // طلب عادي بيجدد الجلسة لو التوكن انتهى
        await ApiService.get('/notifications/summary');
        if (turn == _turn && _isRunning) _retryLater();
        return;
      }
      if (response.statusCode != 200) {
        _retryLater();
        return;
      }

      _nextRetry = _firstRetry;
      _line = response.stream.transform(utf8.decoder).transform(const LineSplitter()).listen(
        (text) {
          if (text.startsWith('id: ')) {
            final id = int.tryParse(text.substring(4).trim());
            if (id != null) _remember(id);
            return;
          }
          if (text.startsWith('data: position ')) {
            final parts = text.split(' ');
            final lat = parts.length > 5 ? double.tryParse(parts[4]) : null;
            final lon = parts.length > 5 ? double.tryParse(parts[5]) : null;
            if (lat != null && lon != null) position.value = LivePoint(parts[2], lat, lon);
            return;
          }
          if (!text.startsWith('data: change')) return;
          final parts = text.split(' ');
          final kind = parts.length > 2 ? parts[2] : 'all';
          final entity = parts.length > 3 && parts[3] != '-' ? parts[3] : null;
          _announce(LiveChange(kind, entity));
          if (text.startsWith('data: change-alert')) alertUser();
        },
        onError: (Object _) {
          if (turn == _turn) _retryLater();
        },
        onDone: () {
          if (turn == _turn) _retryLater();
        },
        cancelOnError: true,
      );
      await _catchUp(turn);
    } catch (_) {
      if (turn == _turn && _isRunning) _retryLater();
    }
  }

  static void _retryLater() {
    if (!_isRunning) return;
    _retryTimer?.cancel();
    _retryTimer = Timer(_nextRetry, () => unawaited(_connect()));
    final doubled = _nextRetry * 2;
    _nextRetry = doubled > _maxRetry ? _maxRetry : doubled;
  }
}
