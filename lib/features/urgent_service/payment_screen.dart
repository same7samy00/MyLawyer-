import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/routing_service.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_header.dart';
import '../../core/widgets/app_message.dart';
import '../../core/widgets/line_illustration.dart';
import '../../data/models/consultation.dart';
import '../../data/models/map_lawyer.dart';
import 'payment_method_screen.dart';

class PaymentScreen extends StatefulWidget {
  final MapLawyer? lawyer;
  final String? problemTitle;
  final String? problemDescription;
  final String locationName;
  final RouteEstimate? routeEstimate;
  final int price;
  final String? orderId;
  final String? orderNumber;
  /// دفع «استشارة سريعة»: الطلب نفسه بيتبعت مع الدفع، ومن غير محامي ولا مكان
  final ConsultationDraft? consultation;

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
    this.consultation,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String get _orderRef => widget.orderNumber ?? '';

  /// الدفع نفسه في صفحة لوحدها بعد مراجعة الفاتورة
  void _chooseMethod() {
    final orderId = widget.orderId ?? (widget.consultation != null ? '' : null);
    if (orderId == null) {
      showAppMessage(context, 
        const SnackBar(
          content: Text('تعذر العثور على الطلب، ارجع وجرب تاني', style: TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback)),
          backgroundColor: AppColors.dark,
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PaymentMethodScreen(
          orderId: orderId,
          orderRef: _orderRef,
          price: widget.price,
          lawyer: widget.lawyer,
          problemTitle: widget.problemTitle,
          problemDescription: widget.problemDescription,
          locationName: widget.locationName,
          consultation: widget.consultation,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                    const LineIllustration(icon: Icons.credit_card_rounded, height: 100),
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
                        'راجع الفاتورة وبعدها اختار طريقة الدفع',
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
                            if (widget.consultation == null) ...[
                              _buildTableRow('المحامي المعتمد', widget.lawyer?.name ?? '-'),
                              _buildTableRow('نطاق التواجد', widget.locationName),
                            ],
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
                text: 'اختار طريقة الدفع',
                onPressed: _chooseMethod,
              ),
            ),
          ],
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
}
