import 'package:flutter/material.dart';
import 'app_button.dart';

/// زرين أعلى صفحة الطلبات: الحالي واللحظي، أو السجل
class OrdersFilter extends StatelessWidget {
  final bool showCurrent;
  final ValueChanged<bool> onChanged;

  const OrdersFilter({super.key, required this.showCurrent, required this.onChanged});

  Widget _button(String text, bool isActive, bool value) {
    return Expanded(
      child: isActive
          ? AppButton.primary(text: text, height: 40, fontSize: 13, onPressed: () => onChanged(value))
          : AppButton.outlined(text: text, height: 40, fontSize: 13, onPressed: () => onChanged(value)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          _button('الطلبات الحالية', showCurrent, true),
          const SizedBox(width: 8),
          _button('سجل الطلبات', !showCurrent, false),
        ],
      ),
    );
  }
}
