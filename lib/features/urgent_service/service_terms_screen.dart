import 'package:flutter/material.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/auth_hero_header.dart';
import '../../core/widgets/terms_accordion.dart';
import 'tracking_screen.dart';

/// شروط خدمة محاميك حالاً، ويوافق عليها الموكل قبل الدخول للخريطة في كل طلب
class ServiceTermsScreen extends StatelessWidget {
  final String? problemTitle;
  final String? problemDescription;

  const ServiceTermsScreen({super.key, this.problemTitle, this.problemDescription});

  static const List<TermsSection> _sections = [
    TermsSection(
      icon: Icons.verified_user_rounded,
      title: 'السعر والمصاريف',
      items: [
        'السعر يشمل أتعاب المحامي وانتقالاته فقط، وشامل الضريبة',
        'مفيش مصاريف زيادة، ولا التطبيق ولا المحامي من حقهم يطلبوا أي مبلغ إضافي',
        'الرسوم الحكومية والكفالات لو مطلوبة تُدفع للجهة الرسمية',
      ],
    ),
    TermsSection(
      icon: Icons.security_rounded,
      title: 'الدفع وكود الإنهاء',
      items: [
        'بعد الدفع هيظهرلك كود إنهاء المهمة',
        'ادّي الكود للمحامي بعد تنفيذ المهمة فقط',
      ],
    ),
    TermsSection(
      icon: Icons.policy_rounded,
      title: 'الإلغاء والاسترداد',
      items: [
        'تقدر تلغي وتسترد المبلغ قبل وصول المحامي',
        'المبالغ المرتجعة بتنزل في رصيدك ولا تُسحب',
      ],
    ),
    TermsSection(
      icon: Icons.shield_rounded,
      title: 'الشكاوى',
      items: ['لو حصلت مشكلة قدم شكوى خلال 24 ساعة من إنهاء المهمة'],
    ),
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
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AuthHeroHeader(
                      title: 'شروط الخدمة',
                      illustration: 'assets/images/terms_hero.svg',
                      onBack: () => Navigator.of(context).maybePop(),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 16, 20, 16),
                      child: TermsAccordion(sections: _sections),
                    ),
                  ],
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
