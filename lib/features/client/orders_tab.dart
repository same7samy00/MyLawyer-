import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/widgets/app_state_message.dart';
import '../../core/widgets/order_summary_card.dart';
import '../../data/models/order_model.dart';
import '../../data/repositories/order_repository.dart';
import '../urgent_service/order_details_screen.dart';

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

  @override
  void initState() {
    super.initState();
    widget.refreshSignal?.addListener(_loadOrders);
    ApiService.isServerReachable.addListener(_onReachabilityChanged);
    _loadOrders();
    // تحديث حالة الطلب الجاري من غير سحب الصفحة
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (_orders.any((order) => order.isOngoing)) _loadOrders();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    widget.refreshSignal?.removeListener(_loadOrders);
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
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => OrderDetailsScreen(order: order)),
    );
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

    final activeOrders = _orders.where((order) => order.isOngoing).toList();
    final pastOrders = _orders.where((order) => !order.isOngoing).toList();

    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _loadOrders,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 16.0),
          children: [
            if (_orders.isEmpty)
              const AppStateMessage(
                icon: Icons.receipt_long_rounded,
                title: 'لا توجد طلبات حتى الآن',
                message: 'هتظهر طلباتك هنا فور إرسالها لأحد المحامين.',
              ),
            for (final order in [...activeOrders, ...pastOrders]) ...[
              OrderSummaryCard(
                key: ValueKey(order.id),
                order: order,
                onOpen: () => _openDetails(order),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}
