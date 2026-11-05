import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/services/app_visibility.dart';
import '../../core/services/live_updates.dart';
import '../../core/widgets/app_state_message.dart';
import '../../core/widgets/order_summary_card.dart';
import '../../core/widgets/orders_filter.dart';
import '../../data/models/order_model.dart';
import '../../data/repositories/order_repository.dart';
import '../urgent_service/order_details_sheet.dart';

class OrdersTab extends StatefulWidget {
  /// إشارة من الحاوية لتحديث القائمة عند العودة لهذا التبويب
  final ValueListenable<int>? refreshSignal;

  const OrdersTab({super.key, this.refreshSignal});

  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab> {
  bool _isLoading = true;
  bool _isFetching = false;
  String? _errorMessage;
  List<OrderModel> _orders = const [];
  Timer? _refreshTimer;
  bool _showCurrent = true;

  @override
  void initState() {
    super.initState();
    widget.refreshSignal?.addListener(_loadOrders);
    LiveUpdates.changes.addListener(_loadOrders);
    ApiService.isServerReachable.addListener(_onReachabilityChanged);
    _loadOrders();
    // تحديث حالة الطلب الجاري من غير سحب الصفحة
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (isAppVisible && _orders.any((order) => order.isOngoing)) _loadOrders();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    widget.refreshSignal?.removeListener(_loadOrders);
    LiveUpdates.changes.removeListener(_loadOrders);
    ApiService.isServerReachable.removeListener(_onReachabilityChanged);
    super.dispose();
  }

  void _onReachabilityChanged() {
    if (ApiService.isServerReachable.value && _errorMessage != null) {
      _loadOrders();
    }
  }

  Future<void> _loadOrders() async {
    if (_isFetching) return;
    _isFetching = true;

    final res = await OrderRepository.getOrders();
    _isFetching = false;
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (res.isOk) {
        _orders = res.data ?? const [];
        _errorMessage = null;
      } else if (_orders.isEmpty) {
        _errorMessage = res.error ?? 'تعذر تحميل طلباتك، يرجى المحاولة مرة أخرى.';
      }
    });
  }

  Future<void> _openDetails(OrderModel order) async {
    await OrderDetailsSheet.open(context, order);
    if (mounted) await _loadOrders();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_errorMessage != null) {
      return SafeArea(
        child: ListView(
          children: [
            AppStateMessage(
              icon: Icons.wifi_off_rounded,
              title: 'تعذر تحميل طلباتك',
              message: _errorMessage,
              onRetry: _loadOrders,
            ),
          ],
        ),
      );
    }

    final orders = _orders.where((order) => order.isOngoing == _showCurrent).toList();

    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _loadOrders,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 16.0),
          itemCount: 1 + (orders.isEmpty ? 1 : orders.length),
          itemBuilder: (context, position) {
            if (position == 0) {
              return OrdersFilter(currentCount: _orders.where((order) => order.isOngoing).length, showCurrent: _showCurrent, onChanged: (value) => setState(() => _showCurrent = value));
            }
            final index = position - 1;
            if (orders.isEmpty) {
              return const AppStateMessage(
                icon: Icons.receipt_long_rounded,
                title: 'لا توجد طلبات حتى الآن',
                message: 'هتظهر طلباتك هنا فور إرسالها لأحد المحامين.',
              );
            }
            final order = orders[index];
            return Padding(
              key: ValueKey(order.id),
              padding: const EdgeInsets.only(bottom: 12),
              child: OrderSummaryCard(
                order: order,
                onOpen: () { _openDetails(order); },
              ),
            );
          },
        ),
      ),
    );
  }
}
