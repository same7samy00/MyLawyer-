import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/notification_center.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_header.dart';
import '../../core/widgets/app_state_message.dart';
import '../../data/models/lifecycle_models.dart';

/// صفحة الإشعارات، والتعليم كمقروء يتم بزر من المستخدم
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
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final res = await NotificationCenter.load();
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _items = res.data ?? const [];
      _error = res.isOk ? null : res.error;
    });
  }

  Future<void> _markAllRead() async {
    await NotificationCenter.markAllRead();
    if (!mounted) return;
    setState(() {
      _items = _items
          .map((item) => AppNotification(id: item.id, title: item.title, body: item.body, isRead: true))
          .toList();
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
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
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
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset('assets/images/notifications_empty.svg', height: 150, excludeFromSemantics: true),
            const SizedBox(height: 14),
            const Text(
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
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (hasUnread) ...[
            AppButton.outlined(
              text: 'تعليم الكل كمقروء',
              height: 40,
              fontSize: 12,
              onPressed: _markAllRead,
            ),
            const SizedBox(height: 12),
          ],
          for (final item in _items) ...[
            _NotificationCard(item: item),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

enum _NotificationKind { success, danger, info }

const _successTitles = {
  'المحامي وافق',
  'الموكل دفع',
  'المحامي وصل',
  'المهمة اتقفلت',
  'أتعابك جاهزة',
  'رجعت فلوسك',
  'انتهى الإيقاف',
};

const _dangerTitles = {
  'المحامي ما ردش',
  'المحامي اعتذر',
  'فاتك طلب',
  'اتحولت لغير متاح',
  'انتهت مهلة الدفع',
  'الموكل ما دفعش',
  'انتهت مهلة الطلب',
  'الطلب اتلغى',
  'شكوى على طلب',
  'إنذار',
  'تم إيقاف حسابك',
  'تم إيقاف حسابك مؤقتاً',
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
      child: Stack(
        children: [
          PositionedDirectional(
            start: 0,
            top: 0,
            bottom: 0,
            width: 12,
            child: CustomPaint(painter: _ScallopedEdgePainter(color.withOpacity(0.28))),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(24, 14, 14, 14),
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// الحافة المتموجة لبداية الكارت، على اليمين في الاتجاه العربي
class _ScallopedEdgePainter extends CustomPainter {
  final Color color;

  const _ScallopedEdgePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    const waveHeight = 12.0;
    final inner = size.width - 7;
    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(inner, 0);

    final count = (size.height / waveHeight).ceil();
    for (var i = 0; i < count; i++) {
      final top = i * waveHeight;
      path.quadraticBezierTo(0, top + waveHeight / 2, inner, top + waveHeight);
    }

    path
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ScallopedEdgePainter oldDelegate) => oldDelegate.color != color;
}
