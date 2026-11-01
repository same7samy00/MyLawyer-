import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_header.dart';
import 'tracking_screen.dart';

/// شروط خدمة محاميك حالاً، ويوافق عليها الموكل قبل الدخول للخريطة في كل طلب
class ServiceTermsScreen extends StatelessWidget {
  final String? problemTitle;
  final String? problemDescription;

  const ServiceTermsScreen({super.key, this.problemTitle, this.problemDescription});

  static const List<String> _terms = [
    'السعر شامل الانتقال وأوراق الخدمة',
    'الرسوم الحكومية والكفالات على الموكل',
    'بعد الدفع هيظهرلك كود إنهاء المهمة',
    'ادّي الكود للمحامي بعد تنفيذ المهمة فقط',
    'تقدر تلغي وتسترد المبلغ قبل وصول المحامي',
    'المبالغ المرتجعة بتنزل في رصيدك ولا تُسحب',
    'لو حصلت مشكلة قدم شكوى خلال 24 ساعة من إنهاء المهمة',
  ];

  void _accept(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => TrackingScreen(
          problemTitle: problemTitle,
          problemDescription: problemDescription,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AppHeader(title: 'شروط الخدمة', isInnerPage: true),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView.separated(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(24),
                itemCount: _terms.length,
                separatorBuilder: (context, index) => const SizedBox(height: 16),
                itemBuilder: (context, index) => Text(
                  _terms[index],
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'AppFont',
                    fontFamilyFallback: appFontFallback,
                    fontSize: 15,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMain,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: AppButton.primary(
                text: 'موافق ومتابعة',
                height: 50,
                onPressed: () => _accept(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
