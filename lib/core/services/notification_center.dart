import 'dart:async';
import 'package:flutter/widgets.dart';
import '../../data/models/lifecycle_models.dart';
import 'api_service.dart';

/// الصفحة اللي الإشعار بيفتحها
class NotificationTarget {
  final String? orderId;
  final String? ticketId;

  const NotificationTarget({this.orderId, this.ticketId});

  factory NotificationTarget.fromMap(Map<String, dynamic> data) {
    String? value(String key) {
      final raw = data[key]?.toString();
      return raw == null || raw.isEmpty ? null : raw;
    }

    return NotificationTarget(orderId: value('orderId'), ticketId: value('ticketId'));
  }
}

/// عدادات الإشعارات والطلبات لشريط التنقل والهيدر أثناء فتح التطبيق
class NotificationCenter {
  NotificationCenter._();

  static final ValueNotifier<int> unread = ValueNotifier<int>(0);
  static final ValueNotifier<int> pendingOrders = ValueNotifier<int>(0);

  /// حالة المحامي من الخادم، فالزر يتبع القواعد تلقائياً
  static final ValueNotifier<bool?> isAvailable = ValueNotifier<bool?>(null);

  /// لمس إشعار من خارج التطبيق يفتح صفحته، أو صفحة الطلبات لو مش مربوط بحاجة
  static final ValueNotifier<NotificationTarget?> openRequest = ValueNotifier<NotificationTarget?>(null);

  /// يتغير بعد تعديل صورة الحساب فتتحدث الكروت المفتوحة
  static final ValueNotifier<int> profileChanged = ValueNotifier<int>(0);

  static Timer? _timer;
  static AppLifecycleListener? _lifecycle;

  /// المحامي عنده دقيقتين للرد، فعداده يتحدث أسرع من الموكل
  static void start({Duration interval = const Duration(seconds: 60)}) {
    _timer?.cancel();
    refresh();
    _timer = Timer.periodic(interval, (_) {
      // مفيش طلبات والتطبيق في الخلفية، والإشعارات شغالة من غيرها
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) refresh();
    });
    _lifecycle ??= AppLifecycleListener(onResume: refresh);
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
    unread.value = 0;
    pendingOrders.value = 0;
    isAvailable.value = null;
  }

  static Future<void> refresh() async {
    final res = await ApiService.get('/notifications/summary');
    if (!res.isOk || res.data is! Map<String, dynamic>) return;

    final data = res.data as Map<String, dynamic>;
    unread.value = (data['unread'] as num? ?? 0).toInt();
    pendingOrders.value = (data['pendingOrders'] as num? ?? 0).toInt();
    if (data['isAvailable'] is bool) isAvailable.value = data['isAvailable'] as bool;
  }

  static Future<ApiResponse<List<AppNotification>>> load() async {
    final res = await ApiService.get('/notifications');
    if (res.isOk && res.data is List) {
      return ApiResponse<List<AppNotification>>(
        success: true,
        statusCode: res.statusCode,
        data: (res.data as List)
            .map((item) => AppNotification.fromJson(item as Map<String, dynamic>))
            .toList(),
      );
    }
    return ApiResponse<List<AppNotification>>(
      success: false,
      statusCode: res.statusCode,
      error: res.error ?? 'تعذر تحميل الإشعارات',
    );
  }

  /// إشعار واحد من القائمة
  static Future<void> markRead(String id) async {
    if (unread.value > 0) unread.value -= 1;
    await ApiService.post('/notifications/read', {'id': id});
  }

  /// الإشعار اللي فتحه المستخدم من خارج التطبيق
  static Future<void> markTargetRead(NotificationTarget target) async {
    if (target.orderId == null && target.ticketId == null) return;
    await ApiService.post('/notifications/read', {
      if (target.orderId != null) 'orderId': target.orderId,
      if (target.ticketId != null) 'ticketId': target.ticketId,
    });
    await refresh();
  }

  static Future<void> markAllRead() async {
    unread.value = 0;
    await ApiService.post('/notifications/read-all', {});
  }
}
