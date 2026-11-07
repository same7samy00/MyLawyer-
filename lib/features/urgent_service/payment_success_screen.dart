import '../../core/widgets/app_loader.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_header.dart';
import '../../core/widgets/line_illustration.dart';
import '../../data/models/map_lawyer.dart';
import '../client/main_navigation_shell.dart';
import '../auth/session_router.dart';

class PaymentSuccessScreen extends StatefulWidget {
  final MapLawyer? lawyer;
  final String? problemTitle;
  final String? problemDescription;
  final int price;
  final String orderRef;
  final String locationName;

  const PaymentSuccessScreen({
    super.key,
    this.lawyer,
    this.problemTitle,
    this.problemDescription,
    required this.price,
    required this.orderRef,
    required this.locationName,
  });

  @override
  State<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen> {
  int _secondsLeft = 3;
  Timer? _timer;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        timer.cancel();
        _navigateToOrders();
      } else {
        setState(() {
          _secondsLeft--;
        });
      }
    });
  }

  void _navigateToOrders() {
    if (_isNavigating) return;
    _isNavigating = true;
    _timer?.cancel();

    SessionRouter.replaceStack(
      Navigator.of(context),
      const MainNavigationShell(initialIndex: 1), // التبويب الثاني: الطلبات
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // بعد السداد لا يعود الرجوع لصفحة الدفع، بل للطلبات مباشرة
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _navigateToOrders();
      },
      child: Scaffold(
      backgroundColor: Colors.white,
      appBar: AppHeader(
        title: 'تأكيد الدفع',
        isInnerPage: true,
        onBack: _navigateToOrders,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),

              // رسمة النجاح make it rain في الأعلى
              const LineIllustration(icon: Icons.verified_rounded, height: 100),
              const SizedBox(height: 16),

              // أيقونة وعنوان النجاح
              const Center(
                child: Text(
                  'تم الدفع بنجاح!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'AppFont',
                    fontFamilyFallback: appFontFallback,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.dark,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Center(
                child: Text(
                  'المحامي في طريقه إليك\nتابع طلبك من صفحة الطلبات',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'AppFont',
                    fontFamilyFallback: appFontFallback,
                    fontSize: 13,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // شريط العد التنازلي التفاعلي
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const AppLoader.inline(size: 16),
                    const SizedBox(width: 10),
                    Text(
                      'جاري التوجيه إلى صفحة الطلبات خلال ($_secondsLeft) ثوانٍ',
                      style: const TextStyle(
                        fontFamily: 'AppFont',
                        fontFamilyFallback: appFontFallback,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // جدول تفاصيل المعاملة المنظم
              Expanded(
                child: SingleChildScrollView(
                  child: Container(
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
                            color: const Color(0xFFF1F5F9),
                            child: const Row(
                              children: [
                                Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'إيصال السداد المالي المعتمد',
                                  style: TextStyle(
                                    fontFamily: 'AppFont',
                                    fontFamilyFallback: appFontFallback,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.dark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _buildDetailRow('رقم المعاملة المرجعي', widget.orderRef),
                          if (widget.lawyer != null) _buildDetailRow('المحامي المكلف', widget.lawyer!.name),
                          if (widget.problemTitle != null) _buildDetailRow('نوع المشكلة والخدمة', widget.problemTitle!),
                          if (widget.problemDescription != null && widget.problemDescription!.isNotEmpty)
                            _buildDetailRow('تفاصيل المشكلة', widget.problemDescription!),
                          _buildDetailRow('المبلغ المسدد', '${widget.price} ج.م'),
                          _buildDetailRow('طريقة الدفع', 'محفظة إلكترونية معتمدة'),
                          _buildDetailRow('حالة المعاملة', 'مؤكدة ومدفوعة بنجاح ✓', isSuccess: true),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // زر الانتقال المباشر للطلبات مع مؤشر تحميل مدمج وحماية من الضغط المتكرر
              AppButton.primary(
                text: 'متابعة الطلب في صفحة الطلبات الآن',
                icon: Icons.assignment_turned_in_rounded,
                onPressed: _navigateToOrders,
                height: 50,
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isSuccess = false}) {
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
              style: TextStyle(
                fontFamily: 'AppFont',
                fontFamilyFallback: appFontFallback,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSuccess ? AppColors.success : AppColors.dark,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

