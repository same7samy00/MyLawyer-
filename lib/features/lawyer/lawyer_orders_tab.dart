import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/services/app_visibility.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_state_message.dart';
import '../../core/widgets/order_summary_card.dart';
import '../../data/models/order_model.dart';
import '../../data/models/service_request.dart';
import '../../data/repositories/order_repository.dart';
import '../../data/repositories/request_repository.dart';
import 'request_offer_screen.dart';
import '../urgent_service/order_details_screen.dart';

/// صفحة طلبات المحامي المستقلة
/// مطابقة لصفحة طلبات الموكل، والإجراءات كلها في صفحة تفاصيل الطلب
class LawyerOrdersTab extends StatefulWidget {
  /// إشارة من الحاوية لتحديث القائمة عند العودة لهذا التبويب
  final ValueListenable<int>? refreshSignal;

  const LawyerOrdersTab({super.key, this.refreshSignal});

  @override
  State<LawyerOrdersTab> createState() => _LawyerOrdersTabState();
}

class _LawyerOrdersTabState extends State<LawyerOrdersTab> {
  bool _isLoading = true;
  bool _isFetching = false;
  String? _errorMessage;
  List<OrderModel> _orders = const [];
  List<IncomingRequest> _requests = const [];
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    widget.refreshSignal?.addListener(_loadOrders);
    ApiService.isServerReachable.addListener(_onReachabilityChanged);
    _loadOrders();
    // الطلب الجديد وانتهاء مهلته يظهران من غير سحب الصفحة
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (isAppVisible) _loadOrders();
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

    final results = await Future.wait([OrderRepository.getOrders(), RequestRepository.incoming()]);
    final res = results[0] as ApiResponse<List<OrderModel>>;
    final requests = results[1] as ApiResponse<List<IncomingRequest>>;
    _isFetching = false;
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (requests.isOk) _requests = requests.data ?? const [];
      if (res.isOk) {
        _orders = res.data ?? const [];
        _errorMessage = null;
      } else if (_orders.isEmpty) {
        _errorMessage = res.error ?? 'تعذر تحميل الطلبات، يرجى المحاولة مرة أخرى.';
      }
    });
  }

  Future<void> _openDetails(OrderModel order) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => OrderDetailsScreen(order: order, isLawyer: true)),
    );
    if (mounted) await _loadOrders();
  }

  Future<void> _openRequest(IncomingRequest request) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => RequestOfferScreen(request: request)),
    );
    if (mounted) await _loadOrders();
  }

  Widget _requestCard(IncomingRequest request) {
    final sent = request.myPrice;
    return Padding(
      key: ValueKey('request-${request.id}'),
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        onTap: () => _openRequest(request),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sent == null ? 'طلب جديد: ${request.problemType}' : 'عرضك بـ $sent ج.م: ${request.problemType}',
                    style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.dark),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'من ${request.minPrice} لـ ${request.maxPrice} ج.م • ${request.distanceKm} كم',
                    style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
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
              title: 'تعذر تحميل الطلبات',
              message: _errorMessage,
              onRetry: _loadOrders,
            ),
          ],
        ),
      );
    }

    final orders = [
      ..._orders.where((order) => order.isOngoing),
      ..._orders.where((order) => !order.isOngoing),
    ];

    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _loadOrders,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 16.0),
          itemCount: orders.isEmpty && _requests.isEmpty ? 1 : _requests.length + orders.length,
          itemBuilder: (context, position) {
            if (position < _requests.length) return _requestCard(_requests[position]);
            final index = position - _requests.length;
            if (orders.isEmpty) {
              return const AppStateMessage(
                icon: Icons.receipt_long_rounded,
                title: 'لا توجد طلبات حتى الآن',
                message: 'هتظهر الطلبات الواردة إليك هنا فور إرسالها من الموكلين.',
              );
            }
            final order = orders[index];
            return Padding(
              key: ValueKey(order.id),
              padding: const EdgeInsets.only(bottom: 12),
              child: OrderSummaryCard(
                order: order,
                isLawyer: true,
                onOpen: () => _openDetails(order),
              ),
            );
          },
        ),
      ),
    );
  }
}
