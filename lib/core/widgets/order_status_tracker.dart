import 'package:flutter/material.dart';
import '../../data/models/order_model.dart';
import 'order_details_parts.dart';

/// مراحل «محاميك حالاً» في صفحة الطلب للموكل والمحامي، وتحتها شارة الحالة [status]
class OrderStatusTracker extends StatelessWidget {
  final OrderModel order;

  /// شارة الحالة تحت المراحل، وبتتحدث لوحدها (`StatusPill` أو شارة وقت الوصول)
  final Widget status;

  const OrderStatusTracker({super.key, required this.order, required this.status});

  static const List<TrackerStep> _steps = [
    (icon: Icons.receipt_long_rounded, label: 'العروض'),
    (icon: Icons.verified_user_rounded, label: 'الاختيار'),
    (icon: Icons.payments_rounded, label: 'الدفع'),
    (icon: Icons.location_on_rounded, label: 'الوصول'),
    (icon: Icons.shield_rounded, label: 'الإنهاء'),
  ];

  @override
  Widget build(BuildContext context) {
    return StageTracker(
      steps: _steps,
      doneSteps: order.trackerDoneSteps,
      failedStep: order.trackerFailedStep,
      isFinished: order.isCompleted,
      status: status,
    );
  }
}
