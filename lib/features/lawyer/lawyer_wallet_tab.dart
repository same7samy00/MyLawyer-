import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/services/live_updates.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/app_message.dart';
import '../../core/widgets/app_pressable.dart';
import '../../core/widgets/app_state_message.dart';
import '../../core/widgets/order_action_sheets.dart';
import '../../data/models/lifecycle_models.dart';
import '../../data/models/order_model.dart';
import '../../data/repositories/order_repository.dart';

/// تبويب المحفظة القانونية للمحامي
/// يطابق تصميم محفظة الموكل مع تخصيص البيانات للأتعاب المحصلة وطلبات السحب
class LawyerWalletTab extends StatefulWidget {
  /// إشارة من الحاوية لتحديث الأرقام عند العودة لهذا التبويب
  final ValueListenable<int>? refreshSignal;

  const LawyerWalletTab({super.key, this.refreshSignal});

  @override
  State<LawyerWalletTab> createState() => _LawyerWalletTabState();
}

class _LawyerWalletTabState extends State<LawyerWalletTab> {
  bool _isLoading = OrderRepository.peekWallet() == null;
  bool _isFetching = false;
  String? _errorMessage;
  List<OrderModel> _completedOrders = OrderRepository.peekOrders().where((order) => order.isCompleted).toList();

  LawyerWallet _wallet = OrderRepository.peekWallet() != null
      ? LawyerWallet.fromJson(OrderRepository.peekWallet()!)
      : const LawyerWallet(available: 0, held: 0, frozen: 0);

  @override
  void initState() {
    super.initState();
    widget.refreshSignal?.addListener(_loadFees);
    LiveUpdates.orders.addListener(_loadFees);
    ApiService.isServerReachable.addListener(_onReachabilityChanged);
    _showSaved();
    _loadFees();
  }

