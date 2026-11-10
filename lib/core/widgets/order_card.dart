import 'dart:async';

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import 'app_card.dart';
import 'service_tag.dart';

/// لون مربع الحالة: ماشي، أو مطلوب منك حاجة بوقت، أو خلص، أو اتقفل
enum OrderCardTone { progress, urgent, done, closed }

/// مراحل «محاميك حالاً» في كل الكروت، للموكل والمحامي
const List<String> urgentOrderStages = ['العروض', 'الاختيار', 'الدفع', 'الوصول', 'الإنهاء'];

/// التاريخ والساعة بشكل واحد في كل الكروت
String orderCardDate(DateTime? date) {
  if (date == null) return '';
  const months = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  return '${date.day} ${months[date.month - 1]} • $hour:$minute ${date.hour >= 12 ? 'م' : 'ص'}';
}

/// الكارت الموحد لكل الطلبات من كل الخدمات، للموكل والمحامي:
/// اسم الخدمة فوق، وبعده العنوان والتفاصيل ومربع الحالة وشريط المراحل، والكارت كله بيفتح التفاصيل
class OrderCard extends StatelessWidget {
  final String service;
  final IconData serviceIcon;
  final String date;
  final String title;
  final String details;
  final String status;
  final IconData statusIcon;
  final OrderCardTone tone;

  /// ثواني باقية بتتعد جنب الحالة، زي مهلة إرسال السعر
  final int? countdownSeconds;

  final List<String> stages;

  /// عدد المراحل اللي خلصت، والمرحلة اللي بعدها هي الحالية
  final int stagesDone;

  /// الطلب وقف عند المرحلة الحالية وما كملش
  final bool isStopped;

  final String reference;
  final VoidCallback? onOpen;

  const OrderCard({
    super.key,
    required this.service,
    required this.serviceIcon,
    required this.title,
    required this.details,
    required this.status,
    required this.statusIcon,
    required this.tone,
    required this.stages,
    required this.stagesDone,
    this.date = '',
    this.reference = '',
    this.countdownSeconds,
    this.isStopped = false,
    this.onOpen,
  });

  Color get _toneColor => switch (tone) {
        OrderCardTone.progress => AppColors.primary,
        OrderCardTone.urgent => AppColors.danger,
        OrderCardTone.done => AppColors.success,
        OrderCardTone.closed => AppColors.textMuted,
      };

  String get _stageText {
    final total = stages.length;
    if (stagesDone >= total) return 'خلص • $total من $total';
    final name = stages[stagesDone];
    return isStopped ? 'وقف عند مرحلة $name' : 'المرحلة ${stagesDone + 1} من $total • $name';
  }

  @override
  Widget build(BuildContext context) {
    final color = _toneColor;
    final seconds = countdownSeconds;
    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: ServiceTag(name: service, icon: serviceIcon)),
              if (date.isNotEmpty) Text(date, style: _muted(11)),
            ],
          ),
          const SizedBox(height: 10),
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _text(15, FontWeight.w800, AppColors.dark)),
          const SizedBox(height: 2),
          Text(details, maxLines: 1, overflow: TextOverflow.ellipsis, style: _muted(12)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(7.0)),
            child: Row(
              children: [
                Icon(statusIcon, size: 18, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: seconds == null
                      ? Text(status, style: _text(13, FontWeight.w800, color))
                      : _CountdownText(label: status, seconds: seconds, style: _text(13, FontWeight.w800, color)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var index = 0; index < stages.length; index++) ...[
                if (index > 0) const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(color: _stageColor(index), borderRadius: BorderRadius.circular(2)),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 5),
          Text(_stageText, style: _muted(11)),
          if (reference.isNotEmpty || onOpen != null) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, thickness: 1, color: AppColors.cardBorder),
            const SizedBox(height: 9),
            Row(
              children: [
                Expanded(child: Text(reference, maxLines: 1, overflow: TextOverflow.ellipsis, style: _muted(12))),
                if (onOpen != null) Text('عرض التفاصيل', style: _text(12, FontWeight.w800, AppColors.primary)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _stageColor(int index) {
    if (index < stagesDone) return AppColors.success;
    if (index > stagesDone) return AppColors.cardBorder;
    return isStopped ? AppColors.textMuted : AppColors.primary;
  }

  static TextStyle _text(double size, FontWeight weight, Color color) =>
      TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: size, fontWeight: weight, color: color);

  static TextStyle _muted(double size) => _text(size, FontWeight.w600, AppColors.textMuted);
}

/// الحالة ومعاها الوقت الباقي، وبيعد لوحده كل ثانية
class _CountdownText extends StatefulWidget {
  final String label;
  final int seconds;
  final TextStyle style;

  const _CountdownText({required this.label, required this.seconds, required this.style});

  @override
  State<_CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<_CountdownText> {
  late DateTime _end = DateTime.now().add(Duration(seconds: widget.seconds));
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(_CountdownText old) {
    super.didUpdateWidget(old);
    if (old.seconds != widget.seconds) _end = DateTime.now().add(Duration(seconds: widget.seconds));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = _end.difference(DateTime.now()).inSeconds;
    if (left <= 0) {
      _timer?.cancel();
      return Text('الوقت خلص', style: widget.style);
    }
    return Text('${widget.label} • باقي ${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')}', style: widget.style);
  }
}
