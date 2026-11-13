import 'dart:async';

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import 'app_card.dart';
import 'status_pill.dart';

/// لون مربع الحالة: ماشي، أو مطلوب منك حاجة بوقت، أو خلص، أو اتقفل
enum OrderCardTone { progress, urgent, done, closed }

/// لون كل حالة في الكروت وفي صفحة الطلب
Color orderToneColor(OrderCardTone tone) => switch (tone) {
      OrderCardTone.progress => AppColors.primary,
      OrderCardTone.urgent => AppColors.danger,
      OrderCardTone.done => AppColors.success,
      OrderCardTone.closed => AppColors.textMuted,
    };

/// اليوم والشهر بشكل واحد في كل الكروت، مثلًا: 13 نوفمبر
String orderCardDay(DateTime? date) {
  if (date == null) return '';
  const months = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
  return '${date.day} ${months[date.month - 1]}';
}

/// الساعة بشكل واحد في كل الكروت، مثلًا: 4:20 م
String orderCardTime(DateTime? date) {
  if (date == null) return '';
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  return '$hour:${date.minute.toString().padLeft(2, '0')} ${date.hour >= 12 ? 'م' : 'ص'}';
}

/// الكارت الموحد المختصر لكل الطلبات من كل الخدمات، للموكل والمحامي:
/// فوق أيقونة الخدمة واسمها اللي اتختار فعلًا وسهم، وتحت خط متقطع رقم الطلب والتاريخ والوقت بأيقوناتهم،
/// وتحتهم الحالة بلونها وأيقونتها. الكارت كله بيفتح التفاصيل، وكل التفاصيل التانية في صفحة الطلب
class OrderCard extends StatelessWidget {
  /// اسم الخدمة اللي الموكل اختارها فعلًا، زي «محضر في قسم الشرطة» أو «استشارة بالتليفون»
  final String title;
  final IconData serviceIcon;

  /// رقم الطلب، أو «جديد» للطلب اللي لسه مالوش رقم
  final String number;
  final DateTime? time;
  final String status;
  final IconData statusIcon;
  final OrderCardTone tone;

  /// ثواني باقية بتتعد جوه الحالة، زي مهلة إرسال السعر
  final int? countdownSeconds;
  final VoidCallback? onOpen;

  const OrderCard({
    super.key,
    required this.title,
    required this.serviceIcon,
    required this.number,
    required this.time,
    required this.status,
    required this.statusIcon,
    required this.tone,
    this.countdownSeconds,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final color = orderToneColor(tone);
    final seconds = countdownSeconds;
    return AppCard(
      padding: const EdgeInsets.all(12),
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(7.0)),
                child: Icon(serviceIcon, color: AppColors.primary, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _text(14, FontWeight.w800, AppColors.dark)),
              ),
              if (onOpen != null) const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 24),
            ],
          ),
          const SizedBox(height: 10),
          const DashedDivider(),
          const SizedBox(height: 9),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _info(Icons.tag_rounded, number),
              _info(Icons.calendar_today_rounded, orderCardDay(time)),
              _info(Icons.schedule_rounded, orderCardTime(time)),
            ],
          ),
          const SizedBox(height: 10),
          StatusPill(
            icon: statusIcon,
            color: color,
            child: seconds == null
                ? Text(status, maxLines: 1, overflow: TextOverflow.ellipsis, style: StatusPill.textStyle(color))
                : _CountdownText(label: status, seconds: seconds, style: StatusPill.textStyle(color)),
          ),
        ],
      ),
    );
  }

  static Widget _info(IconData icon, String text) {
    return Flexible(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 4),
          Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: _text(11.5, FontWeight.w600, AppColors.textMuted))),
        ],
      ),
    );
  }

  static TextStyle _text(double size, FontWeight weight, Color color) =>
      TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: size, fontWeight: weight, color: color);
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
