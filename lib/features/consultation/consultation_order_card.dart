import '../../core/widgets/service_tag.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_sheet.dart';
import '../../data/models/consultation.dart';
import '../../data/repositories/consultation_repository.dart';
import 'consultation_style.dart';

String _dateText(DateTime? date) {
  if (date == null) return '';
  const months = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
  return '${date.day} ${months[date.month - 1]}';
}

Color _statusColor(Consultation item) {
  if (item.canRequestContact) return AppColors.danger;
  return switch (item.status) {
    'DONE' => AppColors.success,
    'REJECTED' => AppColors.textMuted,
    _ => AppColors.primary,
  };
}

/// كارت الاستشارة في صفحة الطلبات، بنفس شكل كروت الطلبات
class ConsultationOrderCard extends StatelessWidget {
  final Consultation item;
  final VoidCallback onOpen;

  const ConsultationOrderCard({super.key, required this.item, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(item);
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ServiceTag(name: 'استشارة سريعة', icon: Icons.support_agent_rounded),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: Text('استشارة رقم ${item.reference}', style: consultationText(13, FontWeight.w900, AppColors.primary))),
              Text(_dateText(item.createdAt), style: consultationText(11, FontWeight.w600, AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 8),
          Text(item.kind.label, style: consultationText(14, FontWeight.w700, AppColors.dark)),
          const SizedBox(height: 4),
          Text('${item.price} ج.م', style: consultationText(11, FontWeight.w600, AppColors.textMuted)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(7.0)),
            child: Row(
              children: [
                Icon(item.canRequestContact ? Icons.phone_missed_rounded : Icons.phone_in_talk_rounded, size: 18, color: color),
                const SizedBox(width: 8),
                Expanded(child: Text(item.statusText, style: consultationText(12.5, FontWeight.w800, color))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppButton.primary(text: 'عرض التفاصيل', height: 40, fontSize: 13, onPressed: onOpen),
        ],
      ),
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

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 96, child: Text(label, style: consultationText(12.5, FontWeight.w700, AppColors.textMuted))),
            Expanded(child: Text(value, style: consultationText(13, FontWeight.w800, AppColors.dark))),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final item = _item;
    final color = _statusColor(item);
    return AppSheet(
      title: 'استشارة ${item.reference}',
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(7.0)),
          child: Row(
            children: [
              Icon(item.canRequestContact ? Icons.phone_missed_rounded : Icons.phone_in_talk_rounded, color: color),
              const SizedBox(width: 10),
              Expanded(child: Text(item.statusText, style: consultationText(14, FontWeight.w900, color))),
            ],
          ),
        ),
        if (item.canRequestContact) ...[
          const SizedBox(height: 10),
          Text(
            'حاولنا نكلمك ومقدرناش نوصلك\nلما تكون متاح اضغط «طلب التواصل» وهنكلمك خلال دقايق',
            style: consultationText(12.5, FontWeight.w600, AppColors.textMain, height: 1.6),
          ),
        ],
        const SizedBox(height: 12),
        _row('نوع الاستشارة', item.kind.label),
        if (item.kind == ConsultationKind.papers) _row('عدد الورق', '${item.pages}'),
        _row('المبلغ', '${item.price} ج.م'),
        _row('التاريخ', _dateText(item.createdAt)),
        if (item.rejectReason != null && item.status == 'REJECTED') _row('سبب الرفض', item.rejectReason!),
        if (item.details.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('تفاصيل المشكلة', style: consultationText(12.5, FontWeight.w700, AppColors.textMuted)),
          const SizedBox(height: 4),
          Text(item.details, maxLines: 6, overflow: TextOverflow.ellipsis, style: consultationText(13, FontWeight.w600, AppColors.textMain, height: 1.6)),
        ],
        if (_notice != null) ...[
          const SizedBox(height: 12),
          Text(_notice!, textAlign: TextAlign.center, style: consultationText(13, FontWeight.w800, AppColors.success, height: 1.5)),
        ],
        const SizedBox(height: 16),
        if (item.canRequestContact)
          AppButton.primary(text: 'طلب التواصل', icon: Icons.call_rounded, height: 48, onPressed: _requestContact)
        else
          AppButton.outlined(text: 'إغلاق', height: 46, onPressed: () => Navigator.of(context).pop()),
      ],
    );
  }
}
