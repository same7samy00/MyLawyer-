import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'app_button.dart';

/// زرار في النوافذ السفلية. الأزرار القصيرة بتتحط اتنين جنب بعض، واللي نصها طويل بياخد السطر لوحده
class SheetButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isPrimary;
  final bool isDanger;
  /// زرار الاتصال أخضر
  final bool isSuccess;

  const SheetButton(this.text, this.onPressed, {super.key, this.icon, this.isPrimary = false, this.isDanger = false, this.isSuccess = false});

  /// أطول من كده مش هيبان كويس في نص السطر
  static const int _shortLength = 16;

  bool get isShort => text.length <= _shortLength;

  @override
  Widget build(BuildContext context) {
    if (isSuccess) {
      return AppButton(text: text, icon: icon, height: 46, fontSize: 14, backgroundColor: AppColors.success, onPressed: onPressed);
    }
    if (isPrimary) {
      return AppButton.primary(text: text, icon: icon, height: 46, fontSize: 14, onPressed: onPressed);
    }
    // أزرار الإلغاء AppButton بيلونها لوحده بخلفية حمرا، فما نديهاش لون نص
    final label = text.trim();
    final isCancel = label.startsWith('إلغاء') || label == 'إغلاق';
    return AppButton.outlined(
      text: text,
      icon: icon,
      height: 46,
      fontSize: 13,
      textColor: isDanger && !isCancel ? AppColors.danger : null,
      borderColor: isDanger && !isCancel ? AppColors.danger.withOpacity(0.35) : null,
      onPressed: onPressed,
    );
  }
}

/// بيرص الأزرار: كل اتنين قصيرين ورا بعض في سطر واحد، والطويل لوحده، وأي حاجة تانية (زي الملاحظات) زي ما هي
List<Widget> packSheetActions(List<Widget> items) {
  final packed = <Widget>[];
  for (var i = 0; i < items.length; i++) {
    final item = items[i];
    final next = i + 1 < items.length ? items[i + 1] : null;
    if (item is SheetButton && item.isShort && next is SheetButton && next.isShort) {
      packed.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Expanded(child: item),
            const SizedBox(width: 10),
            Expanded(child: next),
          ],
        ),
      ),);
      i++;
    } else if (item is SheetButton) {
      packed.add(Padding(padding: const EdgeInsets.only(bottom: 8), child: item));
    } else {
      packed.add(item);
    }
  }
  return packed;
}
