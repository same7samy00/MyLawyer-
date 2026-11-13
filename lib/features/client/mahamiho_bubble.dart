import 'dart:async';
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// فقاعة كلام محاميحو: زرقا مليانة وحوافها 7 ومن غير ظل ومن غير دبوس (مثلث)، وحواليها إطار تاني بخط أزرق متقطع وبينهم فراغ.
/// بتظهر بتلاشي، والكلام بيتكتب حرف حرف ويتمسح ويتكتب اللي بعده، فما يظهرش مرة واحدة.
/// بتتحط جنب راس محاميحو بمسافة صغيرة من غير ما تلزق فيه
class MahamihoBubble extends StatefulWidget {
  /// الكلام على مرات، كل واحدة بتتكتب لوحدها
  final List<String> lines;
  final double maxWidth;

  /// قبل ما تظهر، عشان تستنى محاميحو يطلع
  final Duration delay;

  /// false: بيقول الجمل مرة واحدة وبعد آخر جملة بيستنى لحظة وينده [onDone]. true: بيلف على الجمل
  final bool loop;
  final VoidCallback? onDone;

  const MahamihoBubble({
    super.key,
    required this.lines,
    this.maxWidth = 170,
    this.delay = Duration.zero,
    this.loop = true,
    this.onDone,
  });

  @visibleForTesting
  static const typeEvery = Duration(milliseconds: 38);
  static const eraseEvery = Duration(milliseconds: 16);
  static const holdFull = Duration(milliseconds: 1400);

  @override
  State<MahamihoBubble> createState() => _MahamihoBubbleState();
}

class _MahamihoBubbleState extends State<MahamihoBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _fade;
  Timer? _timer;
  int _line = 0;
  int _shown = 0;
  bool _erasing = false;

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
    _timer = Timer(widget.delay, () {
      if (!mounted) return;
      _fade.forward();
      _tick();
    });
  }

  @override
  void didUpdateWidget(MahamihoBubble old) {
    super.didUpdateWidget(old);
    // كلام جديد بيبدأ يتكتب من الأول
    if (old.lines.join('\n') != widget.lines.join('\n') && _fade.value > 0) {
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
    _fade.dispose();
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
      // آخر جملة في كلام مش بيلف: بيستنى لحظة وبيخلّص
      if (!widget.loop && _line == widget.lines.length - 1) {
        _timer = Timer(MahamihoBubble.holdFull, () {
          if (mounted) widget.onDone?.call();
        });
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
      child: FadeTransition(
        opacity: CurvedAnimation(parent: _fade, curve: Curves.easeOut),
        child: SpeechShape(
          maxWidth: widget.maxWidth,
          // مسافة مخفية بتحجز مكان الكلام عشان الفقاعة ما تكبرش وهي بتكتب
          child: Text(
            shown.isEmpty ? ' ' : shown,
            textAlign: TextAlign.center,
            maxLines: 3,
            style: speechStyle(11.5),
          ),
        ),
      ),
    );
  }
}

TextStyle speechStyle(double size, {Color color = Colors.white}) => TextStyle(
      fontFamily: 'AppFont',
      fontFamilyFallback: appFontFallback,
      fontSize: size,
      height: 1.45,
      fontWeight: FontWeight.w700,
      color: color,
    );

/// شكل الفقاعة (زرقا وحواليها إطار متقطع) حوالين أي محتوى. ده اللي بيستخدمه الشات كمان
class SpeechShape extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final double minWidth;

  const SpeechShape({super.key, required this.child, this.maxWidth = 170, this.minWidth = 112});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: minWidth, maxWidth: maxWidth),
      child: CustomPaint(
        painter: const _BubblePainter(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(11 + _BubblePainter.gap, 9 + _BubblePainter.gap, 11 + _BubblePainter.gap, 9 + _BubblePainter.gap),
          child: child,
        ),
      ),
    );
  }
}

/// كلام محاميحو كامل من غير كتابة حرف حرف، بنفس شكل الفقاعة (للشات)
class MahamihoSpeech extends StatelessWidget {
  final String text;
  final double maxWidth;
  final bool muted;

  const MahamihoSpeech({super.key, required this.text, required this.maxWidth, this.muted = false});

  @override
  Widget build(BuildContext context) {
    return SpeechShape(
      maxWidth: maxWidth,
      minWidth: 0,
      child: Text(text, style: speechStyle(13, color: muted ? const Color(0xB3FFFFFF) : Colors.white).copyWith(fontWeight: FontWeight.w600, height: 1.55)),
    );
  }
}

/// الفقاعة الزرقا بحواف 7، وحواليها إطار أزرق متقطع بينهم فراغ [gap]. من غير ظل ولا دبوس
class _BubblePainter extends CustomPainter {
  static const double radius = 7;
  static const double stroke = 1.4;

  /// الفراغ بين الفقاعة والإطار المتقطع اللي حواليها
  static const double gap = 4;

  const _BubblePainter();

  @override
  void paint(Canvas canvas, Size size) {
    const inset = stroke / 2;
    final body = Rect.fromLTRB(gap, gap, size.width - gap, size.height - gap);
    canvas.drawRRect(RRect.fromRectAndRadius(body, const Radius.circular(radius)), Paint()..color = AppColors.primary);

    final line = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final frame = Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTRB(inset, inset, size.width - inset, size.height - inset), const Radius.circular(radius + gap)));
    for (final PathMetric m in frame.computeMetrics()) {
      for (double at = 0; at < m.length; at += 8) {
        canvas.drawPath(m.extractPath(at, (at + 4.5).clamp(0, m.length)), line);
      }
    }
  }

  @override
  bool shouldRepaint(_BubblePainter oldDelegate) => false;
}


/// محاميحو بيظهر بتلاشي (fade) من غير قفز ولا حركة، مرة واحدة أول ما يظهر
class MahamihoFade extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const MahamihoFade({super.key, required this.child, this.delay = Duration.zero});

  @override
  State<MahamihoFade> createState() => _MahamihoFadeState();
}

class _MahamihoFadeState extends State<MahamihoFade> with SingleTickerProviderStateMixin {
  late final AnimationController _fade;
  Timer? _wait;

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
    if (widget.delay == Duration.zero) {
      _fade.forward();
    } else {
      _wait = Timer(widget.delay, () {
        if (mounted) _fade.forward();
      });
    }
  }

  @override
  void dispose() {
    _wait?.cancel();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(opacity: CurvedAnimation(parent: _fade, curve: Curves.easeOut), child: widget.child);
}
