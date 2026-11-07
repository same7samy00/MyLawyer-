import 'dart:async';

import '../../core/services/api_service.dart';
import '../../core/services/saved_data.dart';
import '../models/support_ticket.dart';

/// تذاكر الدعم الفني للموكل والمحامي
class SupportRepository {
  /// آخر تذاكر اتعرضت، عشان الصفحة تظهر على طول
  static List<SupportTicket>? savedTickets() {
    final value = SavedData.peek('tickets');
    return value is List ? value.whereType<Map<String, dynamic>>().map(SupportTicket.fromJson).toList() : null;
  }

  static Future<ApiResponse<List<SupportTicket>>> getTickets() async {
    final res = await ApiService.get('/support/tickets');
    if (res.isOk && res.data is List) {
      unawaited(SavedData.write('tickets', res.data));
      final tickets = (res.data as List).whereType<Map<String, dynamic>>().map(SupportTicket.fromJson).toList();
      return ApiResponse(success: true, statusCode: res.statusCode, data: tickets);
    }
    return ApiResponse(success: false, statusCode: res.statusCode, error: res.error ?? 'تعذر تحميل التذاكر');
  }

  static Future<ApiResponse<SupportTicket>> getTicket(String id) async {
    final res = await ApiService.get('/support/tickets/$id');
    if (res.isOk && res.data is Map<String, dynamic>) {
      return ApiResponse(success: true, statusCode: res.statusCode, data: SupportTicket.fromJson(res.data as Map<String, dynamic>));
    }
    return ApiResponse(success: false, statusCode: res.statusCode, error: res.error ?? 'تعذر تحميل التذكرة');
  }

  static Future<ApiResponse<dynamic>> createTicket({
    required String category,
    required String title,
    required String body,
    String? orderId,
    List<String> imagePaths = const [],
  }) {
    return ApiService.uploadForm(
      '/support/tickets',
      {'category': category, 'title': title, 'body': body, if (orderId != null) 'orderId': orderId},
      imagePaths,
    );
  }

  static Future<ApiResponse<dynamic>> reply(String ticketId, String body, {List<String> imagePaths = const []}) {
    return ApiService.uploadForm('/support/tickets/$ticketId/messages', {'body': body}, imagePaths);
  }
}
