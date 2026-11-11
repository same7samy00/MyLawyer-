import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/auth_hero_header.dart';
import '../../core/widgets/delete_account_sheet.dart';
import '../../core/widgets/terms_accordion.dart';
import '../auth/session_router.dart';

/// الشروط والأحكام وسياسة الخصوصية للموكل والمحامي، من نفس نصوص الموقع
/// (backend/public/site/terms و privacy). وفي آخرها حذف الحساب، زي ما جوجل بتطلب
class TermsPrivacyScreen extends StatelessWidget {
  const TermsPrivacyScreen({super.key});

  static const List<TermsSection> _sections = [
    TermsSection(
      icon: Icons.verified_user_rounded,
      title: 'عن الخدمة والحساب',
      items: [
        'My Lawyer منصة بتوصلك بمحامين معتمدين، والمحامي هو المسؤول مهنيًا عن الخدمة القانونية',
        'لازم تكون عندك 18 سنة أو أكتر، وتسجل ببيانات صحيحة ورقم موبايل مصري',
        'انت مسؤول عن سرية بيانات دخولك وعن أي استخدام لحسابك',
        'المحامي بيتراجع ملفه وكارنيه النقابة قبل تفعيل حسابه',
      ],
    ),
    TermsSection(
      icon: Icons.policy_rounded,
      title: 'الأسعار والدفع',
      items: [
        'كل الأسعار بالجنيه المصري وبتظهر كاملة قبل تأكيد الطلب',
        'مفيش مصاريف إضافية بعد الدفع، والرسوم الحكومية أو الكفالات بتتدفع للجهة الرسمية',
        'المبلغ بيتحجز لحد تنفيذ الخدمة، وبعدها بيتحول للمحامي بعد خصم نسبة المنصة',
      ],
    ),
    TermsSection(
      icon: Icons.security_rounded,
      title: 'الاستخدام المسموح والشكاوى',
      items: [
        'ممنوع استخدام المنصة في أي غرض مخالف للقانون أو لإيذاء أي طرف',
        'ممنوع الاتفاق على الدفع خارج التطبيق، أو طلب أي مبلغ إضافي',
        'المنصة من حقها توقف أي حساب يخالف الشروط',
        'تقدر تقدم شكوى من صفحة الطلب خلال 24 ساعة من انتهاء الخدمة',
      ],
    ),
    TermsSection(
      icon: Icons.shield_rounded,
      title: 'بياناتك وخصوصيتك',
      items: [
        'بنجمع الاسم ورقم الموبايل والإيميل، وصورة المحامي وكارنيه النقابة للتحقق',
        'موقعك بيتاخد وقت الطلب بس لعرض أقرب المحامين',
        'مش بنبيع بياناتك لأي طرف، والمحامي بيشوف مكانك الدقيق ورقمك بعد الدفع بس',
        'البيانات بتتنقل مشفرة، والمستندات الخاصة محفوظة في مكان غير متاح للعامة',
      ],
    ),
    TermsSection(
      icon: Icons.person_remove_outlined,
      title: 'حذف الحساب',
      items: [
        'تقدر تطلب حذف حسابك من الزرار اللي تحت',
        'حسابك بيخرج من كل الأجهزة على طول، وبياناتك بتتمسح بعد 30 يوم. لو دخلت تاني قبلها، الحذف بيتلغي',
        'الحذف بيتمنع لو عندك طلب أو تذكرة مفتوحة، أو رصيد أو مديونية',
        'الطلبات والمدفوعات القديمة بتفضل من غير اسمك، عشان الحسابات',
      ],
    ),
  ];

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
                      title: 'الشروط والأحكام',
                      icon: Icons.policy_rounded,
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
              child: AppButton.outlined(
                text: 'حذف الحساب',
                height: 50,
                textColor: AppColors.danger,
                borderColor: AppColors.danger.withOpacity(0.35),
                onPressed: () {
                  final navigator = Navigator.of(context, rootNavigator: true);
                  DeleteAccountSheet.show(context, onDeleted: () => SessionRouter.signOut(navigator));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
