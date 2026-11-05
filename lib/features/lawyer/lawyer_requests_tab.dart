import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/app_visibility.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_state_message.dart';
import '../../core/widgets/lawyer_availability_card.dart';
import '../../data/models/service_request.dart';
import '../../data/repositories/order_repository.dart';
import '../../data/repositories/request_repository.dart';
import '../urgent_service/order_details_screen.dart';
import 'request_offer_screen.dart';

/// الطلبات الحالية بس: المنتظرة لسعر المحامي واللي الموكل اختار عرضه لحد الدفع، وبتتحدث لوحدها
class LawyerRequestsTab extends StatefulWidget {
  final ValueListenable<int>? refreshSignal;

  const LawyerRequestsTab({super.key, this.refreshSignal});

  @override
  State<LawyerRequestsTab> createState() => _LawyerRequestsTabState();
}

class _LawyerRequestsTabState extends State<LawyerRequestsTab> {
  bool _isLoading = true;
  bool _isFetching = false;
  List<IncomingRequest> _requests = const [];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    widget.refreshSignal?.addListener(_load);
    _load();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (isAppVisible) _load();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.refreshSignal?.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    if (_isFetching) return;
    _isFetching = true;
    final res = await RequestRepository.incoming();
    _isFetching = false;
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (res.isOk) _requests = res.data ?? const [];
    });
  }

  Future<void> _open(IncomingRequest request) async {
    final navigator = Navigator.of(context);
    final orderId = request.orderId;
    if (request.isChosen && orderId != null) {
      final res = await OrderRepository.getOrderById(orderId);
      final order = res.data;
      if (!mounted || order == null) return;
      await navigator.push(MaterialPageRoute(builder: (_) => OrderDetailsScreen(order: order, isLawyer: true)));
    } else {
      await navigator.push(MaterialPageRoute(builder: (_) => RequestOfferScreen(request: request)));
    }
    if (mounted) await _load();
  }

  (String, Color) _statusOf(IncomingRequest request) {
    if (request.isChosen) return ('الموكل اختار عرضك • مستنيين الدفع', AppColors.success);
    if (request.myPrice != null) return ('عرضك اتبعت، مستنيين الموكل يختار', AppColors.primary);
    return ('ابعت سعرك • باقي ${request.secondsLeft ~/ 60}:${(request.secondsLeft % 60).toString().padLeft(2, '0')}', AppColors.danger);
  }

  Widget _card(IncomingRequest request) {
    final (status, color) = _statusOf(request);
    final sent = request.myPrice;
    return Padding(
      key: ValueKey('request-${request.id}'),
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        onTap: () => _open(request),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(request.problemType, style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.dark)),
            const SizedBox(height: 4),
            Text(
              sent == null ? 'من ${request.minPrice} لـ ${request.maxPrice} ج.م • ${request.distanceKm} كم' : 'عرضك: $sent ج.م • ${request.distanceKm} كم',
              style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted),
            ),
            const SizedBox(height: 8),
            Text(status, style: TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 12, fontWeight: FontWeight.w800, color: color)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: AppColors.primary));

    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 16.0),
          itemCount: _requests.isEmpty ? 2 : _requests.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) return const LawyerAvailabilityCard();
            if (_requests.isEmpty) {
              return const AppStateMessage(
                icon: Icons.notifications_active_rounded,
                title: 'مفيش طلبات جديدة دلوقتي',
                message: 'خليك متاح، والطلبات القريبة منك هتظهر هنا.',
              );
            }
            return _card(_requests[index - 1]);
          },
        ),
      ),
    );
  }
}
