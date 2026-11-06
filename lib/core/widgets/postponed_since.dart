import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// «المهمة مؤجلة بقالها ...»: عداد بيزيد كل ثانية من وقت التأجيل
class PostponedSince extends StatefulWidget {
  final DateTime since;
  final String note;

  const PostponedSince({super.key, required this.since, required this.note});

  @override
  State<PostponedSince> createState() => _PostponedSinceState();
}

class _PostponedSinceState extends State<PostponedSince> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _elapsed {
    final passed = DateTime.now().difference(widget.since.toLocal());
    final total = passed.isNegative ? Duration.zero : passed;
    String two(int value) => value.toString().padLeft(2, '0');
    final clock = '${two(total.inHours % 24)}:${two(total.inMinutes % 60)}:${two(total.inSeconds % 60)}';
    final days = total.inDays;
    return days > 0 ? '$days يوم و $clock' : clock;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(7.0),
      ),
      child: Column(
        children: [
          const Text(
            'المهمة مؤجلة بقالها',
            style: TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted),
          ),
          const SizedBox(height: 2),
          Text(
            _elapsed,
            textDirection: TextDirection.ltr,
            style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.primary),
          ),
          const SizedBox(height: 2),
          Text(
            widget.note,
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMain),
          ),
        ],
      ),
    );
  }
}
