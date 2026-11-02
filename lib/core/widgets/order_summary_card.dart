import 'package:flutter/material.dart';
import '../../data/models/order_model.dart';
import '../constants/app_colors.dart';
import 'app_button.dart';
import 'app_card.dart';
import 'order_status_tracker.dart';
import 'response_countdown.dart';

/// ملخص الطلب في صفحة الطلبات، والإجراءات كلها في صفحة التفاصيل
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
    final otherParty = isLawyer ? 'الموكل: ${order.clientName ?? '-'}' : 'المحامي: ${order.lawyerName ?? '-'}';

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (order.isPending) ...[
            ResponseCountdown(secondsLeft: order.responseSecondsLeft),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(child: Text('طلب رقم ${order.orderNumber}', style: _numberStyle)),
              Text(order.formattedDate, style: _mutedStyle),
            ],
          ),
          const SizedBox(height: 8),
          Text(order.problemType ?? order.serviceTitle, style: _titleStyle),
          const SizedBox(height: 4),
          Text('$otherParty • ${order.priceText} ج.م', style: _mutedStyle),
          const SizedBox(height: 14),
          OrderStatusTracker(order: order, statusText: isLawyer ? order.lawyerStatusLabel : null),
          const SizedBox(height: 12),
          AppButton.outlined(text: 'عرض التفاصيل', height: 40, fontSize: 13, onPressed: onOpen),
        ],
      ),
    );
  }

  static const TextStyle _numberStyle = TextStyle(
    fontFamily: 'AppFont',
    fontFamilyFallback: appFontFallback,
    fontSize: 13,
    fontWeight: FontWeight.w900,
    color: AppColors.primary,
  );

  static const TextStyle _titleStyle = TextStyle(
    fontFamily: 'AppFont',
    fontFamilyFallback: appFontFallback,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: AppColors.dark,
  );

  static const TextStyle _mutedStyle = TextStyle(
    fontFamily: 'AppFont',
    fontFamilyFallback: appFontFallback,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: AppColors.textMuted,
  );
}
