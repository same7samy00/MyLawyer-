import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/services/app_visibility.dart';
import '../../core/services/live_updates.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_state_message.dart';
import '../../core/widgets/lawyer_availability_card.dart';
import '../../core/widgets/order_summary_card.dart';
import '../../data/models/order_model.dart';
import '../../data/models/service_request.dart';
import '../../data/repositories/order_repository.dart';
import '../../data/repositories/request_repository.dart';
import '../urgent_service/order_details_sheet.dart';
import 'request_offer_sheet.dart';

/// صفحة طلبات المحامي الموحدة: الجديد والشغال فوق والمنتهي تحت، والتفاصيل والإجراءات في بوتن شيت
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
    LiveUpdates.changes.addListener(_loadOrders);
    ApiService.isServerReachable.addListener(_onReachabilityChanged);
    _loadOrders();
    // الطلب الجديد وانتهاء مهلته يظهران من غير سحب الصفحة
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (isAppVisible) _loadOrders();
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

    final results = await Future.wait([OrderRepository.getOrders(), RequestRepository.incoming()]);
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
        _errorMessage = res.error ?? 'تعذر تحميل الطلبات، يرجى المحاولة مرة أخرى.';
      }
    });
  }

  Future<void> _openDetails(OrderModel order) async {
    await OrderDetailsSheet.open(context, order, isLawyer: true);
    if (mounted) await _loadOrders();
  }

  Future<void> _openRequest(IncomingRequest request) async {
    await RequestOfferSheet.open(context, request);
    if (mounted) await _loadOrders();
  }

  Widget _requestCard(IncomingRequest request) {
    final sent = request.myPrice;
    final seconds = request.secondsLeft;
    return Padding(
      key: ValueKey('request-${request.id}'),
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(request.problemType, style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.dark)),
            const SizedBox(height: 4),
            Text(
              sent == null ? 'من ${request.minPrice} لـ ${request.maxPrice} ج.م • ${request.distanceKm} كم' : 'عرضك: $sent ج.م • ${request.distanceKm} كم',
              style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted),
            ),
            const SizedBox(height: 10),
            _step('الطلب وصل', true),
            _step(sent == null ? 'ابعت سعرك • باقي ${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}' : 'عرضك اتبعت', sent != null),
            _step('الموكل يختار', false),
            _step('الدفع', false),
            const SizedBox(height: 8),
            AppButton.outlined(text: 'تفاصيل الطلب', height: 40, fontSize: 13, onPressed: () { _openRequest(request); }),
          ],
        ),
      ),
    );
  }

  Widget _step(String text, bool isDone) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 16,
            color: isDone ? AppColors.success : AppColors.textMuted,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text, style: TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 12, fontWeight: FontWeight.w700, color: isDone ? AppColors.dark : AppColors.textMuted)),
          ),
        ],
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
          itemCount: 1 + _requests.length + (orders.isEmpty && _requests.isEmpty ? 1 : orders.length),
          itemBuilder: (context, position) {
            if (position == 0) return const LawyerAvailabilityCard();
            if (position <= _requests.length) return _requestCard(_requests[position - 1]);
            final index = position - _requests.length - 1;
            if (orders.isEmpty) {
              return const AppStateMessage(
                icon: Icons.receipt_long_rounded,
                title: 'لا توجد طلبات حتى الآن',
                message: 'خليك متاح، والطلبات القريبة منك هتظهر هنا أول بأول.',
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
