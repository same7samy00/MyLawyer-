import 'package:flutter/material.dart';

import '../../data/models/order_model.dart';
import '../../features/client/legal_services.dart';
import 'order_card.dart';

/// لون حالة الطلب: خلص، أو اتقفل، أو مطلوب من الموكل يدفع بوقت، أو ماشي
OrderCardTone orderTone(OrderModel order, {required bool isLawyer}) {
  if (order.isCompleted) return OrderCardTone.done;
  if (!order.isOngoing) return OrderCardTone.closed;
  // الموكل هو اللي عليه الدفع بوقت
  return order.isAccepted && !isLawyer ? OrderCardTone.urgent : OrderCardTone.progress;
}

/// أيقونة حالة الطلب، في الكارت وفي صفحة الطلب
IconData orderStatusIcon(OrderModel order, {required bool isLawyer}) {
  if (order.isCompleted) return Icons.check_circle_rounded;
  if (!order.isOngoing) return Icons.cancel_outlined;
  if (order.isAccepted) return isLawyer ? Icons.hourglass_top_rounded : Icons.timer_outlined;
  if (order.isPostponed) return Icons.event_rounded;
  return order.arrivedAt == null ? Icons.navigation_rounded : Icons.verified_user_rounded;
}

/// كارت الطلب بعد اختيار المحامي في صفحة الطلبات، والإجراءات كلها في صفحة التفاصيل.
/// اسم الخدمة وأيقونتها زي كارته قبل اختيار المحامي (`RequestOrderCard`)، فالطلب الواحد شكله واحد في كل مراحله
class OrderSummaryCard extends StatelessWidget {
  final OrderModel order;
  final bool isLawyer;
  final VoidCallback onOpen;

  const OrderSummaryCard({
    super.key,
    required this.order,
    required this.onOpen,
    this.isLawyer = false,
  });

  @override
  Widget build(BuildContext context) {
    return OrderCard(
      title: LegalService.titleFor(order.problemType ?? order.serviceTitle),
      serviceIcon: LegalService.iconFor(order.problemType),
      number: order.orderNumber,
      time: DateTime.tryParse(order.createdAt)?.toLocal(),
      status: (isLawyer ? order.lawyerStatusLabel : null) ?? order.statusLabel,
      statusIcon: orderStatusIcon(order, isLawyer: isLawyer),
      tone: orderTone(order, isLawyer: isLawyer),
      onOpen: onOpen,
    );
  }
}