  Future<void> _showSaved() async {
    final results = await Future.wait([OrderRepository.savedWallet(), OrderRepository.savedOrders()]);
    final wallet = results[0] as Map<String, dynamic>?;
    if (!mounted || wallet == null || !_isLoading) return;
    setState(() {
      _wallet = LawyerWallet.fromJson(wallet);
      _completedOrders = (results[1] as List<OrderModel>).where((order) => order.isCompleted).toList();
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    widget.refreshSignal?.removeListener(_loadFees);
    LiveUpdates.orders.removeListener(_loadFees);
    ApiService.isServerReachable.removeListener(_onReachabilityChanged);
    super.dispose();
  }

  void _onReachabilityChanged() {
    if (ApiService.isServerReachable.value && _errorMessage != null) {
      _loadFees();
    }
  }

  Future<void> _openTransfer() async {
    final sent = await OrderActionSheets.transfer(
      context,
      findRecipient: OrderRepository.findTransferRecipient,
      onSubmit: OrderRepository.transfer,
    );
    if (!sent || !mounted) return;
    showAppMessage(context, 
      const SnackBar(content: Text('تم التحويل'), backgroundColor: AppColors.success),
    );
    await _loadFees();
  }

  Future<void> _loadFees() async {
    if (_isFetching) return;
    _isFetching = true;

    final results = await Future.wait([
      OrderRepository.getOrders(status: 'COMPLETED'),
      OrderRepository.getLawyerWallet(),
    ]);
    final res = results[0] as ApiResponse<List<OrderModel>>;
    final walletRes = results[1] as ApiResponse<LawyerWallet>;
    _isFetching = false;
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (res.isOk && walletRes.isOk) {
        _completedOrders = res.data ?? const [];
        _wallet = walletRes.data ?? _wallet;
        _errorMessage = null;
      } else {
        _errorMessage = res.error ?? walletRes.error ?? 'تعذر تحميل بيانات المحفظة، يرجى المحاولة مرة أخرى';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: AppLoader());
    }

    // لا تعرض أرقام مالية قديمة كأنها حالية
    if (_errorMessage != null) {
      return SafeArea(
        child: AppStateMessage(
          icon: Icons.wifi_off_rounded,
          title: 'تعذر تحميل بيانات المحفظة',
          message: _errorMessage,
          onRetry: _loadFees,
        ),
      );
    }

    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. بطاقة الرصيد المتاح للسحب (مطابقة لبطاقة محفظة الموكل)
            AppCard(
              padding: const EdgeInsets.all(20),
              backgroundColor: AppColors.dark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'الرصيد المتاح للسحب',
                    style: TextStyle(
                      fontFamily: 'AppFont',
                      fontFamilyFallback: appFontFallback,
                      fontSize: 13,
                      color: AppColors.cardBorder,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        _wallet.available.toStringAsFixed(2),
                        style: const TextStyle(
                          fontFamily: 'AppFont',
                          fontFamilyFallback: appFontFallback,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'جنيه مصري',
                        style: TextStyle(
                          fontFamily: 'AppFont',
                          fontFamilyFallback: appFontFallback,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryLight,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'بعد خصم رسوم خدمة المنصة • الحد الأدنى للسحب 100 ج.م',
                    style: TextStyle(
                      fontFamily: 'AppFont',
                      fontFamilyFallback: appFontFallback,
                      fontSize: 11,
                      color: AppColors.cardBorder,
                    ),
                  ),
                  const SizedBox(height: 18),
                  AppPressable(
                    child: ElevatedButton.icon(
                    onPressed: () {
                      showAppMessage(context, 
                        const SnackBar(
                          content: Text('خدمة سحب الأتعاب للحساب البنكي أو المحفظة الإلكترونية ستتوفر قريباً'),
                          backgroundColor: AppColors.dark,
                        ),
                      );
                    },
                    icon: const Icon(Icons.account_balance_wallet_rounded, size: 18, color: Colors.white),
                    label: const Text(
                      'طلب سحب الأتعاب',
                      style: TextStyle(
                        fontFamily: 'AppFont',
                        fontFamilyFallback: appFontFallback,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.0)),
                    ),
                  ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            AppButton.outlined(
              text: 'تحويل لحساب تاني',
              icon: Icons.send_rounded,
              onPressed: _openTransfer,
            ),

            const SizedBox(height: 16),

            // 2. إحصائيات سريعة للأتعاب
            Row(
              children: [
                Expanded(
                  child: AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'أتعاب معلقة 24 ساعة',
                          style: TextStyle(
                            fontFamily: 'AppFont',
                            fontFamilyFallback: appFontFallback,
                            fontSize: 11,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_wallet.held.toStringAsFixed(0)} ج.م',
                          style: TextStyle(
                            fontFamily: 'AppFont',
                            fontFamilyFallback: appFontFallback,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'متوقفة بسبب شكوى',
                          style: TextStyle(
                            fontFamily: 'AppFont',
                            fontFamilyFallback: appFontFallback,
                            fontSize: 11,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_wallet.frozen.toStringAsFixed(0)} ج.م',
                          style: const TextStyle(
                            fontFamily: 'AppFont',
                            fontFamilyFallback: appFontFallback,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 22),

            // 3. سجل العمليات الأخيرة
            const Text(
              'سجل المعاملات والأتعاب الأخيرة',
              style: TextStyle(
                fontFamily: 'AppFont',
                fontFamilyFallback: appFontFallback,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.dark,
              ),
            ),
            const SizedBox(height: 10),

            if (_completedOrders.isEmpty)
              const AppStateMessage(
                icon: Icons.account_balance_wallet_rounded,
                title: 'لا توجد معاملات حتى الآن',
                message: 'هتظهر هنا أتعاب الطلبات فور إتمامها',
              ),
            for (final order in _completedOrders) ...[
              _buildTransactionTile(
                title: order.problemType ?? order.serviceTitle,
                subtitle: 'المعاملة: ${order.orderNumber} • ${order.formattedDate}',
                amount: '+${order.priceText} ج.م',
                isCredit: true,
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionTile({
    required String title,
    required String subtitle,
    required String amount,
    required bool isCredit,
  }) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isCredit ? AppColors.success.withOpacity(0.1) : AppColors.danger.withOpacity(0.1),
              borderRadius: BorderRadius.circular(7.0),
            ),
            child: Icon(
              isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              color: isCredit ? AppColors.success : AppColors.danger,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'AppFont',
                    fontFamilyFallback: appFontFallback,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.dark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
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
          Text(
            amount,
            style: TextStyle(
              fontFamily: 'AppFont',
              fontFamilyFallback: appFontFallback,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: isCredit ? AppColors.success : AppColors.dark,
            ),
          ),
        ],
      ),
    );
  }
}

