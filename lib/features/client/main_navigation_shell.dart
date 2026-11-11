import 'package:flutter/material.dart';

import '../../core/services/background_alerts.dart';
import '../../core/services/notification_center.dart';
import '../../core/services/push_service.dart';
import '../../core/widgets/app_bottom_bar.dart';
import '../../core/widgets/app_header.dart';
import '../../core/widgets/order_action_sheets.dart';
import '../../data/models/order_model.dart';
import '../../data/repositories/order_repository.dart';
import '../notifications/notification_router.dart';
import '../notifications/notifications_screen.dart';
import 'account_tab.dart';
import 'home_tab.dart';
import 'mahamiho_guide.dart';
import 'orders_tab.dart';
import 'wallet_tab.dart';

class MainNavigationShell extends StatefulWidget {
  final int initialIndex;

  const MainNavigationShell({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  late int _currentIndex;

  static const List<String> _tabTitles = [
    'الرئيسية',
    'الطلبات',
    'المحفظة',
    'الحساب',
  ];

  // تُبنى صفحة التبويب عند أول زيارة فقط حتى لا يتأخر دخول التطبيق بأربع صفحات دفعة واحدة
  final Set<int> _visitedTabs = {};

  // يطلب من تبويبات البيانات إعادة التحميل عند العودة إليها
  final ValueNotifier<int> _dataRefresh = ValueNotifier<int>(0);

  static bool _reviewPromptShown = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _visitedTabs.add(_currentIndex);
    NotificationCenter.openRequest.addListener(_onOpenRequest);
    _onOpenRequest();
    NotificationCenter.start();
    PushService.start();
    _promptPendingReview();
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) BackgroundAlerts.askOnce(context); });
  }

  @override
  void dispose() {
    NotificationCenter.stop();
    NotificationCenter.openRequest.removeListener(_onOpenRequest);
    _dataRefresh.dispose();
    super.dispose();
  }

  /// يظهر طلب التقييم مرة واحدة في كل فتحة للتطبيق بعد إنهاء أي مهمة
  Future<void> _promptPendingReview() async {
    if (_reviewPromptShown) return;

    final res = await OrderRepository.getOrders(status: 'COMPLETED');
    if (!mounted || !res.isOk) return;

    final orders = (res.data ?? const <OrderModel>[]).where((order) => order.canReview);
    if (orders.isEmpty || _reviewPromptShown) return;

    _reviewPromptShown = true;
    final order = orders.first;
    await OrderActionSheets.review(
      context,
      lawyerName: order.lawyerName ?? 'المحامي',
      onSubmit: (rating, comment) => OrderRepository.submitReview(order.id, rating, comment),
    );
    _dataRefresh.value++;
  }

  /// لمس إشعار يفتح صفحته، والإشعار اللي مش مربوط بصفحة يفتح الطلبات.
  /// بيستنى لحد ما الصفحة تترسم، عشان الإشعار ممكن يوصل والتطبيق لسه بيفتح
  void _onOpenRequest() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final target = NotificationCenter.openRequest.value;
      if (target == null || !mounted) return;
      NotificationCenter.openRequest.value = null;
      Navigator.of(context).popUntil((route) => route.isFirst);
      NotificationCenter.markTargetRead(target);
      // الإشعار المش مربوط بحاجة بيفتح صفحة الإشعارات
      if (!await NotificationRouter.open(context, target) && mounted) {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
      }
    });
  }

  void _onTabSelected(int index) {
    if (index == _currentIndex) return;
    _dataRefresh.value++;
    setState(() {
      _currentIndex = index;
      _visitedTabs.add(index);
    });
  }

  Widget _buildTab(int index) {
    if (!_visitedTabs.contains(index)) return const SizedBox.shrink();
    switch (index) {
      case 0:
        return const HomeTab();
      case 1:
        return OrdersTab(refreshSignal: _dataRefresh);
      case 2:
        return WalletTab(refreshSignal: _dataRefresh);
      default:
        return const AccountTab();
    }
  }

  @override
  Widget build(BuildContext context) {
    // زر رجوع الهاتف يعود للرئيسية أولاً قبل الخروج من التطبيق
    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _onTabSelected(0);
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppHeader(
          title: _tabTitles[_currentIndex],
          isInnerPage: false,
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: IndexedStack(
                index: _currentIndex,
                children: List.generate(_tabTitles.length, _buildTab),
              ),
            ),
            // محاميحو في الرئيسية بس، لازق في الشريط السفلي. حركته بتقف في التبويبات التانية
            Positioned.fill(
              child: TickerMode(
                enabled: _currentIndex == 0,
                child: Offstage(offstage: _currentIndex != 0, child: const MahamihoGuide()),
              ),
            ),
          ],
        ),
        bottomNavigationBar: AppBottomBar(
          activeIndex: _currentIndex,
          onTabSelected: _onTabSelected,
          ordersBadge: NotificationCenter.pendingOrders,
        ),
      ),
    );
  }
}

