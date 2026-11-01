import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'notification_center.dart';

/// الإشعارات الخلفية يعرضها النظام مباشرة، والدالة دي مطلوبة لتشغيلها والتطبيق مقفول
@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {}

/// تسجيل جهاز المستخدم لاستقبال إشعارات الطلبات والتطبيق مقفول
class PushService {
  PushService._();

  static bool _isListening = false;
  static String? _token;

  /// نافذة إذن الإشعارات قبل تسجيل الدخول
  static Future<void> requestPermission() async {
    try {
      await Firebase.initializeApp();
      await FirebaseMessaging.instance.requestPermission();
    } catch (e) {
      debugPrint('Push permission error: $e');
    }
  }

  static Future<void> start() async {
    try {
      await Firebase.initializeApp();
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();

      _token = await messaging.getToken();
      await _register(_token);

      if (_isListening) return;
      _isListening = true;

      FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);
      messaging.onTokenRefresh.listen((token) {
        _token = token;
        _register(token);
      });
      // الطلب يظهر فوراً في التطبيق لو كان مفتوحاً أو اتفتح من الإشعار
      FirebaseMessaging.onMessage.listen((_) => NotificationCenter.refresh());
      FirebaseMessaging.onMessageOpenedApp.listen((_) => NotificationCenter.refresh());
    } catch (e) {
      debugPrint('Push setup error: $e');
    }
  }

  static Future<void> _register(String? token) async {
    if (token == null) return;
    await ApiService.post('/notifications/device-token', {
      'token': token,
      'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
    });
  }

  /// عند تسجيل الخروج الجهاز يبطل يستقبل إشعارات الحساب
  static Future<void> stop() async {
    final token = _token;
    if (token == null) return;
    _token = null;
    await ApiService.post(
      '/notifications/device-token/remove',
      {'token': token},
      timeout: const Duration(seconds: 5),
    );
  }
}
