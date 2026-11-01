import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// عداد مهلة رد المحامي، ويظهر بنفس الشكل عند الموكل والمحامي
class ResponseCountdown extends StatefulWidget {
  final int secondsLeft;
  final int totalSeconds;
  final VoidCallback? onFinished;

  const ResponseCountdown({
    super.key,
    required this.secondsLeft,
    this.totalSeconds = 120,
    this.onFinished,
  });

  @override
  State<ResponseCountdown> createState() => _ResponseCountdownState();
}

class _ResponseCountdownState extends State<ResponseCountdown> {
  late DateTime _endsAt;
  late int _left;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _restart();
  }

  @override
  void didUpdateWidget(covariant ResponseCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    // قيمة السيرفر تصحح العداد لو ابتعد عنها أكثر من ثانيتين
    if ((widget.secondsLeft - _left).abs() > 2) _restart();
  }

  void _restart() {
    _timer?.cancel();
    _endsAt = DateTime.now().add(Duration(seconds: widget.secondsLeft));
    _left = widget.secondsLeft;
    if (_left > 0) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    }
  }

  void _tick() {
    final left = _endsAt.difference(DateTime.now()).inMilliseconds / 1000;
    final seconds = left <= 0 ? 0 : left.ceil();
    if (seconds != _left) setState(() => _left = seconds);

    if (seconds == 0) {
      _timer?.cancel();
      widget.onFinished?.call();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUrgent = _left <= 10;
    final color = isUrgent ? AppColors.danger : AppColors.primary;
    final isOver = _left == 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: isUrgent ? AppColors.danger.withOpacity(0.07) : AppColors.primaryLight,
        borderRadius: BorderRadius.circular(7.0),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.timer_rounded, size: 17, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  isOver ? 'انتهى وقت الرد' : 'باقي $_left ثانية للرد',
                  style: TextStyle(
                    fontFamily: 'AppFont',
                    fontFamilyFallback: appFontFallback,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(7.0),
            child: LinearProgressIndicator(
              value: (_left / widget.totalSeconds).clamp(0.0, 1.0),
              minHeight: 5,
              color: color,
              backgroundColor: color.withOpacity(0.15),
            ),
          ),
        ],
      ),
    );
  }
}
