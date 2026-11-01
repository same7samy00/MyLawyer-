import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/auth_service.dart';

/// مكون مؤشر قوة كلمة المرور المبسط (شريط القوة فقط بدون أي شارات أو قوائم شروط)
/// متوافق مع نظام التصميم الصارم بحواف 7.0px وخط الثمانية
class PasswordStrengthWidget extends StatelessWidget {
  final PasswordStrength strength;

  const PasswordStrengthWidget({
    super.key,
    required this.strength,
  });

  Color _getStrengthColor() {
    if (strength.score >= 0.8) return AppColors.success;
    if (strength.score >= 0.5) return Colors.amber.shade700;
    return AppColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    final color = _getStrengthColor();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // شريط قوة كلمة المرور فقط دون أي شارات أسفله أو بجانبه
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7.0),
                child: LinearProgressIndicator(
                  value: strength.score,
                  minHeight: 6,
                  backgroundColor: AppColors.cardBorder,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              strength.label,
              style: TextStyle(
                fontFamily: 'AppFont',
                fontFamilyFallback: appFontFallback,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
