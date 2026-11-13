import 'package:flutter/material.dart';
import '../../core/widgets/order_card.dart';
import '../../data/models/service_request.dart';
import 'legal_services.dart';

/// كارت طلب «محاميك حالاً» لسه ما اتختارش فيه محامي: بيدوّر على محامين، أو وصلته عروض، أو اتقفل من غير اختيار.
/// لما يتختار محامي الطلب بيكمل بنفس الكارت في المرحلة اللي بعدها: نفس اسم الخدمة ونفس الأيقونة (`OrderSummaryCard`)
class RequestOrderCard extends StatelessWidget {
  final MyRequest request;
  final VoidCallback? onOpen;

  const RequestOrderCard({super.key, required this.request, this.onOpen});

  @override
  Widget build(BuildContext context) {
    final isOpen = request.isOpen;
    return OrderCard(
      title: LegalService.titleFor(request.problemType),
      serviceIcon: LegalService.iconFor(request.problemType),
      // الطلب بياخد رقم لما يتختار محامي
      number: isOpen ? 'جديد' : 'من غير محامي',
      time: request.createdAt,
      status: request.statusLabel,
      statusIcon: !isOpen ? Icons.cancel_outlined : (request.offers > 0 ? Icons.receipt_long_rounded : Icons.search_rounded),
      tone: isOpen ? OrderCardTone.progress : OrderCardTone.closed,
      onOpen: isOpen ? onOpen : null,
    );
  }
}
