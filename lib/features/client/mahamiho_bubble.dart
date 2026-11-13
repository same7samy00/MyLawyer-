import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// فقاعة كلام محاميحو: زرقا صغيرة وطرفها جزء منها (شكل واحد مش حتتين)، ووراها فقاعة أزرق فاتح.
/// بتتنفخ من طرفها أول ما تظهر، والكلام بيتكتب حرف حرف ويتمسح ويتكتب اللي بعده، فما يظهرش مرة واحدة.
/// الطرف تحت على الشمال، فمحاميحو لازم يكون على شمالها
class MahamihoBubble extends StatefulWidget {
  /// الكلام على مرات، كل واحدة بتتكتب لوحدها
  final List<String> lines;
  final double maxWidth;

  /// قبل ما تتنفخ، عشان تستنى محاميحو يطلع
  final Duration delay;

  const MahamihoBubble({super.key, required this.lines, this.maxWidth = 170, this.delay = Duration.zero});

  @visibleForTesting
  static const typeEvery = Duration(milliseconds: 38);
  static const eraseEvery = Duration(milliseconds: 16);
  static const holdFull = Duration(milliseconds: 1400);

  @override
  State<MahamihoBubble> createState() => _MahamihoBubbleState();
}

class _MahamihoBubbleState extends State<MahamihoBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _pop;
  Timer? _timer;
  int _line = 0;
  int _shown = 0;
  bool _erasing = false;

  @override
  void initState() {
    super.initState();
    _pop = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
    _timer = Timer(widget.delay, () {
      if (!mounted) return;
      _pop.forward();
      _tick();
    });
  }

  @override
  void didUpdateWidget(MahamihoBubble old) {
    super.didUpdateWidget(old);
    // كلام جديد بيبدأ يتكتب من الأول
    if (old.lines.join('\n') != widget.lines.join('\n') && _pop.value > 0) {
      _timer?.cancel();
      setState(() {
        _line = 0;
        _shown = 0;
        _erasing = false;
      });
      _tick();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pop.dispose();
    super.dispose();
  }

  String get _text => widget.lines.isEmpty ? '' : widget.lines[_line % widget.lines.length];

  void _tick() {
    if (!mounted || widget.lines.isEmpty) return;
    final full = _text.length;
    if (!_erasing) {
      if (_shown < full) {
        setState(() => _shown++);
        _timer = Timer(MahamihoBubble.typeEvery, _tick);
        return;
      }
      // جملة واحدة بس بتفضل مكتوبة
      if (widget.lines.length == 1) return;
      _erasing = true;
      _timer = Timer(MahamihoBubble.holdFull, _tick);
      return;
    }
    if (_shown > 0) {
      setState(() => _shown--);
      _timer = Timer(MahamihoBubble.eraseEvery, _tick);
      return;
    }
    setState(() {
      _erasing = false;
      _line = (_line + 1) % widget.lines.length;
    });
    _timer = Timer(const Duration(milliseconds: 250), _tick);
  }

  @override
  Widget build(BuildContext context) {
    final text = _text;
    final shown = text.substring(0, _shown.clamp(0, text.length));
    return Semantics(
      label: widget.lines.join('، '),
      child: ScaleTransition(
        scale: CurvedAnimation(parent: _pop, curve: Curves.elasticOut),
        alignment: Alignment.bottomLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: 112, maxWidth: widget.maxWidth),
          child: CustomPaint(
            painter: _BubblePainter(),
            child: Padding(
              // تحت فيه مكان الطرف، وفوق على اليمين مكان الفقاعة اللي ورا
              padding: const EdgeInsets.fromLTRB(11, 15, 11, _BubblePainter.tail + 9),
              child: Text(
                // مسافة مخفية بتحجز طول الجملة كلها عشان الفقاعة ما تكبرش وهي بتكتب
                shown.isEmpty ? ' ' : shown,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: const TextStyle(
                  fontFamily: 'AppFont',
                  fontFamilyFallback: appFontFallback,
                  fontSize: 11.5,
                  height: 1.45,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// الفقاعة الزرقا وطرفها مرسومين خط واحد، ووراها فقاعة فاتحة مزاحة لفوق ولليمين
class _BubblePainter extends CustomPainter {
  static const double tail = 8;
  static const double radius = 7;
  static const double back = 6;

  Path _shape(Rect body) {
    // جسم الفقاعة بحواف 7، والطرف طالع من الحافة اللي تحت بخط ناعم ومن غير فاصل
    const r = radius;
    final tipX = body.left + 10;
    return Path()
      ..moveTo(body.left + r, body.top)
      ..lineTo(body.right - r, body.top)
      ..arcToPoint(Offset(body.right, body.top + r), radius: const Radius.circular(r))
      ..lineTo(body.right, body.bottom - r)
      ..arcToPoint(Offset(body.right - r, body.bottom), radius: const Radius.circular(r))
      ..lineTo(tipX + 14, body.bottom)
      ..quadraticBezierTo(tipX + 4, body.bottom + 1, tipX - 2, body.bottom + tail)
      ..quadraticBezierTo(tipX + 1, body.bottom + 2, tipX - 1, body.bottom)
      ..lineTo(body.left + r, body.bottom)
      ..arcToPoint(Offset(body.left, body.bottom - r), radius: const Radius.circular(r))
      ..lineTo(body.left, body.top + r)
      ..arcToPoint(Offset(body.left + r, body.top), radius: const Radius.circular(r))
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final body = Rect.fromLTRB(0, back, size.width - back, size.height - tail);
    final behind = RRect.fromRectAndRadius(body.shift(const Offset(back, -back)), const Radius.circular(radius));
    canvas.drawRRect(behind, Paint()..color = AppColors.primary.withOpacity(0.18));
    canvas.drawPath(_shape(body), Paint()..color = AppColors.primary);
  }

  @override
  bool shouldRepaint(_BubblePainter oldDelegate) => false;
}

/// محاميحو بيطلع من ورا الحافة اللي تحته لفوق برجّة خفيفة، مرة واحدة أول ما يظهر، فمفيش فراغ تحته أبدًا.
/// بعد كده بيفضل ثابت، والفقاعة هي اللي بتتحدث بالكلام
class MahamihoRise extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const MahamihoRise({super.key, required this.child, this.delay = Duration.zero});

  @override
  State<MahamihoRise> createState() => _MahamihoRiseState();
}

class _MahamihoRiseState extends State<MahamihoRise> with SingleTickerProviderStateMixin {
  late final AnimationController _rise;
  Timer? _wait;

  @override
  void initState() {
    super.initState();
    _rise = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
    if (widget.delay == Duration.zero) {
      _rise.forward();
    } else {
      _wait = Timer(widget.delay, () {
        if (mounted) _rise.forward();
      });
    }
  }

  @override
  void dispose() {
    _wait?.cancel();
    _rise.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rise = CurvedAnimation(parent: _rise, curve: Curves.easeOutBack);
    return ClipRect(
      child: AnimatedBuilder(
        animation: rise,
        child: widget.child,
        builder: (context, child) => FractionalTranslation(translation: Offset(0, 1 - rise.value), child: child),
      ),
    );
  }
}
