import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// استجابة الضغط الموحدة لكل ما يُضغط عليه في التطبيق:
/// يتحول العنصر إلى الرمادي فور ملامسة الإصبع ويعود لطبيعته عند الرفع،
/// بلا Hover وبلا حركات وبلا أي تغيير في الأبعاد أو الحواف أو الخطوط.
/// لا ينفذ أي إجراء بنفسه، فالضغطة تصل للزر الداخلي كالمعتاد.
class AppPressable extends StatefulWidget {
  final Widget child;
  final bool enabled;

  /// إبقاء اللون الرمادي أثناء انتظار عملية جارية داخل الزر
  final bool forcePressed;

  const AppPressable({
    super.key,
    required this.child,
    this.enabled = true,
    this.forcePressed = false,
  });

  /// أقل زمن ظهور للرمادي حتى تظل الضغطة السريعة جداً مرئية
  static const Duration minimumPressedDuration = Duration(milliseconds: 90);

  @override
  State<AppPressable> createState() => _AppPressableState();
}

class _AppPressableState extends State<AppPressable> {
  bool _isPressed = false;
  Offset? _downPosition;
  DateTime? _downTime;
  Timer? _releaseTimer;

  bool get _isInteractive {
    if (!widget.enabled) return false;
    final child = widget.child;
    if (child is ButtonStyleButton) return child.enabled;
    if (child is IconButton) return child.onPressed != null;
    return true;
  }

  void _setPressed(bool value) {
    if (_isPressed == value || !mounted) return;
    setState(() => _isPressed = value);
  }

  void _onPointerDown(PointerDownEvent event) {
    if (!_isInteractive) return;
    _releaseTimer?.cancel();
    _downPosition = event.position;
    _downTime = DateTime.now();
    _setPressed(true);
  }

  // تحريك الإصبع يعني تمرير الشاشة لا ضغط الزر
  void _onPointerMove(PointerMoveEvent event) {
    final start = _downPosition;
    if (start == null) return;
    if ((event.position - start).distance > kTouchSlop) {
      _downPosition = null;
      _setPressed(false);
    }
  }

  void _onPointerEnd(PointerEvent event) {
    _downPosition = null;
    if (!_isPressed) return;

    final elapsed = DateTime.now().difference(_downTime ?? DateTime.now());
    final remaining = AppPressable.minimumPressedDuration - elapsed;
    if (remaining <= Duration.zero) {
      _setPressed(false);
    } else {
      _releaseTimer = Timer(remaining, () => _setPressed(false));
    }
  }

  @override
  void dispose() {
    _releaseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerEnd,
      onPointerCancel: _onPointerEnd,
      child: PressTint(
        active: widget.forcePressed || (_isPressed && _isInteractive),
        child: widget.child,
      ),
    );
  }
}

/// مرشح لوني يحول العنصر إلى درجات الرمادي دون المساس بتخطيطه أو حالته
/// يبقى في شجرة الواجهة دائماً ولا يكلف أي طبقة رسم إلا أثناء الضغط
class PressTint extends SingleChildRenderObjectWidget {
  final bool active;

  const PressTint({
    super.key,
    required this.active,
    required Widget super.child,
  });

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderPressTint(active);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderPressTint).active = active;
  }
}

class _RenderPressTint extends RenderProxyBox {
  _RenderPressTint(this._active);

  // إضاءة العنصر تُضغط إلى نطاق هادئ يبقي الخلفية رمادية والنص مقروءاً
  static const ColorFilter _grayFilter = ColorFilter.matrix(<double>[
    0.12756, 0.42912, 0.04332, 0, 76.5,
    0.12756, 0.42912, 0.04332, 0, 76.5,
    0.12756, 0.42912, 0.04332, 0, 76.5,
    0, 0, 0, 1, 0,
  ]);

  bool _active;

  set active(bool value) {
    if (_active == value) return;
    _active = value;
    markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => _active;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!_active) {
      layer = null;
      super.paint(context, offset);
      return;
    }
    layer = context.pushColorFilter(
      offset,
      _grayFilter,
      super.paint,
      oldLayer: layer is ColorFilterLayer ? layer as ColorFilterLayer : null,
    );
  }
}
