import 'package:flutter/material.dart';
import '../../core/widgets/order_card.dart';
import '../../data/models/service_request.dart';

/// كارت طلب «محاميك حالاً» لسه ما اتختارش فيه محامي: بيدوّر على محامين، أو وصلته عروض، أو اتقفل من غير اختيار.
/// لما يتختار محامي الطلب بيكمل بنفس الكارت في المرحلة اللي بعدها
class RequestOrderCard extends StatelessWidget {
  final MyRequest request;
  final VoidCallback? onOpen;

  const RequestOrderCard({super.key, required this.request, this.onOpen});

  @override
  Widget build(BuildContext context) {
    final isOpen = request.isOpen;
    return OrderCard(
      service: request.serviceTitle,
      serviceIcon: Icons.location_on_rounded,
      date: orderCardDate(request.createdAt),
      title: request.problemType,
      details: 'السعر من ${request.minPrice} لـ ${request.maxPrice} ج.م',
      status: request.statusLabel,
      statusIcon: !isOpen ? Icons.cancel_outlined : (request.offers > 0 ? Icons.receipt_long_rounded : Icons.search_rounded),
      tone: isOpen ? OrderCardTone.progress : OrderCardTone.closed,
      stages: urgentOrderStages,
      stagesDone: 0,
      isStopped: !isOpen,
      reference: isOpen ? 'طلب جديد' : 'طلب من غير محامي',
      onOpen: isOpen ? onOpen : null,
    );
  }
}
