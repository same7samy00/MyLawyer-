import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_pressable.dart';
import '../../core/services/routing_service.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_header.dart';
import '../../core/widgets/edge_lines_illustration.dart';
import '../../data/models/map_lawyer.dart';
import '../../data/repositories/order_repository.dart';
import 'payment_success_screen.dart';

class PaymentScreen extends StatefulWidget {
  final MapLawyer? lawyer;
  final String? problemTitle;
  final String? problemDescription;
  final String locationName;
  final RouteEstimate? routeEstimate;
  final int price;
  final String? orderId;
  final String? orderNumber;

  const PaymentScreen({
    super.key,
    this.lawyer,
    this.problemTitle,
    this.problemDescription,
    required this.locationName,
    this.routeEstimate,
    this.price = 350,
    this.orderId,
    this.orderNumber,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  int _selectedPaymentMethod = 0; // 0: Vodafone Cash / Wallets, 1: Credit Card, 2: My Lawyer Wallet
  bool _isProcessing = false;

  String get _orderRef => widget.orderNumber ?? '';

  double? _balance;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    final res = await OrderRepository.getClientBalance();
    if (mounted && res.isOk) setState(() => _balance = res.data);
  }

  Future<void> _processPayment() async {
    final orderId = widget.orderId;
    if (orderId == null) {
      _showError('تعذر العثور على الطلب، يرجى العودة وإعادة المحاولة.');
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    final res = await OrderRepository.confirmPayment(orderId, fromBalance: _selectedPaymentMethod == 2);

    if (!mounted) return;

    if (!res.isOk) {
      setState(() {
        _isProcessing = false;
      });
      _showError(res.error ?? 'تعذر تأكيد السداد، يرجى المحاولة مرة أخرى.');
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => PaymentSuccessScreen(
          lawyer: widget.lawyer,
          problemTitle: widget.problemTitle,
          problemDescription: widget.problemDescription,
          price: widget.price,
          orderRef: _orderRef,
          locationName: widget.locationName,
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback)),
        backgroundColor: AppColors.dark,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isProcessing,
      child: Scaffold(
      backgroundColor: Colors.white,
      appBar: const AppHeader(
        title: 'تفاصيل سداد الأتعاب',
        isInnerPage: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // رسمة الدفع في الأعلى
                    const EdgeLinesIllustration(
                      asset: 'assets/images/credit_card_rafiki.svg',
                      height: 150,
                      bleed: 18,
                    ),
                    const SizedBox(height: 16),

                    const Center(
                      child: Text(
                        'سداد الأتعاب',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'AppFont',
                          fontFamilyFallback: appFontFallback,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: AppColors.dark,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Center(
                      child: Text(
                        'راجع الفاتورة واختر وسيلة السداد',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'AppFont',
                          fontFamilyFallback: appFontFallback,
                          fontSize: 12,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // جدول تفاصيل العملية المنسق
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(7.0),
                        border: Border.all(color: AppColors.cardBorder),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(7.0),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              color: Colors.white,
                              child: Row(
                                children: [
                                  const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 18),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'فاتورة الخدمة',
                                    style: TextStyle(
                                      fontFamily: 'AppFont',
                                      fontFamilyFallback: appFontFallback,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    _orderRef,
                                    style: const TextStyle(
                                      fontFamily: 'Nunito',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1, thickness: 1, color: AppColors.cardBorder),
                            _buildTableRow('نوع الخدمة', widget.problemTitle ?? 'محاميك حالاً'),
                            if (widget.problemDescription != null && widget.problemDescription!.isNotEmpty)
                              _buildTableRow('تفاصيل المشكلة', widget.problemDescription!),
                            _buildTableRow('المحامي المعتمد', widget.lawyer?.name ?? '-'),
                            _buildTableRow('نطاق التواجد', widget.locationName),
                            _buildTableRow('قيمة أتعاب الخدمة', '${widget.price} ج.م'),
                            _buildTableRow('ضريبة ورسوم المنصة', '0.00 ج.م (معفاة)'),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              color: Colors.white,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'الإجمالي النهائي المستحق:',
                                    style: TextStyle(
                                      fontFamily: 'AppFont',
                                      fontFamilyFallback: appFontFallback,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.dark,
                                    ),
                                  ),
                                  Text(
                                    '${widget.price} ج.م',
                                    style: const TextStyle(
                                      fontFamily: 'AppFont',
                                      fontFamilyFallback: appFontFallback,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // اختيار وسيلة الدفع
                    const Text(
                      'وسيلة السداد المعتمدة',
                      style: TextStyle(
                        fontFamily: 'AppFont',
                        fontFamilyFallback: appFontFallback,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.dark,
                      ),
                    ),
                    const SizedBox(height: 10),

                    _buildPaymentOption(
                      index: 0,
                      title: 'فودافون كاش ومحافظ المحمول الإلكترونية',
                      subtitle: 'الدفع الفوري السريع عبر رقم الهاتف',
                      icon: Icons.phone_android_rounded,
                    ),
                    const SizedBox(height: 8),
                    _buildPaymentOption(
                      index: 1,
                      title: 'بطاقة بنكية (Visa / MasterCard / ميزة)',
                      subtitle: 'خصم مباشر بأعلى معايير الحماية',
                      icon: Icons.credit_card_rounded,
                    ),
                    const SizedBox(height: 8),
                    _buildPaymentOption(
                      index: 2,
                      title: 'رصيد محفظة My Lawyer',
                      subtitle: _balance == null ? 'الدفع من رصيدك' : 'رصيدك ${_balance!.toStringAsFixed(0)} ج.م',
                      icon: Icons.account_balance_wallet_rounded,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // زر تأكيد السداد
            Container(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.cardBorder, width: 0.8)),
              ),
              child: AppButton.primary(
                text: 'دفع ${widget.price} ج.م وتأكيد الطلب',
                icon: Icons.lock_rounded,
                onPressed: _processPayment,
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildTableRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.cardBorder, width: 0.8)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'AppFont',
              fontFamilyFallback: appFontFallback,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontFamily: 'AppFont',
                fontFamilyFallback: appFontFallback,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.dark,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption({
    required int index,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _selectedPaymentMethod == index;
    return AppPressable(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            _selectedPaymentMethod = index;
          });
        },
        child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(7.0),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.cardBorder,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.background,
                borderRadius: BorderRadius.circular(7.0),
              ),
              child: Icon(
                icon,
                size: 20,
                color: isSelected ? Colors.white : AppColors.dark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'AppFont',
                      fontFamilyFallback: appFontFallback,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? AppColors.primary : AppColors.dark,
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
            Icon(
              isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: isSelected ? AppColors.primary : AppColors.cardBorder,
              size: 20,
            ),
          ],
        ),
      ),
      ),
    );
  }
}

