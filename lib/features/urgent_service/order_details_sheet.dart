import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/services/external_navigation.dart';
import '../../core/services/location_service.dart';
import '../../core/services/notification_center.dart';
import '../../core/services/order_store.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/lawyer_profile_sheet.dart';
import '../../core/widgets/order_action_sheets.dart';
import '../../core/widgets/order_status_tracker.dart';
import '../../core/widgets/postponed_since.dart';
import '../../core/widgets/sheet_actions.dart';
import '../../data/models/order_model.dart';
import '../../data/repositories/order_repository.dart';
import '../support/new_ticket_screen.dart';
import '../support/ticket_details_screen.dart';
import 'arrival_time_card.dart';
import 'payment_screen.dart';

/// كل تفاصيل الطلب وإجراءاته للموكل والمحامي في بوتن شيت، وبتتحدث لوحدها
class OrderDetailsSheet extends StatefulWidget {
  final OrderModel order;
  final bool isLawyer;

  const OrderDetailsSheet({super.key, required this.order, this.isLawyer = false});

  static Future<void> open(BuildContext context, OrderModel order, {bool isLawyer = false}) {
    return AppSheet.show<void>(context, builder: (_) => OrderDetailsSheet(order: order, isLawyer: isLawyer));
  }

  @override
  State<OrderDetailsSheet> createState() => _OrderDetailsSheetState();
}

class _OrderDetailsSheetState extends State<OrderDetailsSheet> {
  late OrderModel _order = widget.order;
  bool _isFetching = false;
  bool _isBusy = false;
  String? _notice;
  Timer? _noticeTimer;

  @override
  void initState() {
    super.initState();
    OrderStore.orders.addListener(_onStoreChanged);
    _load();
    NotificationCenter.markTargetRead(NotificationTarget(orderId: widget.order.id));
  }

  @override
  void dispose() {
    _noticeTimer?.cancel();
    OrderStore.orders.removeListener(_onStoreChanged);
    super.dispose();
  }

  /// الطلب ده بس بيتجاب من السيرفر، والمخزن بيوزعه على كل الشاشات
  Future<void> _load() async {
    if (_isFetching) return;
    _isFetching = true;
    await OrderStore.refreshOne(_order.id);
    _isFetching = false;
  }

  Future<void> _onStoreChanged() async {
    final order = OrderStore.find(_order.id);
    if (!mounted || order == null) return;
    final justFinished = !_order.canReview && order.canReview;
    setState(() => _order = order);
    // The rating opens by itself the moment the lawyer finishes the task
    if (justFinished && !widget.isLawyer) await _openReview(isEdit: false);
  }

