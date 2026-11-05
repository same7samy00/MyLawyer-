import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'api_service.dart';

/// خط مفتوح مع السيرفر: أول ما حاجة تخص المستخدم تتغير، الصفحات المفتوحة تتحدث.
/// لو الخط قطع بيتوصل تاني لوحده، والصفحات بتتحدث أول ما يرجع عشان ما يفوتهاش حاجة.
class LiveUpdates {
  LiveUpdates._();

  /// بيزيد مع كل تغيير، والصفحات بتسمعه
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);

  static const Duration _firstRetry = Duration(seconds: 2);
  static const Duration _maxRetry = Duration(seconds: 30);
  static const Duration _gatherChanges = Duration(milliseconds: 150);

  static StreamSubscription<String>? _line;
  static Timer? _retryTimer;
  static Timer? _gatherTimer;
  static AppLifecycleListener? _lifecycle;
  static Duration _nextRetry = _firstRetry;
  static bool _isRunning = false;
  static int _turn = 0;

  static void start() {
    if (_isRunning) return;
    _isRunning = true;
    _lifecycle ??= AppLifecycleListener(onResume: _reconnectNow);
    unawaited(_connect());
  }

  static void stop() {
    _isRunning = false;
    _turn++;
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

  static void _announce() {
    _gatherTimer?.cancel();
    _gatherTimer = Timer(_gatherChanges, () => changes.value++);
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
      _announce();
      _line = response.stream.transform(utf8.decoder).transform(const LineSplitter()).listen(
        (text) {
          if (text.startsWith('data: change')) _announce();
        },
        onError: (Object _) {
          if (turn == _turn) _retryLater();
        },
        onDone: () {
          if (turn == _turn) _retryLater();
        },
        cancelOnError: true,
      );
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
