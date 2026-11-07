import '../../core/widgets/app_loader.dart';
import '../../core/widgets/line_illustration.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/notification_center.dart';
import '../../core/services/live_updates.dart';
import '../../core/widgets/app_header.dart';
import '../../core/widgets/app_state_message.dart';
import '../../data/models/lifecycle_models.dart';
import 'notification_router.dart';

/// صفحة الإشعارات، والضغط على إشعار بيعلمه كمقروء
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isLoading = true;
  String? _error;
  List<AppNotification> _items = const [];

  @override
  void initState() {
    super.initState();
    _showSaved();
    _load();
    LiveUpdates.changes.addListener(_load);
  }

  @override
  void dispose() {
    LiveUpdates.changes.removeListener(_load);
    super.dispose();
  }

  Future<void> _showSaved() async {
    final saved = await NotificationCenter.saved();
    if (!mounted || saved.isEmpty || !_isLoading) return;
    setState(() {
      _items = saved;
      _isLoading = false;
    });
  }

  Future<void> _load() async {
    final res = await NotificationCenter.load();
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (res.isOk || _items.isEmpty) _items = res.data ?? _items;
      _error = res.isOk ? null : res.error;
    });
  }

  Future<void> _openItem(AppNotification item) async {
    if (!item.isRead) {
      setState(() {
        _items = _items
            .map((other) => other.id != item.id ? other : other.asRead()).toList();
      });
      NotificationCenter.markRead(item.id);
    }
    if (!item.opensPage) return;
    await NotificationRouter.open(context, item.target);
    // ممكن الطلب يكون اتقدم من الصفحة اللي اتفتحت
    if (mounted) _load();
  }

  Future<void> _markAllRead() async {
    await NotificationCenter.markAllRead();
    if (!mounted) return;
    setState(() {
      _items = _items
          .map((item) => item.asRead()).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppHeader(title: 'الإشعارات', isInnerPage: true, showNotifications: false),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: AppLoader());
    }

    if (_error != null) {
      return Center(
        child: AppStateMessage(
          icon: Icons.notifications_off_rounded,
          title: _error!,
          onRetry: _load,
        ),
      );
    }

    if (_items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LineIllustration(icon: Icons.notifications_none_rounded),
            SizedBox(height: 14),
            Text(
              'لا توجد إشعارات',
              style: TextStyle(
                fontFamily: 'AppFont',
                fontFamilyFallback: appFontFallback,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.dark,
              ),
            ),
          ],
        ),
      );
    }

    final hasUnread = _items.any((item) => !item.isRead);

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _items.length + (hasUnread ? 1 : 0),
        itemBuilder: (context, index) {
          if (hasUnread && index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: _markAllRead,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'تعليم الكل كمقروء',
                    style: TextStyle(
                      fontFamily: 'AppFont',
                      fontFamilyFallback: appFontFallback,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            );
          }
          final item = _items[hasUnread ? index - 1 : index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _openItem(item),
              child: _NotificationCard(item: item),
            ),
          );
        },
      ),
    );
  }
}

enum _NotificationKind { success, danger, info }

const _successTitles = {
  'المحامي وافق',
  'الموكل دفع',
  'المحامي وصل',
  'انتهت المهمة',
  'أتعابك جاهزة',
  'انتهى الإيقاف',
  'حسابك اتفعّل',
  'التجميد اتفك',
  'اتلغى إنذار',
  'تمت الموافقة على تقديمك',
  'اتضاف لرصيدك',
  'وصلك تحويل',
  'تم التحويل',
  'تقييم جديد',
};

const _dangerTitles = {
  'المحامي ما ردش',
  'المحامي اعتذر',
  'فاتك طلب',
  'اتحولت لغير متاح',
  'انتهت مهلة الدفع',
  'الموكل ما دفعش',
  'الطلب اتلغى',
  'مراجعة على طلب',
  'وصلك إنذار',
  'حسابك اتوقف',
  'حسابك اتوقف أسبوع',
  'أتعابك اتجمدت',
  'تقديمك اترفض',
  'اتخصم من رصيدك',
};

_NotificationKind _kindOf(String title) {
  if (_successTitles.contains(title)) return _NotificationKind.success;
  if (_dangerTitles.contains(title)) return _NotificationKind.danger;
  return _NotificationKind.info;
}

class _NotificationCard extends StatelessWidget {
  final AppNotification item;

  const _NotificationCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final kind = _kindOf(item.title);
    final color = switch (kind) {
      _NotificationKind.success => AppColors.success,
      _NotificationKind.danger => AppColors.danger,
      _NotificationKind.info => AppColors.primary,
    };
    final icon = switch (kind) {
      _NotificationKind.success => Icons.check_circle_outline_rounded,
      _NotificationKind.danger => Icons.error_outline_rounded,
      _NotificationKind.info => Icons.notifications_none_rounded,
    };

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(7.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 14, 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: color.withOpacity(0.16), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 23),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontFamily: 'AppFont',
                      fontFamilyFallback: appFontFallback,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.body,
                    style: const TextStyle(
                      fontFamily: 'AppFont',
                      fontFamilyFallback: appFontFallback,
                      fontSize: 12,
                      height: 1.4,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (!item.isRead) ...[
              const SizedBox(width: 10),
              Container(
                key: const ValueKey('unread-dot'),
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ],
            // The arrow shows the notification opens a page
            if (item.opensPage) ...[
              const SizedBox(width: 6),
              const Icon(Icons.keyboard_arrow_left_rounded, color: AppColors.textMuted, size: 20),
            ],
          ],
        ),
      ),
    );
  }
}
