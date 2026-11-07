import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'app_button.dart';

/// زرين أعلى صفحة الطلبات: الحالي واللحظي، أو السجل
class OrdersFilter extends StatelessWidget {
  final bool showCurrent;

  /// الطلبات الشغالة والجديدة والعروض المستنية، والرقم بيظهر لو فيه حاجة
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _button(currentCount > 0 ? 'الطلبات الحالية ($currentCount)' : 'الطلبات الحالية', showCurrent, true),
              const SizedBox(width: 8),
              _button('سجل الطلبات', !showCurrent, false),
            ],
          ),
          const SizedBox(height: 8),
          // الصفحة دي فيها كل الطلبات من كل الخدمات
          Text(
            showCurrent ? 'كل طلباتك المفتوحة من كل الخدمات' : 'كل طلباتك اللي خلصت أو اتلغت من كل الخدمات',
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
