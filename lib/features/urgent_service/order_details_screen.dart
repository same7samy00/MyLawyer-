import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/services/app_visibility.dart';
import '../../core/services/external_navigation.dart';
import '../../core/services/location_service.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_header.dart';
import '../../core/widgets/order_action_sheets.dart';
import '../../core/widgets/order_status_tracker.dart';
import '../../core/widgets/response_countdown.dart';
import '../../data/models/order_model.dart';
import '../../data/repositories/order_repository.dart';
import '../support/new_ticket_screen.dart';
import '../support/ticket_details_screen.dart';
import 'payment_screen.dart';

/// كل تفاصيل الطلب وإجراءاته للموكل والمحامي في صفحة واحدة
class OrderDetailsScreen extends StatefulWidget {
  final OrderModel order;
  final bool isLawyer;

  const OrderDetailsScreen({super.key, required this.order, this.isLawyer = false});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  late OrderModel _order = widget.order;
  Timer? _refreshTimer;
  bool _isFetching = false;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    // الحالة تتحدث من غير سحب الصفحة طول ما الطلب جاري
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (isAppVisible && _order.isOngoing) _load();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (_isFetching) return;
    _isFetching = true;

    final res = await OrderRepository.getOrders();
    _isFetching = false;
    if (!mounted || !res.isOk) return;

