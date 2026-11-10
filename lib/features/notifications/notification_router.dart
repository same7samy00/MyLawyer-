import 'package:flutter/material.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/notification_center.dart';
import '../../core/widgets/app_message.dart';
import '../../core/widgets/my_reviews_screen.dart';
import '../../data/models/service_request.dart';
import '../../data/repositories/consultation_repository.dart';
import '../../data/repositories/order_repository.dart';
import '../../data/repositories/request_repository.dart';
import '../consultation/consultation_order_card.dart';
import '../lawyer/request_offer_sheet.dart';
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

    // استشارة: ملخصها وحالتها في نفس شيت صفحة الطلبات
    final consultationId = target.consultationId;
    if (consultationId != null) {
      final res = await ConsultationRepository.get(consultationId);
      if (!context.mounted || res.data == null) return false;
      await ConsultationSheet.open(context, res.data!);
      return true;
    }

    final isLawyer = await AuthService.currentRole() == 'lawyer';
    if (!context.mounted) return false;

    // «تقييم جديد» بيفتح تقييمات المحامي، مش الطلب
    if (target.screen == 'reviews' && isLawyer) return MyReviewsScreen.openForMe(context);
    if (!context.mounted) return false;

    final requestId = target.requestId;
    if (requestId != null) {
      // الموكل بيشوف عروضه في خريطة الطلب، فالإشعار هنا ما بيفتحش حاجة
      if (!isLawyer) return false;
      final res = await RequestRepository.incoming();
      final request = (res.data ?? const <IncomingRequest>[]).where((item) => item.id == requestId).firstOrNull;
      if (!context.mounted) return false;
      if (request == null || request.isChosen) {
        showAppMessage(context, const SnackBar(content: Text('الطلب ده اتقفل')));
        return true;
      }
      await RequestOfferSheet.open(context, request);
      return true;
    }

    final orderId = target.orderId;
    if (orderId == null) return false;

    // النسخة المحفوظة بتفتح على طول، والشيت بيجيب الجديد من السيرفر
    final saved = (await OrderRepository.savedOrders()).where((item) => item.id == orderId).firstOrNull;
    final order = saved ?? (await OrderRepository.getOrderById(orderId)).data;
    if (order == null || !context.mounted) return false;
    await OrderDetailsSheet.open(context, order, isLawyer: isLawyer);
    return true;
  }
}
