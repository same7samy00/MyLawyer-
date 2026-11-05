import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/notification_center.dart';
import '../../core/services/api_service.dart';
import '../../data/models/order_model.dart';
import '../../data/repositories/order_repository.dart';
import '../support/ticket_details_screen.dart';
import '../urgent_service/order_details_sheet.dart';

/// يفتح الصفحة اللي الإشعار بيتكلم عنها: التذكرة، أو تفاصيل الطلب
class NotificationRouter {
  NotificationRouter._();

  /// يرجع false لو الإشعار مش مربوط بصفحة معينة
  static Future<bool> open(BuildContext context, NotificationTarget target) async {
    final navigator = Navigator.of(context);

    final ticketId = target.ticketId;
    if (ticketId != null) {
      await navigator.push(MaterialPageRoute(builder: (_) => TicketDetailsScreen(ticketId: ticketId)));
      return true;
    }

    final orderId = target.orderId;
    if (orderId == null) return false;

    final results = await Future.wait([OrderRepository.getOrders(), AuthService.currentRole()]);
    final orders = results[0] as ApiResponse<List<OrderModel>>;
    final isLawyer = results[1] == 'lawyer';
    if (!orders.isOk) return false;
    final order = (orders.data ?? const <OrderModel>[]).where((item) => item.id == orderId).firstOrNull;
    if (order == null) return false;

    if (!context.mounted) return false;
    await OrderDetailsSheet.open(context, order, isLawyer: isLawyer);
    return true;
  }
}
