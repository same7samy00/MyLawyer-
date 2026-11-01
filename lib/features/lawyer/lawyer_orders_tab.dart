import 'dart:async';
import '../../core/widgets/app_pressable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/services/external_navigation.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/services/location_service.dart';
import '../../core/widgets/order_action_sheets.dart';
import '../../core/widgets/app_state_message.dart';
import '../../core/widgets/order_status_tracker.dart';
import '../../core/widgets/response_countdown.dart';
import '../../data/models/order_model.dart';
import '../../data/repositories/order_repository.dart';
import '../urgent_service/tracking_screen.dart';

/// صفحة طلبات المحامي المستقلة
/// مطابقة لصفحة طلبات الموكل في التصميم والترتيب مع استبدال الأزرار بـ «فتح الطلب» و «اعتذار»
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
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    widget.refreshSignal?.addListener(_loadOrders);
    ApiService.isServerReachable.addListener(_onReachabilityChanged);
    _loadOrders();
    // الطلب الجديد وانتهاء مهلته يظهران من غير سحب الصفحة
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) => _loadOrders());
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
        _errorMessage = res.error ?? 'تعذر تحميل الطلبات، يرجى المحاولة مرة أخرى.';
      }
    });
  }

  /// فتح تفاصيل الطلب على خريطة محاميك حالاً
  Future<void> _openOrderOnMap(OrderModel order) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TrackingScreen(
          isLawyerView: true,
          lawyerOrder: order,
        ),
      ),
    );
    _loadOrders();
  }

  /// نافذة تأكيد الاعتذار عن الطلب
  void _showDeclineModal(OrderModel order) {
    final messenger = ScaffoldMessenger.of(context);

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
                      borderRadius: BorderRadius.circular(2.0),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'الاعتذار عن قبول الطلب',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'AppFont',
                    fontFamilyFallback: appFontFallback,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.dark,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'هل ترغب في الاعتذار عن هذا الطلب؟ سيتم إتاحته لمحامٍ آخر متاح في نفس النطاق الجغرافي فوراً.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'AppFont',
                    fontFamilyFallback: appFontFallback,
                    fontSize: 13,
                    color: AppColors.textMuted,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                AppButton(
                  text: 'تأكيد الاعتذار عن الطلب',
                  backgroundColor: AppColors.danger,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  onPressed: () async {
                    final navigator = Navigator.of(sheetContext);
                    final res = await OrderRepository.rejectOrder(order.id);
                    if (navigator.mounted) navigator.pop();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          res.isOk
                              ? 'تم الاعتذار عن الطلب بنجاح وإعادة توجيهه للشبكة.'
                              : (res.error ?? 'تعذر الاعتذار عن الطلب، يرجى المحاولة مرة أخرى.'),
                          style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback),
                        ),
                        backgroundColor: AppColors.dark,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7.0)),
                      ),
                    );
                    await _loadOrders();
                  },
                ),
                const SizedBox(height: 10),
                AppPressable(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.cardBorder),
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.0)),
                    ),
                    child: const Text(
                      'تراجع',
                      style: TextStyle(
                        fontFamily: 'AppFont',
                        fontFamilyFallback: appFontFallback,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.dark,
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
              title: 'تعذر تحميل الطلبات',
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
                message: 'هتظهر الطلبات الواردة إليك هنا فور إرسالها من الموكلين.',
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

  void _showResult(ApiResponse<dynamic> res, String success) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(res.isOk ? (res.message ?? success) : (res.error ?? 'تعذر تنفيذ العملية'))),
    );
  }

  Future<void> _markArrived(OrderModel order) async {
    final location = await LocationService.instance.checkAndRequestPermission();
    final position = location.position;
    if (!mounted) return;

    if (position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فعّل الموقع عشان نسجل وصولك')),
      );
      return;
    }

    final res = await OrderRepository.markArrived(order.id, position.latitude, position.longitude);
    if (!mounted) return;
    _showResult(res, 'تم تسجيل وصولك');
    await _loadOrders();
  }

  Future<void> _confirmWithdraw(OrderModel order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'الاعتذار عن المهمة',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'المبلغ هيرجع للموكل وهتتسجل عليك نقطة',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('تراجع')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('اعتذار')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final res = await OrderRepository.withdrawFromOrder(order.id);
    if (!mounted) return;
    _showResult(res, 'تم تسجيل الاعتذار');
    await _loadOrders();
  }

  Future<void> _openReport(OrderModel order) async {
    final sent = await OrderActionSheets.text(
      context,
      title: 'بلاغ عن مشكلة',
      subtitle: 'اكتب اللي حصل والإدارة هتراجعه',
      hint: 'تفاصيل البلاغ',
      buttonText: 'إرسال البلاغ',
      onSubmit: (reason) => OrderRepository.reportClient(order.id, reason),
    );
    if (sent && mounted) await _loadOrders();
  }

  /// إجراءات المهمة بعد الدفع: الوصول والإنهاء بالكود والاعتذار والبلاغ
  Widget _buildMissionActions(OrderModel order) {
    if (order.hasOpenComplaint) {
      return const Padding(
        padding: EdgeInsets.only(top: 10),
        child: Text(
          'قيد مراجعة شكوى',
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

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppButton.outlined(
            text: 'افتح مكان الموكل في Google Maps',
            icon: Icons.navigation_rounded,
            height: 40,
            fontSize: 12,
            onPressed: () {
              ExternalNavigation.openDirections(order.clientLat, order.clientLon);
            },
          ),
          const SizedBox(height: 8),
          if (order.isCodeLocked)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'الكود مقفول، الإدارة هتراجع الطلب',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'AppFont',
                  fontFamilyFallback: appFontFallback,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.danger,
                ),
              ),
            ),
          Row(
            children: [
              if (order.arrivedAt == null)
                Expanded(
                  child: AppButton.outlined(
                    text: 'وصلت',
                    height: 40,
                    fontSize: 12,
                    onPressed: () => _markArrived(order),
                  ),
                )
              else if (!order.isCodeLocked)
                Expanded(
                  child: AppButton.primary(
                    text: 'إنهاء المهمة',
                    height: 40,
                    fontSize: 12,
                    onPressed: () {
                      _openCompletion(order);
                    },
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: AppButton.outlined(
                  text: 'اعتذار',
                  height: 40,
                  fontSize: 12,
                  textColor: AppColors.danger,
                  borderColor: AppColors.danger.withOpacity(0.35),
                  onPressed: () {
                    _confirmWithdraw(order);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton.outlined(
                  text: 'بلاغ عن مشكلة',
                  height: 40,
                  fontSize: 12,
                  onPressed: () {
                    _openReport(order);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openCompletion(OrderModel order) async {
    final finished = await OrderActionSheets.completion(
      context,
      onSubmit: (code) => OrderRepository.completeOrder(order.id, code),
    );
    if (!finished || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم إنهاء المهمة، والصافي هيتاح بعد 24 ساعة')),
    );
    await _loadOrders();
  }

  Future<void> _openAppeal(OrderModel order) async {
    final sent = await OrderActionSheets.text(
      context,
      title: 'اعتراض على انتهاء المهلة',
      subtitle: 'اكتب اللي حصل والإدارة هتراجعه',
      hint: 'تفاصيل الاعتراض',
      buttonText: 'إرسال الاعتراض',
      onSubmit: (reason) => OrderRepository.submitAppeal(order.id, reason),
    );
    if (!sent || !mounted) return;
    await _loadOrders();
  }

  Widget _buildActiveOrderCard(OrderModel order) {
    final clientName = order.clientName ?? 'الموكل';
    final problemTitle = order.problemType ?? order.serviceTitle;

    return AppCard(
      key: ValueKey(order.id),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // مهلة الرد على الطلب الجديد
          if (order.isPending) ...[
            ResponseCountdown(secondsLeft: order.responseSecondsLeft),
            const SizedBox(height: 12),
          ],

          // توقيت الطلب
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

          // بيانات الموكل صاحب الطلب
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(7.0),
                  border: Border.all(color: AppColors.primary.withOpacity(0.15)),
                ),
                child: const Icon(Icons.person_rounded, color: AppColors.primary, size: 28),
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
                            'الموكل: $clientName',
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
                    const SizedBox(height: 2),
                    Text(
                      problemTitle,
                      style: const TextStyle(
                        fontFamily: 'AppFont',
                        fontFamilyFallback: appFontFallback,
                        fontSize: 12,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // جدول بيانات وتفاصيل الطلب والنطاق والأتعاب بحافة متقطعة وظل خفيف
          CustomPaint(
            foregroundPainter: const DashedRRectPainter(
              color: AppColors.dashedBorder,
              strokeWidth: 0.9,
              dash: 5.0,
              gap: 3.5,
              borderRadius: 7.0,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                  _buildDetailRow(
                    label: 'رقم المعاملة:',
                    value: order.orderNumber,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 7.0),
                    child: Divider(height: 1, color: AppColors.cardBorder),
                  ),
                  _buildDetailRow(
                    label: 'منطقة الموكل:',
                    value: order.clientAddress ?? '-',
                    maxLines: 3,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 7.0),
                    child: Divider(height: 1, color: AppColors.cardBorder),
                  ),
                  _buildDetailRow(
                    label: 'نوع المشكلة:',
                    value: problemTitle,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 7.0),
                    child: Divider(height: 1, color: AppColors.cardBorder),
                  ),
                  if (order.clientPhone != null && order.clientPhone!.isNotEmpty) ...[
                    _buildDetailRow(
                      label: 'رقم الموكل:',
                      value: order.clientPhone!,
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 7.0),
                      child: Divider(height: 1, color: AppColors.cardBorder),
                    ),
                  ],
                  _buildDetailRow(
                    label: 'صافي أتعابك:',
                    value: '${order.priceText} ج.م',
                    valueColor: AppColors.success,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // أزرار الإجراءات الخاصة بالمحامي: «فتح الطلب» أساسي و «اعتذار» ثانوي
          Row(
            children: [
              Expanded(
                flex: 6,
                child: AppPressable(
                  child: ElevatedButton.icon(
                    onPressed: () => _openOrderOnMap(order),
                    icon: const Icon(Icons.map_rounded, color: Colors.white, size: 17),
                    label: const Text(
                      'فتح الطلب',
                      style: TextStyle(
                        fontFamily: 'AppFont',
                        fontFamilyFallback: appFontFallback,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size(double.infinity, 42),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24.0),
                      ),
                    ),
                  ),
                ),
              ),
              if (order.isPending) ...[
                const SizedBox(width: 10),
                Expanded(
                  flex: 4,
                  child: AppPressable(
                    child: OutlinedButton.icon(
                      onPressed: () => _showDeclineModal(order),
                      icon: const Icon(Icons.cancel_outlined, color: AppColors.danger, size: 17),
                      label: const Text(
                        'اعتذار',
                        style: TextStyle(
                          fontFamily: 'AppFont',
                          fontFamilyFallback: appFontFallback,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.danger,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.danger.withOpacity(0.35), width: 1.2),
                        minimumSize: const Size(double.infinity, 42),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24.0),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (order.isActive) _buildMissionActions(order),
          const SizedBox(height: 16),
          OrderStatusTracker(order: order, statusText: _statusTextFor(order)),
        ],
      ),
    );
  }

  /// نص الحالة من ناحية المحامي لما يختلف عن نص الموكل
  String? _statusTextFor(OrderModel order) {
    if (order.isPending) return 'طلب جديد';
    if (order.isAccepted) return 'تم قبول الطلب • بانتظار دفع الموكل';
    if (order.isNoResponse) return 'انتهى وقت الرد';
    return null;
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
            'الموكل: ${order.clientName ?? '-'} • الأتعاب: ${order.priceText} ج.م',
            style: const TextStyle(
              fontFamily: 'AppFont',
              fontFamilyFallback: appFontFallback,
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 14),
          OrderStatusTracker(order: order, statusText: _statusTextFor(order)),
          if (order.canAppeal) ...[
            const SizedBox(height: 12),
            AppButton.outlined(
              text: 'اعتراض',
              height: 38,
              fontSize: 12,
              onPressed: () {
                _openAppeal(order);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required String label,
    required String value,
    Color? valueColor,
    int maxLines = 1,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'AppFont',
            fontFamilyFallback: appFontFallback,
            fontSize: 12,
            color: AppColors.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'AppFont',
              fontFamilyFallback: appFontFallback,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: valueColor ?? AppColors.dark,
            ),
          ),
        ),
      ],
    );
  }
}
