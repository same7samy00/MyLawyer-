import 'package:flutter/material.dart';

import '../../data/models/order_model.dart';
import 'order_card.dart';

/// كارت الطلب بعد اختيار المحامي في صفحة الطلبات، والإجراءات كلها في صفحة التفاصيل
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

  OrderCardTone get _tone {
    if (order.isCompleted) return OrderCardTone.done;
    if (!order.isOngoing) return OrderCardTone.closed;
    // الموكل هو اللي عليه الدفع بوقت
    return order.isAccepted && !isLawyer ? OrderCardTone.urgent : OrderCardTone.progress;
  }

  IconData get _icon {
    if (order.isCompleted) return Icons.check_circle_rounded;
    if (!order.isOngoing) return Icons.cancel_outlined;
    if (order.isAccepted) return isLawyer ? Icons.hourglass_top_rounded : Icons.timer_outlined;
    if (order.isPostponed) return Icons.event_rounded;
    return order.arrivedAt == null ? Icons.navigation_rounded : Icons.verified_user_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final otherParty = isLawyer ? 'الموكل: ${order.clientName ?? '-'}' : 'المحامي: ${order.lawyerName ?? '-'}';
    final isStopped = order.trackerFailedStep != null;

    return OrderCard(
      service: order.serviceTitle,
      serviceIcon: Icons.location_on_rounded,
      date: orderCardDate(DateTime.tryParse(order.createdAt)?.toLocal()),
      title: order.problemType ?? order.serviceTitle,
      details: '$otherParty • ${order.priceText} ج.م',
      status: (isLawyer ? order.lawyerStatusLabel : null) ?? order.statusLabel,
      statusIcon: _icon,
      tone: _tone,
      stages: urgentOrderStages,
      stagesDone: order.trackerDoneSteps,
      isStopped: isStopped,
      reference: 'طلب رقم ${order.orderNumber}',
      onOpen: onOpen,
    );
  }
}
