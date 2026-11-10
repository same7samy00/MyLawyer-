import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api_service.dart';

/// أي عطل يحصل في التطبيق على موبايل أي مستخدم بيتبعت لسيرفرنا (`POST /app/errors`)، فنعرف بيه ونصلّحه.
/// من غير أي مكتبة ولا أي شركة تانية: رسالة العطل ومكانه في الكود بس، ومفيش أي بيانات من الشاشة.
class ErrorReporter {
  ErrorReporter._();

  /// عطل واحد بيتكرر في كل إطار ما يبعتش مئات الرسايل
  static const int _maxPerRun = 5;
  static final Set<String> _sent = <String>{};

  static void start() {
    final showInConsole = FlutterError.onError;
    FlutterError.onError = (details) {
      showInConsole?.call(details);
      report(details.exception, details.stack);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      report(error, stack);
      // العطل اتسجل، والتطبيق يكمل
      return true;
    };
  }

  static void report(Object error, StackTrace? stack) {
    final message = error.toString();
    final short = message.length > 500 ? message.substring(0, 500) : message;
    if (_sent.length >= _maxPerRun || !_sent.add(short)) return;
    final trace = stack?.toString() ?? '';
    unawaited(
      ApiService.post('/app/errors', {
        'message': short,
        'stack': trace.length > 4000 ? trace.substring(0, 4000) : trace,
        'platform': defaultTargetPlatform.name,
      }).catchError((Object _) => const ApiResponse<dynamic>(success: false, statusCode: 0)),
    );
  }

  @visibleForTesting
  static void reset() => _sent.clear();
}
