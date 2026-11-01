import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

enum StatusBadgeType {
  success,
  warning,
  danger,
  primary,
  neutral,
}

class StatusBadge extends StatelessWidget {
  final String text;
  final StatusBadgeType type;
  final IconData? icon;
  final Widget? trailing;
  final bool showDot;

  const StatusBadge({
    super.key,
    required this.text,
    this.type = StatusBadgeType.success,
    this.icon,
    this.trailing,
    this.showDot = true,
  });

  Color get _textColor {
    switch (type) {
      case StatusBadgeType.success:
        return AppColors.success;
      case StatusBadgeType.warning:
        return AppColors.warning;
      case StatusBadgeType.danger:
        return AppColors.danger;
      case StatusBadgeType.primary:
        return AppColors.primary;
      case StatusBadgeType.neutral:
        return AppColors.darkSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showDot) ...[
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: _textColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
        ] else if (icon != null) ...[
          Icon(icon, size: 14, color: _textColor),
          const SizedBox(width: 5),
        ],
        Text(
          text,
          style: TextStyle(
            fontFamily: 'AppFont',
            fontFamilyFallback: appFontFallback,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: _textColor,
            letterSpacing: 0.4,
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 6),
          trailing!,
        ],
      ],
    );
  }
}

