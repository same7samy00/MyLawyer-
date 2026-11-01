import 'package:flutter/material.dart';
import '../../data/models/order_model.dart';
import '../constants/app_colors.dart';

/// شريط تتبع حالة الطلب أسفل كروت الطلبات للموكل والمحامي
class OrderStatusTracker extends StatelessWidget {
  final OrderModel order;

  /// نص الحالة أسفل الشريط لو يختلف عن النص الافتراضي للطلب
  final String? statusText;

  const OrderStatusTracker({super.key, required this.order, this.statusText});

  static const _steps = [
    (icon: Icons.receipt_long_rounded, label: 'الطلب'),
    (icon: Icons.verified_user_rounded, label: 'القبول'),
    (icon: Icons.payments_rounded, label: 'الدفع'),
    (icon: Icons.location_on_rounded, label: 'الوصول'),
    (icon: Icons.shield_rounded, label: 'الإنهاء'),
  ];

  @override
  Widget build(BuildContext context) {
    final failedStep = order.trackerFailedStep;
    final doneSteps = order.trackerDoneSteps;
    final statusColor = failedStep != null
        ? AppColors.danger
        : order.isCompleted
            ? AppColors.success
            : AppColors.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < _steps.length; index++)
              Expanded(child: _buildStep(index, doneSteps, failedStep)),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          statusText ?? order.statusLabel,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'AppFont',
            fontFamilyFallback: appFontFallback,
            fontSize: 12.5,
            fontWeight: FontWeight.w900,
            color: statusColor,
          ),
        ),
      ],
    );
  }

  Widget _buildStep(int index, int doneSteps, int? failedStep) {
    final step = _steps[index];
    final isDone = index < doneSteps;
    final isFailed = index == failedStep;
    final isCurrent = failedStep == null && index == doneSteps && !order.isCompleted;

    final Color circleColor;
    final Color iconColor;
    if (isFailed) {
      circleColor = AppColors.danger;
      iconColor = Colors.white;
    } else if (isDone) {
      circleColor = AppColors.success;
      iconColor = Colors.white;
    } else if (isCurrent) {
      circleColor = AppColors.primaryLight;
      iconColor = AppColors.primary;
    } else {
      circleColor = AppColors.background;
      iconColor = AppColors.textMuted;
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildLine(index > 0, index <= doneSteps)),
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: circleColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isCurrent ? AppColors.primary : (isDone || isFailed ? circleColor : AppColors.cardBorder),
                  width: 1.2,
                ),
              ),
              child: Icon(isFailed ? Icons.close_rounded : step.icon, size: 15, color: iconColor),
            ),
            Expanded(child: _buildLine(index < _steps.length - 1, index < doneSteps)),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          step.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'AppFont',
            fontFamilyFallback: appFontFallback,
            fontSize: 10.5,
            fontWeight: isDone || isCurrent || isFailed ? FontWeight.w800 : FontWeight.w600,
            color: isFailed
                ? AppColors.danger
                : isCurrent
                    ? AppColors.primary
                    : isDone
                        ? AppColors.dark
                        : AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildLine(bool isVisible, bool isReached) {
    if (!isVisible) return const SizedBox.shrink();
    return Container(height: 2, color: isReached ? AppColors.success : AppColors.cardBorder);
  }
}
