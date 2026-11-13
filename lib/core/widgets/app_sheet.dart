import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../constants/app_colors.dart';
import 'app_card.dart';
import 'app_header.dart';
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

/// المحتوى الموحد للنوافذ: عنوان، ومحتوى، وأزرار.
/// [AppSheet.show] بيفتحه **صفحة كاملة** بالهيدر وزرار الرجوع والأزرار في آخر الصفحة (قرار صاحب المشروع 2026-11-13).
/// [AppSheet.showModal] بيفتحه نافذة سفلية، ودي لتأكيد تسجيل الخروج بس. شيتات الخريطة ثابتة ومش بتستخدم الاتنين
class AppSheet extends StatelessWidget {
  final String title;
  final List<Widget> children;

  /// الأزرار: في الصفحة بتتثبت في آخرها، وفي النافذة السفلية بتيجي بعد المحتوى
  final List<Widget> actions;

  /// رجوع لخطوة قبل كده جوه نفس الصفحة (بدل ما الصفحة تتقفل)
  final VoidCallback? onBack;
  final EdgeInsets padding;

  const AppSheet({
    super.key,
    required this.title,
    required this.children,
    this.actions = const [],
    this.onBack,
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 18),
  });

  /// بيفتح المحتوى صفحة منفصلة، وبيرجع القيمة اللي الصفحة اتقفلت بيها زي النافذة بالظبط
  static Future<T?> show<T>(BuildContext context, {required WidgetBuilder builder}) {
    return Navigator.of(context).push<T>(
      MaterialPageRoute<T>(builder: (context) => _AsPage(child: Builder(builder: builder))),
    );
  }

  /// نافذة سفلية، لتأكيد تسجيل الخروج بس
  static Future<T?> showModal<T>(BuildContext context, {required WidgetBuilder builder, bool isDismissible = true}) {
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
    if (context.dependOnInheritedWidgetOfExactType<_AsPage>() != null) return _page(context);
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
                    children: [
                      ...children,
                      if (actions.isNotEmpty) ...[const SizedBox(height: 14), ...actions],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// الصفحة: الهيدر بالعنوان وزرار الرجوع، والمحتوى بيتحرك، والأزرار ثابتة تحت
  Widget _page(BuildContext context) {
    final back = onBack;
    return PopScope(
      // في صفحة فيها خطوات، الرجوع بيرجع خطوة الأول
      canPop: back == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) back?.call();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppHeader(title: title, isInnerPage: true, onBack: back),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
                ),
              ),
              if (actions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: actions),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// علامة إن المحتوى مفتوح صفحة مش نافذة سفلية
class _AsPage extends InheritedWidget {
  const _AsPage({required super.child});

  @override
  bool updateShouldNotify(_AsPage oldWidget) => false;
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
