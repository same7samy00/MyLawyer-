import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// عد تنازلي لحد وقت معين، زي نهاية إيقاف الحساب
class CountdownText extends StatefulWidget {
  final DateTime until;
  final VoidCallback? onDone;
  final double fontSize;

  const CountdownText({super.key, required this.until, this.onDone, this.fontSize = 22});

  @override
  State<CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<CountdownText> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (!DateTime.now().isBefore(widget.until)) {
        _timer?.cancel();
        widget.onDone?.call();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _text() {
    final left = widget.until.difference(DateTime.now());
    if (left.isNegative) return 'خلاص';
    String two(int n) => n.toString().padLeft(2, '0');
    final clock = '${two(left.inHours % 24)}:${two(left.inMinutes % 60)}:${two(left.inSeconds % 60)}';
    return left.inDays > 0 ? '${left.inDays} يوم و $clock' : clock;
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _text(),
      textAlign: TextAlign.center,
      textDirection: TextDirection.rtl,
      style: TextStyle(
        fontFamily: 'AppFont',
        fontFamilyFallback: appFontFallback,
        fontSize: widget.fontSize,
        fontWeight: FontWeight.w900,
        color: AppColors.danger,
      ),
    );
  }
}
