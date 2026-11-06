import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'app_pressable.dart';

/// إجراء الزر: الدالة العادية تُعامل كإجراء فوري، والدالة التي تعيد Future
/// يظهر معها التحميل داخل الزر ويبقى ممنوعاً من التكرار حتى تنتهي فعلياً
typedef AppButtonAction = FutureOr<void> Function();

/// زر موحد ومعتمد لكافة أزرار الإجراءات والانتقال في التطبيق
/// يلتزم بنظام التصميم الحصري (حواف 24.0px Pill Shape، خط Flat Jooza، ألوان المنصة)
/// ويتحول للرمادي عند الضغط، ويعرض التحميل فقط أثناء العمليات المنتظرة
class AppButton extends StatefulWidget {
  final String text;
  final AppButtonAction? onPressed;
  final bool isLoading;
  final IconData? icon;
  final Widget? customIcon;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? borderColor;
  final double height;
  final double? width;
  final bool isOutlined;
  final double fontSize;
  final FontWeight fontWeight;

  const AppButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.customIcon,
    this.backgroundColor,
    this.textColor,
    this.borderColor,
    this.height = 50.0,
    this.width,
    this.isOutlined = false,
    this.fontSize = 15.0,
    this.fontWeight = FontWeight.w800,
  });

  /// زر رئيسي بلون المنصة الأساسي (Primary Blue)
  const AppButton.primary({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.customIcon,
    this.height = 50.0,
    this.width,
    this.fontSize = 15.0,
    this.fontWeight = FontWeight.w800,
  })  : isOutlined = false,
        backgroundColor = AppColors.primary,
        textColor = Colors.white,
        borderColor = null;

  /// زر بإطار (Outlined Button) بحواف 24.0px
  const AppButton.outlined({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.customIcon,
    this.height = 48.0,
    this.width,
    this.fontSize = 13.0,
    this.fontWeight = FontWeight.w800,
    this.backgroundColor = Colors.white,
    this.textColor = AppColors.dark,
    this.borderColor = AppColors.cardBorder,
  }) : isOutlined = true;

  static const double buttonRadius = 24.0;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _isRunning = false;

  bool get _isLoading => widget.isLoading || _isRunning;

  Future<void> _handlePressed() async {
    if (_isLoading) return;

    final pending = widget.onPressed?.call();
    if (pending is! Future) return;

    setState(() => _isRunning = true);
    try {
      await pending;
    } finally {
      if (mounted) {
        setState(() => _isRunning = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOutlined = widget.isOutlined;
    // أزرار الإلغاء والإغلاق في التطبيق كله حمرا (قرار صاحب المشروع 2026-11-06)
    final text = widget.text.trim();
    final isCancel = text.startsWith('إلغاء') || text == 'إغلاق';
    final effectiveBgColor = widget.backgroundColor ?? (isOutlined ? Colors.white : (isCancel ? AppColors.danger : AppColors.primary));
    final effectiveTextColor = widget.textColor ?? (isOutlined ? (isCancel ? AppColors.danger : AppColors.dark) : Colors.white);
    final isForwardArrow = widget.customIcon == null && widget.icon == Icons.arrow_forward_rounded;
    final effectiveBorderColor = widget.borderColor ?? (isCancel ? AppColors.danger.withOpacity(0.35) : AppColors.cardBorder);

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppButton.buttonRadius), // حواف مستديرة واضحة (Pill Shape) 24.0px
      side: isOutlined ? BorderSide(color: effectiveBorderColor, width: 1.2) : BorderSide.none,
    );

    // يحتفظ الزر بمساحة محتواه كاملة أثناء التحميل فلا يقفز عرضه أو ارتفاعه
    final childContent = Stack(
      alignment: Alignment.center,
      children: [
        Visibility(
          visible: !_isLoading,
          maintainSize: true,
          maintainAnimation: true,
          maintainState: true,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (widget.customIcon != null) ...[
                widget.customIcon!,
                const SizedBox(width: 8),
              ] else if (widget.icon != null && !isForwardArrow) ...[
                Icon(widget.icon, color: effectiveTextColor, size: 18),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  widget.text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'AppFont',
                    fontFamilyFallback: appFontFallback,
                    fontSize: widget.fontSize,
                    fontWeight: widget.fontWeight,
                    color: effectiveTextColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // سهم المتابعة يأتي بعد النص ليشير إلى اتجاه القراءة
              if (isForwardArrow) ...[
                const SizedBox(width: 8),
                Icon(widget.icon, color: effectiveTextColor, size: 18),
              ],
            ],
          ),
        ),
        if (_isLoading)
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(
                isOutlined ? AppColors.primary : Colors.white,
              ),
            ),
          ),
      ],
    );

    final buttonStyle = ElevatedButton.styleFrom(
      backgroundColor: effectiveBgColor,
      foregroundColor: effectiveTextColor,
      disabledBackgroundColor: _isLoading ? effectiveBgColor : effectiveBgColor.withOpacity(0.65),
      disabledForegroundColor: effectiveTextColor.withOpacity(0.65),
      overlayColor: Colors.transparent,
      elevation: 0,
      shape: shape,
      minimumSize: Size(widget.width ?? double.infinity, widget.height),
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
    );

    final bool isActionable = !_isLoading && widget.onPressed != null;

    return AppPressable(
      enabled: isActionable,
      forcePressed: _isLoading,
      child: ElevatedButton(
        onPressed: isActionable ? _handlePressed : null,
        style: buttonStyle,
        child: childContent,
      ),
    );
  }
}
