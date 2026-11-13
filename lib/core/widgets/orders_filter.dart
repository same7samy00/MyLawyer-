import 'package:flutter/material.dart';
import 'app_button.dart';

/// زرين أعلى صفحة الطلبات: المفتوحة أو السجل، من غير شرح تحتهم
class OrdersFilter extends StatelessWidget {
  final bool showCurrent;

  /// الطلبات المفتوحة (الشغالة والجديدة والعروض المستنية)، والرقم بيظهر لو فيه حاجة
  final int currentCount;
  final ValueChanged<bool> onChanged;

  const OrdersFilter({super.key, required this.showCurrent, required this.onChanged, this.currentCount = 0});

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
          _button(currentCount > 0 ? 'الطلبات المفتوحة ($currentCount)' : 'الطلبات المفتوحة', showCurrent, true),
          const SizedBox(width: 8),
          _button('سجل الطلبات', !showCurrent, false),
        ],
      ),
    );
  }
}
