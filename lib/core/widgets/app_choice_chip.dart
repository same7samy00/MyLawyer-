import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// اختيار من قايمة اختيارات: المختار أزرق ونصه أبيض، من غير علامة صح
class AppChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  const AppChoiceChip({super.key, required this.label, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      showCheckmark: false,
      selectedColor: AppColors.primary,
      backgroundColor: Colors.white,
      side: BorderSide(color: selected ? AppColors.primary : AppColors.cardBorder),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7.0)),
      labelStyle: TextStyle(
        fontFamily: 'AppFont',
        fontFamilyFallback: appFontFallback,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: selected ? Colors.white : AppColors.textMain,
      ),
    );
  }
}
