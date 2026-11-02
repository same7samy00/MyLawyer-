import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// يبلغ بحجم محتواه بعد الرسم، عشان البوتن شيت ياخد طول المحتوى بالظبط على أي موبايل
class MeasuredSize extends SingleChildRenderObjectWidget {
  final ValueChanged<Size> onChange;

  const MeasuredSize({super.key, required this.onChange, required Widget super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => RenderMeasuredSize(onChange);

  @override
  void updateRenderObject(BuildContext context, RenderMeasuredSize renderObject) {
    renderObject.onChange = onChange;
  }
}

class RenderMeasuredSize extends RenderProxyBox {
  ValueChanged<Size> onChange;
  Size? _lastSize;

  RenderMeasuredSize(this.onChange);

  @override
  void performLayout() {
    super.performLayout();
    if (size == _lastSize) return;
    _lastSize = size;
    final measured = size;
    WidgetsBinding.instance.addPostFrameCallback((_) => onChange(measured));
  }
}
