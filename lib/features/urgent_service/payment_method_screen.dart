import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_pressable.dart';
import '../../core/widgets/auth_hero_header.dart';
import '../../data/models/map_lawyer.dart';
import '../../data/repositories/order_repository.dart';
import 'payment_success_screen.dart';

enum PaymentMethod { mobileWallet, card, balance }

/// صفحة اختيار طريقة الدفع لوحدها بعد مراجعة الفاتورة، بنفس شكل صفحات إنشاء الحساب: رسمة وعنوان ثم الطرق
class PaymentMethodScreen extends StatefulWidget {
  final String orderId;
  final String orderRef;
  final int price;
  final MapLawyer? lawyer;
  final String? problemTitle;
  final String? problemDescription;
  final String locationName;
  /// دفع «استشارة سريعة»: تجريبي من غير سيرفر، ومن غير محامي ولا مكان
  final bool consultation;

  const PaymentMethodScreen({
    super.key,
    required this.orderId,
    required this.orderRef,
    required this.price,
    required this.locationName,
    this.lawyer,
    this.problemTitle,
    this.problemDescription,
    this.consultation = false,
  });

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  PaymentMethod _method = PaymentMethod.mobileWallet;
  bool _isProcessing = false;
  double? _balance;

  bool get _balanceEnough => _balance != null && _balance! >= widget.price;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    final res = await OrderRepository.getClientBalance();
    if (mounted && res.isOk) setState(() => _balance = res.data);
  }

  Future<void> _pay() async {
    setState(() => _isProcessing = true);
    if (widget.consultation) {
      // دفع تجريبي لحد ما بوابة الدفع والسيرفر يجهزوا
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      _openSuccess();
      return;
    }
    final res = await OrderRepository.confirmPayment(widget.orderId, fromBalance: _method == PaymentMethod.balance);
    if (!mounted) return;

    if (!res.isOk) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res.error ?? 'الدفع ما تمش، جرب تاني',
            style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback),
          ),
          backgroundColor: AppColors.dark,
        ),
      );
      return;
    }

    _openSuccess();
  }

  void _openSuccess() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => PaymentSuccessScreen(
          lawyer: widget.lawyer,
          problemTitle: widget.problemTitle,
          problemDescription: widget.problemDescription,
          price: widget.price,
          orderRef: widget.orderRef,
          locationName: widget.locationName,
          consultation: widget.consultation,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final balanceText = _balance == null
        ? 'الدفع من رصيدك في التطبيق'
        : _balanceEnough
            ? 'رصيدك ${_balance!.toStringAsFixed(0)} ج.م'
            : 'رصيدك ${_balance!.toStringAsFixed(0)} ج.م ومش كفاية';

    return PopScope(
      canPop: !_isProcessing,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AuthHeroHeader(
                        title: 'اختار طريقة الدفع',
                        description: 'هتدفع ${widget.price} ج.م للطلب ${widget.orderRef}',
                        icon: Icons.account_balance_wallet_rounded,
                        onBack: () {
                          if (!_isProcessing) Navigator.of(context).maybePop();
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _PaymentOption(
                              title: 'فودافون كاش ومحافظ الموبايل',
                              subtitle: 'ادفع برقم موبايلك',
                              icon: Icons.phone_android_rounded,
                              isSelected: _method == PaymentMethod.mobileWallet,
                              onTap: () => setState(() => _method = PaymentMethod.mobileWallet),
                            ),
                            const SizedBox(height: 10),
                            _PaymentOption(
                              title: 'بطاقة بنكية',
                              subtitle: 'فيزا أو ماستركارد أو ميزة',
                              icon: Icons.credit_card_rounded,
                              isSelected: _method == PaymentMethod.card,
                              onTap: () => setState(() => _method = PaymentMethod.card),
                            ),
                            const SizedBox(height: 10),
                            _PaymentOption(
                              title: 'رصيد My Lawyer',
                              subtitle: balanceText,
                              subtitleColor: _balance != null && !_balanceEnough ? AppColors.danger : null,
                              icon: Icons.account_balance_wallet_rounded,
                              isSelected: _method == PaymentMethod.balance,
                              onTap: _balanceEnough ? () => setState(() => _method = PaymentMethod.balance) : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: AppButton.primary(
                  text: 'ادفع ${widget.price} ج.م',
                  icon: Icons.lock_rounded,
                  isLoading: _isProcessing,
                  onPressed: _isProcessing ? null : _pay,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color? subtitleColor;
  final IconData icon;
  final bool isSelected;
  final VoidCallback? onTap;

  const _PaymentOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: AppPressable(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primaryLight : Colors.white,
              borderRadius: BorderRadius.circular(14.0),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.cardBorder,
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : AppColors.background,
                    borderRadius: BorderRadius.circular(7.0),
                  ),
                  child: Icon(icon, size: 20, color: isSelected ? Colors.white : AppColors.dark),
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
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isSelected ? AppColors.primary : AppColors.dark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontFamily: 'AppFont',
                          fontFamilyFallback: appFontFallback,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: subtitleColor ?? AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  color: isSelected ? AppColors.primary : AppColors.cardBorder,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
