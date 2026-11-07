import '../../core/widgets/app_loader.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/services/live_updates.dart';
import '../../core/services/order_store.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_state_message.dart';
import '../../core/widgets/lawyer_availability_card.dart';
import '../../core/widgets/order_summary_card.dart';
import '../../core/widgets/orders_filter.dart';
import '../../core/widgets/request_parts.dart';
import '../../data/models/order_model.dart';
import '../../data/models/service_request.dart';
import '../../data/repositories/request_repository.dart';
import '../urgent_service/order_details_sheet.dart';
import 'request_offer_sheet.dart';

/// صفحة طلبات المحامي الموحدة: زر للحالي واللحظي وزر للسجل، والتفاصيل والإجراءات في بوتن شيت
class LawyerOrdersTab extends StatefulWidget {
  /// إشارة من الحاوية لتحديث القائمة عند العودة لهذا التبويب
  final ValueListenable<int>? refreshSignal;

  const LawyerOrdersTab({super.key, this.refreshSignal});

  @override
  State<LawyerOrdersTab> createState() => _LawyerOrdersTabState();
}

class _LawyerOrdersTabState extends State<LawyerOrdersTab> {
  // آخر نسخة محفوظة بتظهر من أول لحظة، والتحميل بس لو مفيش حاجة محفوظة خالص
  late bool _isLoading = OrderStore.orders.value.isEmpty && !OrderStore.isLoaded;
  bool _isFetching = false;
  String? _errorMessage;
  List<OrderModel> _orders = OrderStore.orders.value;
  List<IncomingRequest> _requests = const [];
  bool _showCurrent = true;

  @override
  void initState() {
    super.initState();
    widget.refreshSignal?.addListener(_loadOrders);
    OrderStore.start();
    OrderStore.orders.addListener(_onStoreChanged);
    LiveUpdates.requests.addListener(_loadRequests);
    ApiService.isServerReachable.addListener(_onReachabilityChanged);
    _showSaved();
    _loadOrders();
  }

  /// أي طلب اتغير في المخزن، الصفحة تتغير معاه
  void _onStoreChanged() {
    if (!mounted) return;
    setState(() {
      _orders = OrderStore.orders.value;
      if (OrderStore.isLoaded) _isLoading = false;
    });
  }

  /// الطلبات الجديدة والعروض بس، من غير ما الطلبات كلها تتجاب
  Future<void> _loadRequests() async {
    final res = await RequestRepository.incoming();
    if (!mounted || !res.isOk) return;
    setState(() => _requests = (res.data ?? const <IncomingRequest>[]).where((item) => !item.isChosen).toList());
  }

  @override
  void dispose() {
    widget.refreshSignal?.removeListener(_loadOrders);
    OrderStore.orders.removeListener(_onStoreChanged);
    LiveUpdates.requests.removeListener(_loadRequests);
    ApiService.isServerReachable.removeListener(_onReachabilityChanged);
    super.dispose();
  }

  void _onReachabilityChanged() {
    if (ApiService.isServerReachable.value && _errorMessage != null) {
      _loadOrders();
    }
  }

  /// آخر طلبات محفوظة بتظهر فورًا، والتحديث من السيرفر بيحل محلها
  Future<void> _showSaved() async {
    await OrderStore.showSaved();
    if (!mounted || OrderStore.orders.value.isEmpty || !_isLoading) return;
    setState(() {
      _orders = OrderStore.orders.value;
      _isLoading = false;
    });
  }

  Future<void> _loadOrders() async {
    if (_isFetching) return;
    _isFetching = true;

    final results = await Future.wait([OrderStore.load(), RequestRepository.incoming()]);
    final res = results[0] as ApiResponse<List<OrderModel>>;
    final requests = results[1] as ApiResponse<List<IncomingRequest>>;
    _isFetching = false;
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      // العرض المختار بقى طلب، فبطاقته هي بطاقة الطلب
      if (requests.isOk) _requests = (requests.data ?? const <IncomingRequest>[]).where((item) => !item.isChosen).toList();
      if (res.isOk) {
        _orders = res.data ?? const [];
        _errorMessage = null;
      } else if (_orders.isEmpty) {
        _errorMessage = res.error ?? 'تعذر تحميل الطلبات، يرجى المحاولة مرة أخرى';
      }
    });
  }

  Future<void> _openDetails(OrderModel order) async {
    await OrderDetailsSheet.open(context, order, isLawyer: true);
  }

  Future<void> _openRequest(IncomingRequest request) async {
    await RequestOfferSheet.open(context, request);
    if (mounted) await _loadOrders();
  }

  Widget _requestCard(IncomingRequest request) {
    final sent = request.myPrice;
    return Padding(
      key: ValueKey('request-${request.id}'),
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    request.problemType,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.dark),
                  ),
                ),
                if (sent == null) RequestTimeBadge(secondsLeft: request.secondsLeft),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.location_on_rounded, size: 15, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${request.area ?? 'مكان الموكل'} • ${request.distanceKm} كم',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            RequestPriceBox(minPrice: request.minPrice, maxPrice: request.maxPrice, sentPrice: sent),
            const SizedBox(height: 12),
            RequestSteps(priceSent: sent != null),
            const SizedBox(height: 12),
            AppButton.primary(text: 'تفاصيل الطلب', height: 42, fontSize: 13, onPressed: () { _openRequest(request); }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: AppLoader());
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

    final orders = _orders.where((order) => order.isOngoing == _showCurrent).toList();
    final requests = _showCurrent ? _requests.where((item) => item.myPrice != null || item.secondsLeftNow > 0).toList() : const <IncomingRequest>[];

    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _loadOrders,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 16.0),
          itemCount: 2 + requests.length + (orders.isEmpty && requests.isEmpty ? 1 : orders.length),
          itemBuilder: (context, position) {
            if (position == 0) return const LawyerAvailabilityCard();
            if (position == 1) {
              return OrdersFilter(currentCount: _requests.length + _orders.where((order) => order.isOngoing).length, showCurrent: _showCurrent, onChanged: (value) => setState(() => _showCurrent = value));
            }
            if (position - 2 < requests.length) return _requestCard(requests[position - 2]);
            final index = position - requests.length - 2;
            if (orders.isEmpty) {
              return const AppStateMessage(
                icon: Icons.receipt_long_rounded,
                title: 'لا توجد طلبات حتى الآن',
                message: 'خليك متاح، والطلبات القريبة منك هتظهر هنا أول بأول',
              );
            }
            final order = orders[index];
            return Padding(
              key: ValueKey(order.id),
              padding: const EdgeInsets.only(bottom: 12),
              child: OrderSummaryCard(
                order: order,
                isLawyer: true,
                onOpen: () { _openDetails(order); },
              ),
            );
          },
        ),
      ),
    );
  }
}
