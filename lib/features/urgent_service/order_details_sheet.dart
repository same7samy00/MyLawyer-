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
import '../../core/widgets/order_card.dart';
import '../../core/widgets/order_details_parts.dart';
import '../../core/widgets/order_status_tracker.dart';
import '../../core/widgets/order_summary_card.dart';
import '../../core/widgets/postponed_since.dart';
import '../../core/widgets/sheet_actions.dart';
import '../../core/widgets/status_pill.dart';
import '../../data/models/order_model.dart';
import '../../data/repositories/field_repository.dart';
import '../../data/repositories/order_repository.dart';
import '../field_service/field_order_blocks.dart';
import '../support/new_ticket_screen.dart';
import '../support/ticket_details_screen.dart';
import 'arrival_status_pill.dart';
import 'lawyer_on_map_card.dart';
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

  /// الإشارة ضعيفة جوه المبنى: الموكل يأكد الوصول من موبايله
  Future<void> _askArrival() async {
    if (!await _confirm('تأكيد الوصول من الموكل', 'لو إنت مع الموكل والزرار مش راضي\nهنبعتله يأكد وصولك من موبايله', 'ابعت للموكل', icon: Icons.how_to_reg_rounded)) return;
    await _run(() => OrderRepository.askArrival(_order.id), 'بعتنا للموكل يأكد وصولك');
  }

  Future<void> _confirmArrival() async {
    if (!await _confirm('المحامي وصل؟', 'أكّد بس لو المحامي معاك دلوقتي', 'أيوه وصل', icon: Icons.how_to_reg_rounded)) return;
    await _run(() => OrderRepository.confirmArrival(_order.id), 'تم تأكيد وصول المحامي');
  }

  /// الخدمة الميدانية: الشخص قال الكود، والمحامي بيكتبه فيتسجل الوصول
  Future<void> _openCodeEntry() async {
    final code = await FieldCodeSheet.ask(context);
    if (code == null || !mounted) return;
    await _run(() => FieldRepository.submitCode(_order.id, code), 'تم تسجيل وصولك');
  }

  /// الشخص رفض المحامي بعد ما قابله: الطلب بيتقفل والأتعاب للمحامي كاملة
  Future<void> _personRefused() async {
    if (!await _confirm('الشخص رفض المحامي؟', 'المهمة هتتقفل والأتعاب كاملة ليك، وهتتاح بعد 24 ساعة', 'أيوه، رفض', icon: Icons.person_off_rounded, isDanger: true)) return;
    await _run(() => FieldRepository.personRefused(_order.id), 'تم تسجيل رفض الشخص');
  }

  Future<void> _addProof() async {
    final path = await pickProofPhoto(context);
    if (path == null || !mounted) return;
    await _run(() => FieldRepository.uploadProof(_order.id, path), 'الصورة اتحفظت عند الإدارة');
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
          child: OrderStatusTracker(order: order, status: _statusPill(order)),
        ),
        const SizedBox(height: 12),
        if (!widget.isLawyer && order.field?.code != null) ...[
          FieldCodeCard(code: order.field!.code!, placeName: order.field!.placeName, onNotice: _showNotice),
          const SizedBox(height: 12),
        ],
        if (order.isActive && order.arrivedAt == null) ...[
          // الموكل بيشوف المحامي جاي على الخريطة، والمحامي معاه Google Maps
          if (!widget.isLawyer) ...[
            LawyerOnMapCard(order: order),
            const SizedBox(height: 12),
          ],
        ],
        _buildDetailsCard(order),
        const SizedBox(height: 16),
        ...packSheetActions(widget.isLawyer ? _buildLawyerActions(order) : _buildClientActions(order)),
      ],
    );
  }

  /// الحالة تحت المراحل: من الدفع لحد الوصول وقت الوصول الحي، وغير كده حالة الطلب. بتتحدث مع كل تغيير في الطلب
  Widget _statusPill(OrderModel order) {
    if (order.isActive && order.arrivedAt == null) return ArrivalStatusPill(order: order, isLawyer: widget.isLawyer);
    final isLawyer = widget.isLawyer;
    return StatusPill(
      icon: orderStatusIcon(order, isLawyer: isLawyer),
      color: orderToneColor(orderTone(order, isLawyer: isLawyer)),
      text: (isLawyer ? order.lawyerStatusLabel : null) ?? order.statusLabel,
    );
  }

  Widget _buildNumberCard(OrderModel order) =>
      OrderNumberCard(number: order.orderNumber, time: DateTime.tryParse(order.createdAt)?.toLocal(), onCopy: _copyOrderNumber);

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
      if (order.field != null) ...[
        _infoRow('الطلب لـ', order.field!.personLine),
        _infoRow('المكان', order.field!.placeName),
        if (order.field!.detained) _infoRow('الحالة', 'محبوس أو محتجز', valueColor: AppColors.danger),
        if (order.arrivedAt != null) _infoRow('إثبات الوصول', _arrivalWay(order.field!.arrivalMethod)),
      ] else if (order.clientAddress != null)
        _infoRow('المنطقة', order.clientAddress!),
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

    return DetailsCard(rows: rows);
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

  Widget _infoRow(String label, String value, {Color? valueColor, VoidCallback? onTap}) =>
      DetailRow(label, value, valueColor: valueColor, onTap: onTap);

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
      if (order.canConfirmArrival) ...[
        _statusNote(
          order.field?.forOther == true
              ? 'المحامي بيقول إنه وصل\nلو هو قدام الشخص دلوقتي أكّد وصوله'
              : 'المحامي بيقول إنه وصل\nلو هو معاك دلوقتي أكّد وصوله',
        ),
        _primaryAction('أيوه، المحامي وصل', _confirmArrival),
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
        _action(order.field != null ? 'افتح المكان في Google Maps' : 'افتح مكان الموكل في Google Maps', _openDirections, icon: Icons.navigation_rounded),
        if (!order.hasOpenComplaint) ...[
          // Finishing stays hidden until the lawyer arrives within 50 meters of the client
          if (order.isPostponed) PostponedSince(since: order.postponedAt!, note: 'وأتعابها محجوزة لحد ما تنهيها'),
          if (order.arrivedAt == null) ...[
            _primaryAction('وصلت', _markArrived),
            if (order.field?.canTypeCode == true) _action('اكتب كود الشخص', _openCodeEntry, icon: Icons.pin_rounded),
            _action(order.field?.forOther == true ? 'الموكل يأكد وصولي (للشخص)' : 'الموكل يأكد وصولي', _askArrival),
          ] else ...[
            _primaryAction('إنهاء المهمة', _openCompletion),
            // المؤجلة بتتنهي على طول، ومفيش «إلغاء التأجيل»
            if (!order.isPostponed) _action('مؤجل', _openPostpone),
            if (order.field?.forOther == true) _action('الشخص رفض', _personRefused, isDanger: true),
          ],
          if (order.field?.canAddProof == true)
            _action(order.field!.proofs == 0 ? 'صورة إثبات للإدارة' : 'صورة إثبات (${order.field!.proofs})', _addProof, icon: Icons.photo_camera_rounded),
          _action('اعتذار', _withdraw, isDanger: true),
        ],
      ],
      ..._problemAction(order),
    ];
  }

  static String _arrivalWay(String? method) {
    switch (method) {
      case 'code':
        return 'كود الشخص';
      case 'client':
        return 'تأكيد الموكل';
      default:
        return 'منطقة المكان';
    }
  }
}

/// سبب التأجيل اللي بيوصل للموكل