    for (final order in res.data ?? const <OrderModel>[]) {
      if (order.id == _order.id) {
        final justFinished = !_order.canReview && order.canReview;
        setState(() => _order = order);
        // The rating opens by itself the moment the lawyer finishes the task
        if (justFinished && !widget.isLawyer) await _openReview(isEdit: false);
        return;
      }
    }
  }

  void _showNotice(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback),
        ),
        backgroundColor: AppColors.dark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7.0)),
      ),
    );
  }

  /// تنفيذ إجراء واحد في المرة، ونتيجته تظهر كإشعار واضح
  Future<void> _run(Future<ApiResponse<dynamic>> Function() action, String success) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);

    final res = await action();
    if (!mounted) return;

    setState(() => _isBusy = false);
    _showNotice(res.isOk ? success : (res.error ?? 'تعذر تنفيذ العملية'));
    await _load();
  }

  Future<bool> _confirm(String title, String message, String action) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7.0)),
        title: Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontWeight: FontWeight.w800),
        ),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('تراجع')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(action)),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _copyOrderNumber() async {
    await Clipboard.setData(ClipboardData(text: _order.orderNumber));
    if (mounted) _showNotice('تم نسخ رقم الطلب');
  }

  Future<void> _call(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final opened = await ExternalNavigation.call(phone);
    if (!opened && mounted) _showNotice('تعذر فتح الاتصال');
  }

  Future<void> _openDirections() async {
    final opened = await ExternalNavigation.openDirections(_order.clientLat, _order.clientLon);
    if (!opened && mounted) _showNotice('تعذر فتح الخرائط');
  }

  // إجراءات الموكل

  Future<void> _openPayment() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PaymentScreen(
          orderId: _order.id,
          orderNumber: _order.orderNumber,
          locationName: _order.clientAddress ?? '',
          problemTitle: _order.problemType ?? _order.serviceTitle,
          problemDescription: _order.problemDescription,
          price: _order.price.round(),
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _cancelOrder() async {
    final message = _order.isActive ? 'المبلغ هيرجع لرصيدك' : 'الطلب هيتلغي ومفيش أي مبلغ هيتخصم';
    if (!await _confirm('إلغاء الطلب', message, 'إلغاء الطلب')) return;
    await _run(() => OrderRepository.cancelOrder(_order.id), 'تم إلغاء الطلب');
  }

  /// أول مرة بيفتح تذكرة جديدة على الطلب، وبعدها بيفتح نفس التذكرة للمتابعة
  Future<void> _openComplaint() async {
    final ticketId = _order.openTicketId;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ticketId == null ? NewTicketScreen(order: _order) : TicketDetailsScreen(ticketId: ticketId),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _openReview({required bool isEdit}) async {
    final sent = await OrderActionSheets.review(
      context,
      lawyerName: _order.lawyerName ?? 'المحامي',
      onSubmit: (rating, comment) => isEdit
          ? OrderRepository.updateReview(_order.id, rating, comment)
          : OrderRepository.submitReview(_order.id, rating, comment),
    );
    if (!sent || !mounted) return;
    _showNotice(isEdit ? 'تم تعديل تقييمك' : 'شكراً لتقييمك');
    await _load();
  }

  // إجراءات المحامي

  Future<void> _acceptOrder() async {
    // تعذر الموقع لا يمنع القبول، والموكل يشوف وقت آخر مكان معروف
    final location = await LocationService.instance.checkAndRequestPermission(fresh: true);
    if (!mounted) return;

    await _run(
      () => OrderRepository.acceptOrder(
        _order.id,
        lat: location.position?.latitude,
        lon: location.position?.longitude,
      ),
      'تم قبول الطلب',
    );
  }

  Future<void> _rejectOrder() async {
    if (!await _confirm('الاعتذار عن الطلب', 'هتعتذر عن قبول الطلب ده؟', 'اعتذار')) return;
    await _run(() => OrderRepository.rejectOrder(_order.id), 'تم الاعتذار عن الطلب');
  }

  Future<void> _markArrived() async {
    // The arrival proves the meeting, so it needs the lawyer's real location
    final location = await LocationService.instance.checkAndRequestPermission(fresh: true);
    final position = location.position;
    if (!mounted) return;
    if (position == null) {
      _showNotice('شغّل الموقع عشان نتأكد إنك على بعد 50 متر من الموكل');
      return;
    }

    await _run(
      () => OrderRepository.markArrived(_order.id, position.latitude, position.longitude),
      'تم تسجيل وصولك',
    );
  }

  Future<void> _openCompletion() async {
    if (!await _confirm('إنهاء المهمة', 'خلصت المهمة مع الموكل؟', 'إنهاء')) return;
    await _run(() => OrderRepository.completeOrder(_order.id), 'تم إنهاء المهمة، والصافي هيتاح بعد 24 ساعة');
  }

  Future<void> _withdraw() async {
    if (!await _confirm('الاعتذار عن المهمة', 'المبلغ هيرجع للموكل وهتتسجل عليك نقطة', 'اعتذار')) return;
    await _run(() => OrderRepository.withdrawFromOrder(_order.id), 'تم تسجيل الاعتذار');
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppHeader(title: 'تفاصيل الطلب', isInnerPage: true),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(18),
            children: [
              if (order.isPending) ...[
                ResponseCountdown(secondsLeft: order.responseSecondsLeft, onFinished: _load),
                const SizedBox(height: 12),
              ],
              _buildNumberCard(order),
              const SizedBox(height: 12),
              AppCard(
                padding: const EdgeInsets.all(14),
                child: OrderStatusTracker(
                  order: order,
                  statusText: widget.isLawyer ? order.lawyerStatusLabel : null,
                ),
              ),
              const SizedBox(height: 12),
              _buildDetailsCard(order),
              const SizedBox(height: 16),
              if (widget.isLawyer) ..._buildLawyerActions(order) else ..._buildClientActions(order),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumberCard(OrderModel order) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: _copyOrderNumber,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('رقم الطلب', style: _labelStyle),
                const SizedBox(height: 2),
                Text(order.orderNumber, style: _numberStyle),
                const SizedBox(height: 2),
                Text(order.formattedDate, style: _labelStyle),
              ],
            ),
          ),
          const Icon(Icons.copy_rounded, size: 20, color: AppColors.textMuted),
        ],
      ),
    );
  }

  Widget _buildDetailsCard(OrderModel order) {
    final isLawyer = widget.isLawyer;
    final phone = isLawyer ? order.clientPhone : order.lawyerPhone;
    final closingReason = order.cancellationReason ?? order.rejectionReason;
    final rows = <Widget>[
      _infoRow(isLawyer ? 'الموكل' : 'المحامي', (isLawyer ? order.clientName : order.lawyerName) ?? '-'),
      if (order.isPaid && phone != null && phone.isNotEmpty) _infoRow('رقم الهاتف', phone),
      _infoRow('نوع المشكلة', order.problemType ?? order.serviceTitle),
      if (order.problemDescription.isNotEmpty) _infoRow('تفاصيل المشكلة', order.problemDescription),
      if (order.clientAddress != null) _infoRow('المنطقة', order.clientAddress!),
      _infoRow(
        isLawyer ? 'صافي أتعابك' : (order.isPaid ? 'الأتعاب المسددة' : 'الأتعاب المستحقة'),
        '${order.priceText} ج.م',
        valueColor: isLawyer || order.isPaid ? AppColors.success : null,
      ),
      if (!order.isOngoing && closingReason != null) _infoRow('السبب', closingReason),
    ];

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.cardBorder),
            rows[i],
          ],
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 104, child: Text(label, style: _labelStyle)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'AppFont',
                fontFamilyFallback: appFontFallback,
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w800,
                color: valueColor ?? AppColors.dark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _action(String text, VoidCallback onPressed, {bool isDanger = false, IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppButton.outlined(
        text: text,
        icon: icon,
        height: 44,
        fontSize: 13,
        textColor: isDanger ? AppColors.danger : null,
        borderColor: isDanger ? AppColors.danger.withOpacity(0.35) : null,
        onPressed: _isBusy ? null : onPressed,
      ),
    );
  }

  Widget _primaryAction(String text, VoidCallback onPressed, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppButton.primary(
        text: text,
        icon: icon,
        height: 46,
        fontSize: 14,
        onPressed: _isBusy ? null : onPressed,
      ),
    );
  }

  Widget _statusNote(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'AppFont',
          fontFamilyFallback: appFontFallback,
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: AppColors.danger,
        ),
      ),
    );
  }

  List<Widget> _buildClientActions(OrderModel order) {
    return [
      if (order.isAccepted) ...[
        _statusNote('طلب غير مكتمل • باقي ${order.paymentMinutesLeft} دقيقة للدفع'),
        _primaryAction('ادفع ${order.priceText} ج.م', _openPayment),
      ],
      if (order.isActive && order.lawyerPhone != null)
        _primaryAction('اتصل بالمحامي', () => _call(order.lawyerPhone), icon: Icons.call_rounded),
      if (order.canReview) _primaryAction('قيّم المحامي', () => _openReview(isEdit: false)),
      if (order.canEditReview) _action('تعديل التقييم', () => _openReview(isEdit: true)),
      if (order.hasOpenComplaint) _statusNote('الطلب قيد المراجعة، والأتعاب متوقفة لحد قرار الإدارة'),
      ..._problemAction(order),
      if (order.canCancel) _action('إلغاء الطلب', _cancelOrder, isDanger: true),
    ];
  }

  /// «عندك مشكلة؟» يفتح تذكرة جديدة، ولو فيه تذكرة مفتوحة يبقى «تابع مشكلتك»
  List<Widget> _problemAction(OrderModel order) {
    if (order.hasOpenTicket) return [_action('تابع مشكلتك', _openComplaint, icon: Icons.headset_mic_outlined)];
    if (order.canOpenTicket) return [_action('عندك مشكلة؟', _openComplaint, isDanger: true)];
    return const [];
  }

  List<Widget> _buildLawyerActions(OrderModel order) {
    return [
      if (order.isPending) ...[
        _primaryAction('قبول الطلب', _acceptOrder, icon: Icons.check_circle_rounded),
        _action('اعتذار', _rejectOrder, isDanger: true),
      ],
      if (order.isActive) ...[
        if (order.hasOpenComplaint) _statusNote('الطلب قيد المراجعة، والأتعاب متوقفة لحد قرار الإدارة'),
        if (order.clientPhone != null)
          _action('اتصل بالموكل', () => _call(order.clientPhone), icon: Icons.call_rounded),
        _action('افتح مكان الموكل في Google Maps', _openDirections, icon: Icons.navigation_rounded),
        if (!order.hasOpenComplaint) ...[
          // Finishing stays hidden until the lawyer arrives within 50 meters of the client
          if (order.arrivedAt == null)
            _primaryAction('وصلت', _markArrived)
          else
            _primaryAction('إنهاء المهمة', _openCompletion),
          _action('اعتذار', _withdraw, isDanger: true),
        ],
      ],
      ..._problemAction(order),
    ];
  }

  static const TextStyle _labelStyle = TextStyle(
    fontFamily: 'AppFont',
    fontFamilyFallback: appFontFallback,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textMuted,
  );

  static const TextStyle _numberStyle = TextStyle(
    fontFamily: 'AppFont',
    fontFamilyFallback: appFontFallback,
    fontSize: 18,
    fontWeight: FontWeight.w900,
    color: AppColors.primary,
  );
}
