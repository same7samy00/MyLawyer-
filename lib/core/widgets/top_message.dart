import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// الرسايل القصيرة («مفيش محامي قريب منك دلوقتي» مثلًا) بنفس شكلها، بس فوق تحت الهيدر والنص في النص،
/// فما بتغطيش أي زرار تحت. رسالة واحدة في نفس الوقت، والجديدة بتحل محل القديمة
OverlayEntry? _current;

void showTopMessage(BuildContext context, SnackBar bar) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  _current?.remove();
  _current = null;

  final theme = Theme.of(context);
  final background = bar.backgroundColor ?? theme.snackBarTheme.backgroundColor ?? const Color(0xFF323232);
  final top = MediaQuery.paddingOf(context).top + kToolbarHeight + 8;

  late final OverlayEntry entry;
  void close() {
    if (identical(_current, entry)) _current = null;
    if (entry.mounted) entry.remove();
  }

  entry = OverlayEntry(
    builder: (context) => Positioned(
      top: top,
      left: 16,
      right: 16,
      child: _TopMessage(bar: bar, background: background, onDone: close),
    ),
  );
  _current = entry;
  overlay.insert(entry);
}

/// بيختفي لوحده بعد مدة الرسالة. المدة بتتعد بالإطارات مش بمؤقت، فبتقف مع الشاشة
class _TopMessage extends StatefulWidget {
  final SnackBar bar;
  final Color background;
  final VoidCallback onDone;

  const _TopMessage({required this.bar, required this.background, required this.onDone});

  @override
  State<_TopMessage> createState() => _TopMessageState();
}

class _TopMessageState extends State<_TopMessage> with SingleTickerProviderStateMixin {
  late final AnimationController _life;

  @override
  void initState() {
    super.initState();
    _life = AnimationController(vsync: this, duration: widget.bar.duration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onDone();
      })
      ..forward();
  }

  @override
  void dispose() {
    _life.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final action = widget.bar.action;
    return Material(
      color: widget.background,
      elevation: 6,
      borderRadius: BorderRadius.circular(AppTheme.borderRadiusValue),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: DefaultTextStyle.merge(
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(child: widget.bar.content),
              if (action != null)
                TextButton(
                  onPressed: () {
                    action.onPressed();
                    widget.onDone();
                  },
                  child: Text(action.label, style: TextStyle(color: action.textColor ?? Colors.white, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
