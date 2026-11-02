import 'app_pressable.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/notification_center.dart';
import '../../features/notifications/notifications_screen.dart';

/// الهيدر العلوي العام والموحد لجميع شاشات التطبيق (باستثناء تسجيل الدخول)
/// - ثابت في أعلى الشاشة ولا يتحرك مع التمرير
/// - عنوان الصفحة الحالية يظهر في المنتصف تماماً
/// - في اليمين (RTL): أيقونة البحث للصفحات الرئيسية أو زر الرجوع الفعلي للصفحات الداخلية
/// - في اليسار (RTL): أيقونة الإشعارات
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool isInnerPage;
  final VoidCallback? onBack;
  final VoidCallback? onSearch;
  final VoidCallback? onNotifications;
  final bool showNotifications;

  const AppHeader({
    super.key,
    required this.title,
    this.isInnerPage = false,
    this.onBack,
    this.onSearch,
    this.onNotifications,
    this.showNotifications = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56.0);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          bottom: BorderSide(color: AppColors.cardBorder, width: 1.0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56.0,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. يمين الهيدر في RTL: زر البحث (للرئيسية) أو زر الرجوع الفعلي (للصفحات الداخلية)
                // الشاشة الأولى في المكدس لا يوجد خلفها ما يُرجع إليه، فلا يظهر زر بلا فعل
                if (isInnerPage && onBack == null && !(ModalRoute.of(context)?.canPop ?? false))
                  const SizedBox(width: 40, height: 40)
                else
                _buildActionBtn(
                  context: context,
                  isPrimary: !isInnerPage,
                  icon: isInnerPage ? Icons.arrow_back_rounded : Icons.search_rounded,
                  tooltip: isInnerPage ? 'رجوع' : 'بحث',
                  onPressed: () {
                    if (isInnerPage) {
                      if (onBack != null) {
                        onBack!();
                      } else {
                        Navigator.of(context).maybePop();
                      }
                    } else {
                      if (onSearch != null) {
                        onSearch!();
                      } else {
                        _showQuickSearchDialog(context);
                      }
                    }
                  },
                ),

                // 2. منتصف الهيدر تماماً: اسم الصفحة الحالية
                Expanded(
                  child: Center(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'AppFont',
                        fontFamilyFallback: appFontFallback,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: AppColors.dark,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

                // 3. يسار الهيدر في RTL: أيقونة الإشعارات الثابتة
                if (!showNotifications)
                  const SizedBox(width: 40, height: 40)
                else
                _buildActionBtn(
                  context: context,
                  isPrimary: false,
                  icon: Icons.notifications_none_rounded,
                  tooltip: 'الإشعارات',
                  onPressed: () {
                    if (onNotifications != null) {
                      onNotifications!();
                    } else {
                      _openNotifications(context);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionBtn({
    required BuildContext context,
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    bool isPrimary = false,
  }) {
    return AppPressable(
      child: IconButton(
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        icon: ValueListenableBuilder<int>(
          valueListenable: NotificationCenter.unread,
          child: Icon(
            icon,
            size: 23,
            color: isPrimary ? AppColors.primary : AppColors.dark,
          ),
          builder: (context, unread, iconWidget) => Stack(
            clipBehavior: Clip.none,
            children: [
              iconWidget!,
              if (unread > 0 && icon == Icons.notifications_none_rounded)
                Positioned(
                  top: 0,
                  left: 0,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                  ),
                ),
            ],
          ),
        ),
        onPressed: onPressed,
      ),
    );
  }

  void _showQuickSearchDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.cardBorder,
                      borderRadius: BorderRadius.circular(4.0),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'البحث السريع في My Lawyer',
                  style: TextStyle(
                    fontFamily: 'AppFont',
                    fontFamilyFallback: appFontFallback,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.dark,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  autofocus: true,
                  style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'ابحث عن خدمة قانونية، نوع استشارة، أو محامٍ',
                    hintStyle: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 13, color: AppColors.textMuted),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary, size: 20),
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(7.0),
                      borderSide: const BorderSide(color: AppColors.cardBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(7.0),
                      borderSide: const BorderSide(color: AppColors.cardBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(7.0),
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openNotifications(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (context) => const NotificationsScreen()),
    );
  }
}
