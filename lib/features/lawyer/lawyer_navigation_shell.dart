import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/services/location_service.dart';
import '../../core/services/notification_center.dart';
import '../../core/services/push_service.dart';
import '../../core/widgets/app_bottom_bar.dart';
import '../../core/widgets/app_header.dart';
import '../../data/repositories/lawyer_repository.dart';
import 'lawyer_account_tab.dart';
import 'lawyer_home_tab.dart';
import 'lawyer_orders_tab.dart';
import 'lawyer_wallet_tab.dart';

/// الحاوية الرئيسية المستقلة لتبويبات المحامي
class LawyerNavigationShell extends StatefulWidget {
  final int initialIndex;

  const LawyerNavigationShell({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<LawyerNavigationShell> createState() => _LawyerNavigationShellState();
}

class _LawyerNavigationShellState extends State<LawyerNavigationShell> with WidgetsBindingObserver {
  late int _currentIndex;
  Timer? _presenceTimer;

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

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _visitedTabs.add(_currentIndex);
    NotificationCenter.start(interval: const Duration(seconds: 5));
    NotificationCenter.pendingOrders.addListener(_onPendingOrdersChanged);
    WidgetsBinding.instance.addObserver(this);
    _syncLocation();
    PushService.start();
    // إشارة الحضور تبقي المحامي ظاهراً للموكلين بمكانه الحالي
    _presenceTimer = Timer.periodic(const Duration(minutes: 1), (_) => _syncLocation());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _syncLocation();
  }

  @override
  void dispose() {
    _presenceTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    NotificationCenter.pendingOrders.removeListener(_onPendingOrdersChanged);
    NotificationCenter.stop();
    _dataRefresh.dispose();
    super.dispose();
  }

  /// موقع المحامي يحدد ظهوره للموكلين القريبين
  Future<void> _syncLocation() async {
    try {
      final result = await LocationService.instance.checkAndRequestPermission();
      final position = result.position;
      if (position == null) return;
      await LawyerRepository.updateLawyerLocation(lat: position.latitude, lon: position.longitude);
    } catch (_) {
      // تعذر الموقع لا يوقف باقي التطبيق
    }
  }

  void _onPendingOrdersChanged() {
    _dataRefresh.value++;
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
        return const LawyerHomeTab();
      case 1:
        return LawyerOrdersTab(refreshSignal: _dataRefresh);
      case 2:
        return LawyerWalletTab(refreshSignal: _dataRefresh);
      default:
        return const LawyerAccountTab();
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
        body: IndexedStack(
          index: _currentIndex,
          children: List.generate(_tabTitles.length, _buildTab),
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

