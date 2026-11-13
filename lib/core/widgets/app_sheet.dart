import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../constants/app_colors.dart';
import 'app_card.dart';
import 'app_skeleton.dart';

/// رأس موحد لكل البوتن شيت: خط السحب في النص، وتحته العنوان، وتحته خط فاصل متقطع.
/// الشيت اللي فوق الخريطة ثابت وما بيتقفلش، فمالوش خط سحب ([showHandle] = false)
/// أي شيت تاني بيتقفل بالضغط بره أو السحب لتحت
class AppSheetHeader extends StatelessWidget {
  final String title;

  /// زر رجوع جنب العنوان، لما الشيت فيه أكتر من خطوة
  final VoidCallback? onBack;

  /// خط السحب فوق العنوان، للشيت اللي بيتقفل بالسحب بس
  final bool showHandle;

  const AppSheetHeader({super.key, required this.title, this.onBack, this.showHandle = true});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHandle) ...[
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(color: AppColors.cardBorder, borderRadius: BorderRadius.circular(4.0)),
            ),
          ),
        ] else
          const SizedBox(height: 8),
        SizedBox(
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'AppFont',
                    fontFamilyFallback: appFontFallback,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.dark,
                  ),
                ),
              ),
              if (onBack != null)
                PositionedDirectional(
                  start: 6,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: AppColors.dark),
                    tooltip: 'رجوع',
                    onPressed: onBack,
                  ),
                ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: DashedDivider(),
        ),
      ],
    );
  }
}

/// البوتن شيت الموحد: طوله على قد محتواه على أي موبايل.
/// لو المحتوى أطول من الشاشة أو الكيبورد فتح، الجزء الزيادة بس هو اللي يتحرك جواه
class AppSheet extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final VoidCallback? onBack;
  final EdgeInsets padding;

  const AppSheet({
    super.key,
    required this.title,
    required this.children,
    this.onBack,
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 18),
  });

  static Future<T?> show<T>(BuildContext context, {required WidgetBuilder builder, bool isDismissible = true}) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      isDismissible: isDismissible,
      enableDrag: isDismissible,
      backgroundColor: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(7.0))),
      builder: builder,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context).height;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: screen * 0.9),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppSheetHeader(title: title, onBack: onBack),
              Flexible(
                child: SingleChildScrollView(
                  padding: padding,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// بيبلغ بطول المحتوى كل ما يتغير، عشان الشيت اللي فوق الخريطة يتظبط عليه
class MeasuredSize extends SingleChildRenderObjectWidget {
  final ValueChanged<Size> onChange;

  const MeasuredSize({super.key, required this.onChange, required Widget super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => MeasuredSizeBox(onChange);

  @override
  void updateRenderObject(BuildContext context, MeasuredSizeBox renderObject) => renderObject.onChange = onChange;
}

class MeasuredSizeBox extends RenderProxyBox {
  ValueChanged<Size> onChange;
  Size? _last;

  MeasuredSizeBox(this.onChange);

  @override
  void performLayout() {
    super.performLayout();
    if (_last == size) return;
    _last = size;
    final reported = size;
    WidgetsBinding.instance.addPostFrameCallback((_) => onChange(reported));
  }
}

/// تحميل موحد جوه أي شيت، بدل طبقة فوق الخريطة: كروت Skeleton بشكل كروت المحامين.
/// [text] بيتقرا لقارئ الشاشة بس
class SheetLoading extends StatelessWidget {
  final String text;

  const SheetLoading({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: text,
      // الشيت ممكن يبقى أقصر من التلات كروت، فاللي زيادة بيتقص بدل ما يطلع بره
      child: const SingleChildScrollView(
        physics: NeverScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(vertical: 12),
        child: AppSkeleton(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SkeletonRow(circle: true),
              SizedBox(height: 10),
              SkeletonRow(circle: true),
              SizedBox(height: 10),
              SkeletonRow(circle: true),
            ],
          ),
        ),
      ),
    );
  }
}
