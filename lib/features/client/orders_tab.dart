import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/services/live_updates.dart';
import '../../core/services/order_store.dart';
import '../../core/widgets/app_skeleton.dart';
import '../../core/widgets/app_state_message.dart';
import '../../core/widgets/order_summary_card.dart';
import '../../core/widgets/orders_filter.dart';
import '../../data/models/consultation.dart';
import '../../data/models/order_model.dart';
import '../../data/models/service_request.dart';
import '../../data/repositories/consultation_repository.dart';
import '../../data/repositories/request_repository.dart';
import '../consultation/consultation_order_card.dart';
import '../urgent_service/order_details_sheet.dart';
import '../urgent_service/tracking_screen.dart';
import 'request_order_card.dart';

class OrdersTab extends StatefulWidget {
  /// إشارة من الحاوية لتحديث القائمة عند العودة لهذا التبويب
  final ValueListenable<int>? refreshSignal;

  const OrdersTab({super.key, this.refreshSignal});

  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab> {
  // آخر نسخة محفوظة بتظهر من أول لحظة، والتحميل بس لو مفيش حاجة محفوظة خالص
  late bool _isLoading = OrderStore.orders.value.isEmpty && !OrderStore.isLoaded;
  bool _isFetching = false;
  String? _errorMessage;
  List<OrderModel> _orders = OrderStore.orders.value;
  bool _showCurrent = true;

  /// الصفحة بتفتح دايمًا على الطلبات المفتوحة، حتى لو كانت آخر مرة على السجل
  void _backToCurrent() {
    if (mounted && !_showCurrent) setState(() => _showCurrent = true);
  }

  /// صفحة الطلبات شاملة كل الخدمات: «محاميك حالاً» والاستشارة السريعة
  List<Consultation> _consultations = ConsultationRepository.peek();
  StreamSubscription<LiveChange>? _live;

  @override
  void initState() {
    super.initState();
    widget.refreshSignal?.addListener(_loadOrders);
    widget.refreshSignal?.addListener(_backToCurrent);
    OrderStore.start();
    OrderStore.orders.addListener(_onStoreChanged);
    ApiService.isServerReachable.addListener(_onReachabilityChanged);
    _showSaved();
    _loadOrders();
    _loadConsultations();
    _loadRequests();
    _live = LiveUpdates.stream.listen((change) {
      if (change.kind == 'requests' || change.kind == 'orders' || change.isEverything || change.kind == 'notifications') _loadRequests();
      if (change.kind == 'consultations' || change.isEverything || change.kind == 'notifications') _loadConsultations();
    });
  }

  List<MyRequest> _requests = const [];

  Future<void> _loadRequests() async {
    final res = await RequestRepository.mine();
    if (!mounted || !res.isOk) return;
    setState(() => _requests = res.data ?? const []);
  }

  /// طلب مفتوح: الشاشة بتفتح على عروضه
  Future<void> _openRequest(MyRequest request) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => TrackingScreen(problemTitle: request.problemType, resumeRequestId: request.id)));
    _loadRequests();
  }

  Future<void> _loadConsultations() async {
    final res = await ConsultationRepository.list();
    if (!mounted || !res.isOk) return;
    setState(() => _consultations = res.data ?? const []);
  }

  /// أي طلب اتغير في المخزن، الصفحة تتغير معاه
  void _onStoreChanged() {
    if (!mounted) return;
    setState(() {
      _orders = OrderStore.orders.value;
      if (OrderStore.isLoaded) _isLoading = false;
    });
  }

  @override
  void dispose() {
    widget.refreshSignal?.removeListener(_loadOrders);
    widget.refreshSignal?.removeListener(_backToCurrent);
    OrderStore.orders.removeListener(_onStoreChanged);
    _live?.cancel();
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

    final res = await OrderStore.load();
    _isFetching = false;
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (res.isOk) {
        _orders = res.data ?? const [];
        _errorMessage = null;
      } else if (_orders.isEmpty) {
        _errorMessage = res.error ?? 'تعذر تحميل طلباتك، يرجى المحاولة مرة أخرى';
      }
    });
  }

  Future<void> _openConsultation(Consultation item) async {
    await ConsultationSheet.open(context, item);
    _loadConsultations();
  }

  Future<void> _openDetails(OrderModel order) async {
    await OrderDetailsSheet.open(context, order);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AppSkeletonList();
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

    // الطلبات والاستشارات مع بعض، الأحدث الأول
    final entries = <({DateTime date, Widget card, String key})>[
      for (final order in _orders.where((order) => order.isOngoing == _showCurrent))
        (
          date: DateTime.tryParse(order.createdAt) ?? DateTime(2000),
          key: 'order-${order.id}',
          card: OrderSummaryCard(order: order, onOpen: () { _openDetails(order); }),
        ),
      for (final request in _requests.where((request) => request.isOpen == _showCurrent))
        (
          date: request.createdAt ?? DateTime(2000),
          key: 'request-${request.id}',
          card: RequestOrderCard(request: request, onOpen: () { _openRequest(request); }),
        ),
      for (final item in _consultations.where((item) => item.isOngoing == _showCurrent))
        (
          date: item.createdAt ?? DateTime(2000),
          key: 'consultation-${item.id}',
          card: ConsultationOrderCard(item: item, onOpen: () { _openConsultation(item); }),
        ),
    ]..sort((a, b) => b.date.compareTo(a.date));
    final currentCount = _orders.where((order) => order.isOngoing).length + _consultations.where((item) => item.isOngoing).length + _requests.where((request) => request.isOpen).length;

    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => Future.wait([_loadOrders(), _loadConsultations(), _loadRequests()]),
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 16.0),
          itemCount: 1 + (entries.isEmpty ? 1 : entries.length),
          itemBuilder: (context, position) {
            if (position == 0) {
              return OrdersFilter(currentCount: currentCount, showCurrent: _showCurrent, onChanged: (value) => setState(() => _showCurrent = value));
            }
            final index = position - 1;
            if (entries.isEmpty) {
              return AppStateMessage(
                icon: Icons.receipt_long_rounded,
                title: _showCurrent ? 'مفيش طلبات حالية' : 'السجل فاضي',
                message: _showCurrent
                    ? 'أي طلب مفتوح من أي خدمة بيظهر هنا\nزي «محضر شرطة» و«استشارة قانونية»'
                    : 'الطلبات اللي خلصت أو اتلغت من كل الخدمات\nبتتجمع هنا',
              );
            }
            // آخر كارت في السجل ظهر: الصفحة اللي بعدها تتحمل لوحدها
            if (!_showCurrent && index == entries.length - 1) unawaited(OrderStore.loadMore());
            final entry = entries[index];
            return Padding(
              key: ValueKey(entry.key),
              padding: const EdgeInsets.only(bottom: 12),
              child: entry.card,
            );
          },
        ),
      ),
    );
  }
}
