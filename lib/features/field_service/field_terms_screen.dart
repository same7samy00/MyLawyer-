import 'package:flutter/material.dart';

import '../../core/widgets/app_button.dart';
import '../../core/widgets/auth_hero_header.dart';
import '../../core/widgets/terms_accordion.dart';
import '../../data/models/field_info.dart';
import '../urgent_service/tracking_screen.dart';

/// شروط الخدمات الميدانية، ويوافق عليها الموكل قبل ما الطلب يتبعت لأقرب المحامين للمكان
class FieldTermsScreen extends StatelessWidget {
  final FieldDraft draft;

  const FieldTermsScreen({super.key, required this.draft});

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
      title: 'وصول المحامي',
      items: [
        'المحامي بيسجل وصوله لما يكون جوه المكان اللي اخترته',
        'لو الطلب لشخص تاني، المحامي بيكتب كود الشخص لما يقابله. ولو ما قدرش، بتأكد وصوله من عندك',
        'لو المحامي ما وصلش، المبلغ بيرجعلك كامل',
      ],
    ),
    TermsSection(
      icon: Icons.policy_rounded,
      title: 'الإلغاء والاسترداد',
      items: [
        'تقدر تلغي وتسترد المبلغ قبل وصول المحامي',
        'لو المحامي وصل والشخص رفضه، الأتعاب بتفضل للمحامي كاملة',
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
        builder: (_) => TrackingScreen(
          problemTitle: draft.serviceTitle,
          problemDescription: draft.description,
          field: draft,
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
              child: AppButton.primary(text: 'موافق ومتابعة', height: 50, onPressed: () => _accept(context)),
            ),
          ],
        ),
      ),
    );
  }
}
