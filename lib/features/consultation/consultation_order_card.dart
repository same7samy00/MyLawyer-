import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/order_card.dart';
import '../../core/widgets/order_details_parts.dart';
import '../../core/widgets/status_pill.dart';
import '../../data/models/consultation.dart';
import '../../data/repositories/consultation_repository.dart';
import 'consultation_style.dart';

/// لون حالة الاستشارة: مطلوب منك تطلب التواصل، أو خلصت، أو اتقفلت، أو ماشية
OrderCardTone _tone(Consultation item) {
  if (item.canRequestContact) return OrderCardTone.urgent;
  if (item.status == 'DONE') return OrderCardTone.done;
  return item.isOngoing ? OrderCardTone.progress : OrderCardTone.closed;
}

IconData _icon(Consultation item) => switch (_tone(item)) {
      OrderCardTone.urgent => Icons.phone_missed_rounded,
      OrderCardTone.done => Icons.check_circle_rounded,
      OrderCardTone.closed => Icons.cancel_outlined,
      OrderCardTone.progress => Icons.phone_in_talk_rounded,
    };

/// كارت الاستشارة في صفحة الطلبات، بنفس شكل كروت الطلبات
class ConsultationOrderCard extends StatelessWidget {
  final Consultation item;
  final VoidCallback onOpen;

  const ConsultationOrderCard({super.key, required this.item, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return OrderCard(
      title: item.serviceTitle,
      serviceIcon: Icons.support_agent_rounded,
      number: item.reference,
      time: item.createdAt,
      status: item.statusText,
      statusIcon: _icon(item),
      tone: _tone(item),
      onOpen: onOpen,
    );
  }
}

/// ملخص الاستشارة وحالتها، و«طلب التواصل» لو الفريق ما قدرش يوصله
class ConsultationSheet extends StatefulWidget {
  final Consultation item;

  const ConsultationSheet({super.key, required this.item});

  static Future<void> open(BuildContext context, Consultation item) {
    return AppSheet.show<void>(context, builder: (_) => ConsultationSheet(item: item));
  }

  @override
  State<ConsultationSheet> createState() => _ConsultationSheetState();
}

class _ConsultationSheetState extends State<ConsultationSheet> {
  late Consultation _item = widget.item;
  String? _notice;

  Future<void> _requestContact() async {
    final res = await ConsultationRepository.requestContact(_item.id);
    if (!mounted) return;
    setState(() {
      if (res.data != null) _item = res.data!;
      _notice = res.isOk ? 'وصلنا طلبك\nفريقنا هيكلمك خلال دقايق' : res.error;
    });
  }

  Future<void> _copyNumber() async {
    await Clipboard.setData(ClipboardData(text: _item.reference));
    if (mounted) setState(() => _notice = 'تم نسخ رقم الطلب');
  }

  /// مراحل الاستشارة: دفعت، وفريقنا بيكلمك، وخلصت. المرفوضة بتقف عند التواصل
  static const List<TrackerStep> _steps = [
    (icon: Icons.payments_rounded, label: 'الدفع'),
    (icon: Icons.phone_in_talk_rounded, label: 'التواصل'),
    (icon: Icons.shield_rounded, label: 'الإنهاء'),
  ];

  @override
  Widget build(BuildContext context) {
    final item = _item;
    final isDone = item.status == 'DONE';
    return AppSheet(
      title: 'تفاصيل الطلب',
      actions: [
        if (item.canRequestContact) AppButton.primary(text: 'طلب التواصل', icon: Icons.call_rounded, height: 48, onPressed: _requestContact),
      ],
      children: [
        if (_notice != null) ...[
          Text(_notice!, textAlign: TextAlign.center, style: consultationText(13, FontWeight.w800, AppColors.success, height: 1.5)),
          const SizedBox(height: 12),
        ],
        OrderNumberCard(number: item.reference, time: item.createdAt, onCopy: _copyNumber),
        const SizedBox(height: 12),
        AppCard(
          padding: const EdgeInsets.all(14),
          child: StageTracker(
            steps: _steps,
            doneSteps: isDone ? 3 : 1,
            failedStep: item.status == 'REJECTED' ? 1 : null,
            isFinished: isDone,
            status: StatusPill(icon: _icon(item), color: orderToneColor(_tone(item)), text: item.statusText),
          ),
        ),
        const SizedBox(height: 12),
        DetailsCard(
          rows: [
            DetailRow('الخدمة', item.serviceTitle),
            DetailRow('نوع الاستشارة', item.kind.label),
            if (item.kind == ConsultationKind.papers) DetailRow('عدد الورق', '${item.pages}'),
            if (item.details.isNotEmpty) DetailRow('تفاصيل المشكلة', item.details),
            DetailRow('المبلغ المدفوع', '${item.price} ج.م', valueColor: AppColors.success),
            if (item.rejectReason != null && item.status == 'REJECTED') DetailRow('سبب الرفض', item.rejectReason!),
          ],
        ),
      ],
    );
  }
}