  /// الرسالة بتظهر جوه الشيت، لأن الصفحة اللي تحته متغطية
  void _showNotice(String message) {
    _noticeTimer?.cancel();
    setState(() => _notice = message);
    _noticeTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _notice = null);
    });
  }

  /// تنفيذ إجراء واحد في المرة، ونتيجته تظهر كإشعار واضح
  Future<void> _run(Future<ApiResponse<dynamic>> Function() action, String success) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);

    final res = await action();
    if (!mounted) return;

    setState(() => _isBusy = false);
    _showNotice(res.isOk ? success : (res.error ?? 'تعذر تنفيذ العملية'));
    // السيرفر بيعلّم إشعارات الطلب مقروءة مع أي إجراء، فالعداد يتحدث على طول
    unawaited(NotificationCenter.refresh());
    await _load();
  }

  Future<bool> _confirm(String title, String message, String action, {IconData icon = Icons.help_outline_rounded, bool isDanger = false}) {
    return AppDialog.confirm(context, icon: icon, title: title, message: message, confirmText: action, isDanger: isDanger);
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
    if (!await _confirm('إلغاء الطلب', message, 'إلغاء الطلب', icon: Icons.cancel_outlined, isDanger: true)) return;
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

  Future<void> _markArrived() async {
    // The arrival proves the meeting, so it needs the lawyer's real location
    final location = await LocationService.instance.checkAndRequestPermission(fresh: true);
    final position = location.position;
    if (!mounted) return;
    if (position == null) {
      _showNotice('شغّل الموقع عشان نتأكد إنك قريب من الموكل');
      return;
    }

    await _run(
      () => OrderRepository.markArrived(_order.id, position.latitude, position.longitude, mocked: position.isMocked),
      'تم تسجيل وصولك',
    );
  }

  Future<void> _openCompletion() async {
    if (!await _confirm('إنهاء المهمة', 'خلصت المهمة مع الموكل؟', 'إنهاء', icon: Icons.verified_rounded)) return;
    await _run(() => OrderRepository.completeOrder(_order.id), 'تم إنهاء المهمة، والصافي هيتاح بعد 24 ساعة');
  }

  Future<void> _openPostpone() async {
    if (!await _confirm('تأجيل المهمة', 'المهمة هتتأجل وفلوسها هتفضل محجوزة لحد ما تنهيها\nوتقدر تستقبل طلبات تانية لحد ما تكملها', 'تأجيل', icon: Icons.schedule_rounded)) return;
    await _run(() => OrderRepository.postponeOrder(_order.id), 'تم تأجيل المهمة');
  }

  Future<void> _withdraw() async {
    if (!await _confirm('الاعتذار عن المهمة', 'المبلغ هيرجع للموكل وهتتسجل عليك مخالفة\n3 مخالفات خلال 30 يوم بتوقف حسابك أسبوع', 'اعتذار', icon: Icons.policy_rounded, isDanger: true)) return;
    await _run(() => OrderRepository.withdrawFromOrder(_order.id), 'تم تسجيل الاعتذار');
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;

    return AppSheet(
      title: 'تفاصيل الطلب',
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
      children: [
        if (_notice != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.dark, borderRadius: BorderRadius.circular(7.0)),
            child: Text(
              _notice!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 13, color: Colors.white),
            ),
          ),
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
        if (order.isActive && order.arrivedAt == null) ...[
          ArrivalTimeCard(order: order, isLawyer: widget.isLawyer),
          const SizedBox(height: 12),
        ],
        _buildDetailsCard(order),
        const SizedBox(height: 16),
        ...packSheetActions(widget.isLawyer ? _buildLawyerActions(order) : _buildClientActions(order)),
      ],
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
    final closingReason = order.cancellationReason ?? order.rejectionReason;
    final rows = <Widget>[
      _infoRow(
        isLawyer ? 'الموكل' : 'المحامي',
        (isLawyer ? order.clientName : order.lawyerName) ?? '-',
        onTap: !isLawyer && order.lawyerId != null ? () => _openLawyerProfile(order) : null,
      ),
      _infoRow('نوع المشكلة', order.problemType ?? order.serviceTitle),
      if (order.problemDescription.isNotEmpty) _infoRow('تفاصيل المشكلة', order.problemDescription),
      if (order.clientAddress != null) _infoRow('المنطقة', order.clientAddress!),
      _infoRow(
        isLawyer ? 'صافي أتعابك' : (order.isPaid ? 'الأتعاب المسددة' : 'الأتعاب المستحقة'),
        '${order.priceText} ج.م',
        valueColor: isLawyer || order.isPaid ? AppColors.success : null,
      ),
      if (order.reviewRating != null)
        _infoRow(
          isLawyer ? 'تقييم الموكل' : 'تقييمك',
          '${'★' * order.reviewRating!}${'☆' * (5 - order.reviewRating!)}',
          valueColor: const Color(0xFFEAB308),
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

  /// ملف المحامي وتقييماته من غير ما الطلب يتقفل
  Future<void> _openLawyerProfile(OrderModel order) {
    return LawyerProfileSheet.open(
      context,
      lawyerId: order.lawyerId!,
      name: order.lawyerName ?? 'المحامي',
      photoPath: order.lawyerAvatar,
      rating: order.lawyerRating ?? 0,
      reviewsCount: order.lawyerReviewsCount,
      experienceYears: order.lawyerExperienceYears,
    );
  }

  Widget _infoRow(String label, String value, {Color? valueColor, VoidCallback? onTap}) {
    final row = Padding(
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
                color: valueColor ?? (onTap != null ? AppColors.primary : AppColors.dark),
              ),
            ),
          ),
          if (onTap != null) ...[
            const Text('عرض الملف', style: TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
          ],
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(7.0), child: row);
  }

  Widget _action(String text, VoidCallback onPressed, {bool isDanger = false, IconData? icon}) {
    return SheetButton(text, _isBusy ? null : onPressed, icon: icon, isDanger: isDanger);
  }

  Widget _primaryAction(String text, VoidCallback onPressed, {IconData? icon}) {
    return SheetButton(text, _isBusy ? null : onPressed, icon: icon, isPrimary: true);
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
      if (order.canChooseToWait) ...[
        _statusNote('المحامي اتأخر\nتحب تستنى ولا تلغي وترجع فلوسك؟'),
        _primaryAction('هستنى', () => _run(() => OrderRepository.keepWaiting(order.id), 'تمام، هنكمل الانتظار')),
      ],
      if (order.isPostponed) PostponedSince(since: order.postponedAt!, note: 'والفلوس محجوزة لحد ما المحامي ينهيها'),
      if (order.isActive && order.lawyerPhone != null)
        SheetButton('اتصل بالمحامي', _isBusy ? null : () => _call(order.lawyerPhone), icon: Icons.call_rounded, isSuccess: true),
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
      if (order.isActive) ...[
        if (order.hasOpenComplaint) _statusNote('الطلب قيد المراجعة، والأتعاب متوقفة لحد قرار الإدارة'),
        if (order.clientPhone != null)
          SheetButton('اتصل بالموكل', _isBusy ? null : () => _call(order.clientPhone), icon: Icons.call_rounded, isSuccess: true),
        _action('افتح مكان الموكل في Google Maps', _openDirections, icon: Icons.navigation_rounded),
        if (!order.hasOpenComplaint) ...[
          // Finishing stays hidden until the lawyer arrives within 50 meters of the client
          if (order.isPostponed) PostponedSince(since: order.postponedAt!, note: 'وأتعابها محجوزة لحد ما تنهيها'),
          if (order.arrivedAt == null)
            _primaryAction('وصلت', _markArrived)
          else ...[
            _primaryAction('إنهاء المهمة', _openCompletion),
            // المؤجلة بتتنهي على طول، ومفيش «إلغاء التأجيل»
            if (!order.isPostponed) _action('مؤجل', _openPostpone),
          ],
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

/// سبب التأجيل اللي بيوصل للموكل
