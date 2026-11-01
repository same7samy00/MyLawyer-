import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/models/lifecycle_models.dart';
import 'api_service.dart';

/// عدادات الإشعارات والطلبات لشريط التنقل والهيدر أثناء فتح التطبيق
class NotificationCenter {
  NotificationCenter._();

  static final ValueNotifier<int> unread = ValueNotifier<int>(0);
  static final ValueNotifier<int> pendingOrders = ValueNotifier<int>(0);

  static Timer? _timer;

  /// المحامي عنده دقيقتين للرد، فعداده يتحدث أسرع من الموكل
  static void start({Duration interval = const Duration(seconds: 20)}) {
    _timer?.cancel();
    refresh();
    _timer = Timer.periodic(interval, (_) => refresh());
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
    unread.value = 0;
    pendingOrders.value = 0;
  }

  static Future<void> refresh() async {
    final res = await ApiService.get('/notifications/summary');
    if (!res.isOk || res.data is! Map<String, dynamic>) return;

    final data = res.data as Map<String, dynamic>;
    unread.value = (data['unread'] as num? ?? 0).toInt();
    pendingOrders.value = (data['pendingOrders'] as num? ?? 0).toInt();
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

  static Future<void> markAllRead() async {
    unread.value = 0;
    await ApiService.post('/notifications/read-all', {});
  }
}
