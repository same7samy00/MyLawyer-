import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api_service.dart';
import 'notification_center.dart';

/// الإشعارات الخلفية يعرضها النظام مباشرة، والدالة دي مطلوبة لتشغيلها والتطبيق مقفول
@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {}

/// تسجيل جهاز المستخدم لاستقبال إشعارات الطلبات والتطبيق مقفول
class PushService {
  PushService._();

  static const AndroidNotificationDetails _alertDetails = AndroidNotificationDetails(
    'alerts',
    'الإشعارات',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
  );

  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
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
      // لمس الإشعار يتسجل الأول، قبل الإذن وتسجيل الجهاز اللي ممكن يتأخروا أو يفشلوا مع النت
      await _listen();

      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      _token = await messaging.getToken();
      await _register(_token);
    } catch (e) {
      debugPrint('Push setup error: $e');
    }
  }

  static Future<void> _listen() async {
    if (_isListening) return;
    _isListening = true;
    final messaging = FirebaseMessaging.instance;

    FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);
    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (response) => _openPayload(response.payload),
    );
    await messaging.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);
    messaging.onTokenRefresh.listen((token) {
      _token = token;
      _register(token);
    });
    // الطلب يظهر فوراً في التطبيق لو كان مفتوحاً
    FirebaseMessaging.onMessage.listen((message) {
      NotificationCenter.refresh();
      _showWhileOpen(message);
    });
    // التطبيق كان في الخلفية واتفتح بلمس الإشعار
    FirebaseMessaging.onMessageOpenedApp.listen((message) => _open(message.data));

    // التطبيق كان مقفول خالص واتفتح بلمس الإشعار
    final initialMessage = await messaging.getInitialMessage();
    final launchDetails = await _localNotifications.getNotificationAppLaunchDetails();
    if (initialMessage != null) {
      _open(initialMessage.data);
    } else if (launchDetails?.didNotificationLaunchApp == true) {
      _openPayload(launchDetails?.notificationResponse?.payload);
    }
  }

  static void _open(Map<String, dynamic> data) {
    NotificationCenter.refresh();
    NotificationCenter.openRequest.value = NotificationTarget.fromMap(data);
  }

  static void _openPayload(String? payload) {
    Map<String, dynamic> data = const {};
    try {
      if (payload != null && payload.isNotEmpty) data = jsonDecode(payload) as Map<String, dynamic>;
    } catch (_) {}
    _open(data);
  }

  /// النظام ما يعرضش الإشعار والتطبيق مفتوح على أندرويد، فيتعرض بنفس الصوت والاهتزاز
  static Future<void> _showWhileOpen(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null || defaultTargetPlatform != TargetPlatform.android) return;
    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(android: _alertDetails),
      payload: jsonEncode(message.data),
    );
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
