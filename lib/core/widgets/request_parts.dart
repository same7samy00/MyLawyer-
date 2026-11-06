import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// أجزاء مشتركة بين بطاقة الطلب الجديد وشيت تفاصيله

/// الوقت الباقي لإرسال السعر، أحمر عشان يلفت النظر، وبيعد لوحده كل ثانية
class RequestTimeBadge extends StatefulWidget {
  final int secondsLeft;

  const RequestTimeBadge({super.key, required this.secondsLeft});

  @override
  State<RequestTimeBadge> createState() => _RequestTimeBadgeState();
}

class _RequestTimeBadgeState extends State<RequestTimeBadge> {
  late DateTime _end = DateTime.now().add(Duration(seconds: widget.secondsLeft));
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(RequestTimeBadge old) {
    super.didUpdateWidget(old);
    if (old.secondsLeft != widget.secondsLeft) _end = DateTime.now().add(Duration(seconds: widget.secondsLeft));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = _end.difference(DateTime.now()).inSeconds;
    final isOver = left <= 0;
    if (isOver) _timer?.cancel();
    final text = isOver ? 'الوقت خلص' : '${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')}';
    final color = isOver ? AppColors.textMuted : AppColors.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(7.0)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 14, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 12, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}

/// مربع السعر المسموح
class RequestPriceBox extends StatelessWidget {
  final int minPrice;
  final int maxPrice;
  final int? sentPrice;

  const RequestPriceBox({super.key, required this.minPrice, required this.maxPrice, this.sentPrice});

  @override
  Widget build(BuildContext context) {
    final sent = sentPrice;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(7.0)),
      child: Row(
        children: [
          Text(sent == null ? 'السعر المسموح' : 'عرضك', style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
          const Spacer(),
          Text(
            sent == null ? '$minPrice – $maxPrice ج.م' : '$sent ج.م',
            style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

/// خطوات الطلب جنب بعض: الطلب وصل، السعر، اختيار الموكل، الدفع
class RequestSteps extends StatelessWidget {
  final bool priceSent;

  const RequestSteps({super.key, required this.priceSent});

  @override
  Widget build(BuildContext context) {
    final steps = [('الطلب وصل', true), (priceSent ? 'عرضك اتبعت' : 'ابعت سعرك', priceSent), ('الموكل يختار', false), ('الدفع', false)];
    return Row(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          Expanded(
            child: Column(
              children: [
                Icon(
                  steps[i].$2 ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  size: 18,
                  color: steps[i].$2 ? AppColors.success : (i == (priceSent ? 2 : 1) ? AppColors.primary : AppColors.cardBorder),
                ),
                const SizedBox(height: 4),
                Text(
                  steps[i].$1,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'AppFont',
                    fontFamilyFallback: appFontFallback,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: steps[i].$2 ? AppColors.dark : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// سطر بأيقونة في كارت تفاصيل الطلب
class RequestInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const RequestInfoRow({super.key, required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          SizedBox(
            width: 72,
            child: Text(label, style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 13, height: 1.45, fontWeight: FontWeight.w600, color: AppColors.dark)),
          ),
        ],
      ),
    );
  }
}
