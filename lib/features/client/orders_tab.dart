import 'dart:async';
import '../../core/widgets/app_pressable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/order_action_sheets.dart';
import '../urgent_service/payment_screen.dart';
import '../../core/widgets/app_state_message.dart';
import '../../core/widgets/order_status_tracker.dart';
import '../../core/widgets/response_countdown.dart';
import '../../data/models/order_model.dart';
import '../../data/repositories/order_repository.dart';

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
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
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

  Future<void> _openComplaint(OrderModel order) async {
    final sent = await OrderActionSheets.text(
      context,
      title: 'شكوى على الطلب',
      subtitle: 'اكتب اللي حصل والإدارة هتراجعه',
      hint: 'تفاصيل الشكوى',
      buttonText: 'إرسال الشكوى',
      onSubmit: (reason) => OrderRepository.submitComplaint(order.id, reason),
    );
    if (!sent || !mounted) return;
    _showNotice('تم استلام شكواك');
    await _loadOrders();
  }

  Future<void> _openReview(OrderModel order) async {
    final sent = await OrderActionSheets.review(
      context,
      lawyerName: order.lawyerName ?? 'المحامي',
      onSubmit: (rating, comment) => OrderRepository.submitReview(order.id, rating, comment),
    );
    if (!sent || !mounted) return;
    _showNotice('شكراً لتقييمك');
    await _loadOrders();
  }

  Future<void> _openReviewEdit(OrderModel order) async {
    final sent = await OrderActionSheets.review(
      context,
      lawyerName: order.lawyerName ?? 'المحامي',
      onSubmit: (rating, comment) => OrderRepository.updateReview(order.id, rating, comment),
    );
    if (sent && mounted) await _loadOrders();
  }

  /// دفع طلب وافق عليه المحامي، والطلب يبقى غير مكتمل لحد الدفع
  Future<void> _openPayment(OrderModel order) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PaymentScreen(
          orderId: order.id,
          orderNumber: order.orderNumber,
          locationName: order.clientAddress ?? '',
          problemTitle: order.problemType ?? order.serviceTitle,
          problemDescription: order.problemDescription,
          price: order.price.round(),
        ),
      ),
    );
    if (mounted) await _loadOrders();
  }

  Future<void> _confirmCancel(OrderModel order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'إلغاء الطلب',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'المبلغ هيرجع لرصيدك',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('تراجع')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('إلغاء الطلب')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final res = await OrderRepository.cancelOrder(order.id);
    if (!mounted) return;
    _showNotice(res.isOk ? 'تم إلغاء الطلب ورجوع المبلغ لرصيدك' : (res.error ?? 'تعذر إلغاء الطلب'));
    await _loadOrders();
  }

  /// الكود إجباري لإنهاء المهمة ويظهر للموكل فقط
  Widget _buildCompletionCode(String code) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'كود إنهاء المهمة',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'AppFont',
            fontFamilyFallback: appFontFallback,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.dark,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          code,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'AppFont',
            fontFamilyFallback: appFontFallback,
            fontSize: 30,
            letterSpacing: 8,
            fontWeight: FontWeight.w900,
            color: AppColors.primary,
          ),
        ),
        const Text(
          'ادّيه للمحامي بعد تنفيذ المهمة',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'AppFont',
            fontFamilyFallback: appFontFallback,
            fontSize: 12,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  /// إجراءات الطلب المكتمل: التقييم والشكوى خلال مدتهما
  Widget _buildPastOrderActions(OrderModel order) {
    if (order.hasOpenComplaint) {
      return const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Text(
          'شكواك قيد المراجعة',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'AppFont',
            fontFamilyFallback: appFontFallback,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.danger,
          ),
        ),
      );
    }

    if (!order.isCompleted || (!order.canReview && !order.canComplain && !order.canEditReview)) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          if (order.canReview) ...[
            Expanded(
              child: AppButton.primary(text: 'قيّم المحامي', height: 38, fontSize: 12, onPressed: () {
                  _openReview(order);
                }),
            ),
            const SizedBox(width: 8),
          ],
          if (order.canEditReview) ...[
            Expanded(
              child: AppButton.outlined(
                text: 'تعديل التقييم',
                height: 38,
                fontSize: 12,
                onPressed: () {
                  _openReviewEdit(order);
                },
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: AppButton.outlined(
              text: 'عندك مشكلة؟',
              height: 38,
              fontSize: 12,
              textColor: AppColors.danger,
              borderColor: AppColors.danger.withOpacity(0.35),
              onPressed: () {
                _openComplaint(order);
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showContactBottomSheet(OrderModel order) {
    final lawyerName = order.lawyerName ?? 'المحامي';
    final lawyerPhone = order.lawyerPhone ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.cardBorder,
                      borderRadius: BorderRadius.circular(4.0),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(7.0),
                      ),
                      child: const Icon(Icons.phone_in_talk_rounded, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'التواصل المباشر مع $lawyerName',
                            style: const TextStyle(
                              fontFamily: 'AppFont',
                              fontFamilyFallback: appFontFallback,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.dark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            lawyerPhone.isNotEmpty ? lawyerPhone : 'متاح للاتصال الفوري طوال فترة تنفيذ الخدمة',
                            style: const TextStyle(
                              fontFamily: 'AppFont',
                              fontFamilyFallback: appFontFallback,
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                AppPressable(
                  child: ElevatedButton.icon(
                    onPressed: lawyerPhone.isEmpty
                        ? null
                        : () {
                            Clipboard.setData(ClipboardData(text: lawyerPhone));
                            Navigator.pop(sheetContext);
                            _showNotice('تم نسخ رقم المحامي، يمكنك الاتصال به الآن.');
                          },
                    icon: const Icon(Icons.call_rounded, color: Colors.white, size: 18),
                    label: const Text(
                      'نسخ رقم المحامي',
                      style: TextStyle(
                        fontFamily: 'AppFont',
                        fontFamilyFallback: appFontFallback,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24.0),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                AppPressable(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _showNotice('المحادثة الكتابية ستتوفر قريباً.');
                    },
                    icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primary, size: 18),
                    label: const Text(
                      'محادثة كتابية فورية',
                      style: TextStyle(
                        fontFamily: 'AppFont',
                        fontFamilyFallback: appFontFallback,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primary, width: 1.2),
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24.0),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
            for (final order in activeOrders) ...[
              _buildActiveOrderCard(order),
              const SizedBox(height: 20),
            ],
            for (final order in pastOrders) ...[
              _buildPastOrderCard(order),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActiveOrderCard(OrderModel order) {
    final lawyerName = order.lawyerName ?? 'المحامي';

    return AppCard(
      key: ValueKey(order.id),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // مهلة رد المحامي
          if (order.isPending) ...[
            ResponseCountdown(secondsLeft: order.responseSecondsLeft),
            const SizedBox(height: 12),
          ],

          // تاريخ وساعة الطلب الفعلي
          Text(
            order.formattedDate,
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontFamily: 'AppFont',
              fontFamilyFallback: appFontFallback,
              fontSize: 11,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),

          // بيانات المحامي المكلف
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(7.0),
                child: order.lawyerAvatarUrl.isNotEmpty
                    ? Image.network(
                        order.lawyerAvatarUrl,
                        width: 52,
                        height: 52,
                        cacheWidth: 104,
                        cacheHeight: 104,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildAvatarFallback(),
                      )
                    : _buildAvatarFallback(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            lawyerName,
                            style: const TextStyle(
                              fontFamily: 'AppFont',
                              fontFamilyFallback: appFontFallback,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: AppColors.dark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 16),
                      ],
                    ),
                    if (order.lawyerSpecialty != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        order.lawyerSpecialty!,
                        style: const TextStyle(
                          fontFamily: 'AppFont',
                          fontFamilyFallback: appFontFallback,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // تفاصيل الوضع والشكوى والموقع بحافة رفيعة متقطعة وظل خفيف
          CustomPaint(
            foregroundPainter: const DashedRRectPainter(
              color: AppColors.dashedBorder,
              strokeWidth: 0.9,
              dash: 5.0,
              gap: 3.5,
              borderRadius: 7.0,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(7.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 6.0,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildInfoLine(
                    icon: Icons.shield_rounded,
                    label: 'نوع الطلب / المشكلة:',
                    value: order.problemType ?? order.serviceTitle,
                  ),
                  if (order.problemDescription.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _buildInfoLine(
                      icon: Icons.notes_rounded,
                      label: 'تفاصيل المشكلة:',
                      value: order.problemDescription,
                    ),
                  ],
                  if (order.clientAddress != null) ...[
                    const SizedBox(height: 6),
                    _buildInfoLine(
                      icon: Icons.location_on_rounded,
                      label: 'المنطقة:',
                      value: order.clientAddress!,
                      maxLines: 3,
                    ),
                  ],
                  const SizedBox(height: 6),
                  _buildInfoLine(
                    icon: Icons.receipt_rounded,
                    label: 'رقم المعاملة:',
                    value: order.orderNumber,
                  ),
                  const SizedBox(height: 6),
                  _buildInfoLine(
                    icon: Icons.payments_rounded,
                    label: order.isPaid ? 'الأتعاب المسددة:' : 'الأتعاب المستحقة:',
                    value: order.isPaid ? '${order.priceText} ج.م (مدفوعة)' : '${order.priceText} ج.م',
                    valueColor: order.isPaid ? AppColors.success : null,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          if (order.isActive && order.completionCode != null) ...[
            _buildCompletionCode(order.completionCode!),
            const SizedBox(height: 14),
          ],

          if (order.isAccepted) ...[
            Text(
              'طلب غير مكتمل • باقي ${order.paymentMinutesLeft} دقيقة للدفع',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'AppFont',
                fontFamilyFallback: appFontFallback,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.danger,
              ),
            ),
            const SizedBox(height: 10),
            AppButton.primary(
              text: 'ادفع ${order.priceText} ج.م',
              height: 42,
              fontSize: 13,
              onPressed: () {
                _openPayment(order);
              },
            ),
          ],

          // أزرار المهمة جنب بعض، والرقم يظهر بعد الدفع فقط
          if (order.isActive) Row(
            children: [
              Expanded(
                child: AppButton.primary(
                  text: 'تواصل',
                  height: 40,
                  fontSize: 12,
                  onPressed: () => _showContactBottomSheet(order),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton.outlined(
                  text: 'شكوى',
                  height: 40,
                  fontSize: 12,
                  textColor: AppColors.danger,
                  borderColor: AppColors.danger.withOpacity(0.35),
                  onPressed: order.canComplain
                      ? () {
                          _openComplaint(order);
                        }
                      : null,
                ),
              ),
              if (order.canCancelAfterPayment) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: AppButton.outlined(
                    text: 'إلغاء الطلب',
                    height: 40,
                    fontSize: 12,
                    textColor: AppColors.danger,
                    borderColor: AppColors.danger.withOpacity(0.35),
                    onPressed: () {
                      _confirmCancel(order);
                    },
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          OrderStatusTracker(order: order),
        ],
      ),
    );
  }

  Widget _buildAvatarFallback() {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(7.0),
      ),
      child: const Icon(Icons.person_rounded, color: AppColors.primary, size: 28),
    );
  }

  Widget _buildPastOrderCard(OrderModel order) {
    return AppCard(
      key: ValueKey(order.id),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            order.formattedDate,
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontFamily: 'AppFont',
              fontFamilyFallback: appFontFallback,
              fontSize: 11,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            order.problemType ?? order.serviceTitle,
            style: const TextStyle(
              fontFamily: 'AppFont',
              fontFamilyFallback: appFontFallback,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.dark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'المحامي: ${order.lawyerName ?? '-'} • الأتعاب: ${order.priceText} ج.م',
            style: const TextStyle(
              fontFamily: 'AppFont',
              fontFamilyFallback: appFontFallback,
              fontSize: 11,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 14),
          OrderStatusTracker(order: order),
          _buildPastOrderActions(order),
        ],
      ),
    );
  }

  Widget _buildInfoLine({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    int maxLines = 1,
  }) {
    return Row(
      crossAxisAlignment: maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 15, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'AppFont',
            fontFamilyFallback: appFontFallback,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontFamily: 'AppFont',
              fontFamilyFallback: appFontFallback,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: valueColor ?? AppColors.dark,
            ),
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
