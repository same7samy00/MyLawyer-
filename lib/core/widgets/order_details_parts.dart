import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import 'app_card.dart';
import 'order_card.dart';

/// أجزاء صفحة الطلب، مشتركة بين طلبات المحامي والاستشارات عشان الصفحتين بنفس الترتيب والشكل:
/// كارت الرقم، وكارت المراحل وتحتها شارة الحالة، وكارت التفاصيل

/// رقم الطلب صغير ومعاه التاريخ والوقت بأيقوناتهم، والضغط عليه بينسخ الرقم
class OrderNumberCard extends StatelessWidget {
  final String number;
  final DateTime? time;
  final VoidCallback onCopy;

  const OrderNumberCard({super.key, required this.number, required this.time, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      onTap: onCopy,
      child: Row(
        children: [
          const Icon(Icons.tag_rounded, size: 18, color: AppColors.primary),
          const SizedBox(width: 6),
          Expanded(child: Text(number, maxLines: 1, overflow: TextOverflow.ellipsis, style: _number)),
          const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 4),
          Text(orderCardDay(time), style: detailLabelStyle),
          const SizedBox(width: 10),
          const Icon(Icons.schedule_rounded, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 4),
          Text(orderCardTime(time), style: detailLabelStyle),
          const SizedBox(width: 10),
          const Icon(Icons.copy_rounded, size: 18, color: AppColors.textMuted),
        ],
      ),
    );
  }

  static const TextStyle _number = TextStyle(
    fontFamily: 'AppFont',
    fontFamilyFallback: appFontFallback,
    fontSize: 14,
    fontWeight: FontWeight.w800,
    color: AppColors.dark,
  );
}

/// مرحلة في شريط المراحل
typedef TrackerStep = ({IconData icon, String label});

/// شريط المراحل وتحته شارة الحالة [status]. [failedStep] المرحلة اللي الطلب وقف عندها
class StageTracker extends StatelessWidget {
  final List<TrackerStep> steps;
  final int doneSteps;
  final int? failedStep;
  final bool isFinished;
  final Widget status;

  const StageTracker({
    super.key,
    required this.steps,
    required this.doneSteps,
    required this.status,
    this.failedStep,
    this.isFinished = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [for (var index = 0; index < steps.length; index++) Expanded(child: _step(index))],
        ),
        const SizedBox(height: 12),
        status,
      ],
    );
  }

  Widget _step(int index) {
    final step = steps[index];
    final isDone = index < doneSteps;
    final isFailed = index == failedStep;
    final isCurrent = failedStep == null && index == doneSteps && !isFinished;

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
            Expanded(child: _line(index > 0, index <= doneSteps)),
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
            Expanded(child: _line(index < steps.length - 1, index < doneSteps)),
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

  Widget _line(bool isVisible, bool isReached) {
    if (!isVisible) return const SizedBox.shrink();
    return Container(height: 2, color: isReached ? AppColors.success : AppColors.cardBorder);
  }
}

/// كارت التفاصيل: صفوف بينها خط
class DetailsCard extends StatelessWidget {
  final List<Widget> rows;

  const DetailsCard({super.key, required this.rows});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.cardBorder),
            rows[i],
          ],
        ],
      ),
    );
  }
}

/// صف في كارت التفاصيل: العنوان على اليمين والقيمة جنبه. [onTap] بيخليه رابط («عرض الملف»)
class DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final VoidCallback? onTap;

  const DetailRow(this.label, this.value, {super.key, this.valueColor, this.onTap});

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 104, child: Text(label, style: detailLabelStyle)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'AppFont',
                fontFamilyFallback: appFontFallback,
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w800,
                color: valueColor ?? (onTap != null ? AppColors.primary : AppColors.dark),
              ),
            ),
          ),
          if (onTap != null)
            const Text(
              'عرض الملف',
              style: TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
            ),
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(7.0), child: row);
  }
}

const TextStyle detailLabelStyle = TextStyle(
  fontFamily: 'AppFont',
  fontFamilyFallback: appFontFallback,
  fontSize: 12,
  fontWeight: FontWeight.w600,
  color: AppColors.textMuted,
);
