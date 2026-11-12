import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_header.dart';
import '../../core/widgets/line_illustration.dart';
import '../field_service/field_request_screen.dart';
import '../field_service/field_services.dart';
import 'problem_description_screen.dart';

/// نموذج بيانات المشكلة القانونية لخدمة «محاميك حالاً»
class UrgentProblemItem {
  final String id;
  final String title;
  final IconData icon;

  const UrgentProblemItem({
    required this.id,
    required this.title,
    required this.icon,
  });
}

/// شاشة اختيار المشكلة لخدمة «محاميك حالاً» (محسنة بالكامل للأداء والتمرير السلس)
class UrgentServiceProblemScreen extends StatefulWidget {
  const UrgentServiceProblemScreen({super.key});

  @override
  State<UrgentServiceProblemScreen> createState() => _UrgentServiceProblemScreenState();
}

class _UrgentServiceProblemScreenState extends State<UrgentServiceProblemScreen> {

  static const List<UrgentProblemItem> _problems = [
    UrgentProblemItem(
      id: 'police_report',
      title: 'محضر في قسم الشرطة',
      icon: Icons.policy_rounded,
    ),
    UrgentProblemItem(
      id: 'police_arrest',
      title: 'القبض على شخص أو احتجازه بقسم الشرطة',
      icon: Icons.lock_outline_rounded,
    ),
    UrgentProblemItem(
      id: 'prosecution_investigation',
      title: 'تحقيق عاجل في النيابة العامة',
      icon: Icons.verified_user_rounded,
    ),
    UrgentProblemItem(
      id: 'assault_threat',
      title: 'مشاجرة أو اعتداء أو تهديد',
      icon: Icons.warning_amber_rounded,
    ),
    UrgentProblemItem(
      id: 'traffic_accident',
      title: 'حادث سير أو نزاع مروري طارئ',
      icon: Icons.directions_car_rounded,
    ),
    UrgentProblemItem(
      id: 'security_checkpoint',
      title: 'كمين أو استيقاف أمني أو فحص هوية',
      icon: Icons.security_rounded,
    ),
    UrgentProblemItem(
      id: 'search_seizure',
      title: 'تفتيش أو ضبط أو التحفظ على ممتلكات',
      icon: Icons.inventory_2_outlined,
    ),
    UrgentProblemItem(
      id: 'possession_dispute',
      title: 'نزاع حيازة أو طرد أو تمكين',
      icon: Icons.home_work_rounded,
    ),
    UrgentProblemItem(
      id: 'urgent_fact_check',
      title: 'إثبات حالة أو واقعة عاجلة',
      icon: Icons.assignment_late_rounded,
    ),
    UrgentProblemItem(
      id: 'workplace_investigation',
      title: 'تحقيق إداري أو تأديبي عاجل في العمل',
      icon: Icons.business_center_rounded,
    ),
    UrgentProblemItem(
      id: 'unfair_dismissal',
      title: 'فصل تعسفي أو مستحقات عمالية متأخرة',
      icon: Icons.work_off_rounded,
    ),
    UrgentProblemItem(
      id: 'family_dispute',
      title: 'نزاع أسري عاجل أو امتناع عن تنفيذ حكم',
      icon: Icons.family_restroom_rounded,
    ),
    UrgentProblemItem(
      id: 'theft_fraud',
      title: 'سرقة أو نصب أو احتيال',
      icon: Icons.shield_rounded,
    ),
    UrgentProblemItem(
      id: 'other_problem',
      title: 'مشكلة قانونية أخرى',
      icon: Icons.help_outline_rounded,
    ),
  ];

  void _onProblemSelected(UrgentProblemItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FieldServices.isField(item.title)
            ? FieldRequestScreen(problemTitle: item.title)
            : ProblemDescriptionScreen(problemTitle: item.title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AppHeader(
        title: 'اختار مشكلتك',
        isInnerPage: true,
      ),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          physics: const BouncingScrollPhysics(),
          itemCount: _problems.length + 1,
          itemBuilder: (context, index) {
            // العنصر الأول: الهيدر الثابت مع RepaintBoundary للرسمة التوضيحية
            if (index == 0) {
              return const Column(
                children: [
                  RepaintBoundary(
                    child: Center(
                      child: LineIllustration(icon: Icons.help_outline_rounded, height: 90),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'اختار مشكلتك',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'AppFont',
                      fontFamilyFallback: appFontFallback,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.dark,
                    ),
                  ),
                  SizedBox(height: 6),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.0),
                    child: Text(
                      'حدد نوع الموقف القانوني العاجل ليتم ربطك فورياً بأقرب محامٍ متاح في نطاقك الجغرافي',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'AppFont',
                        fontFamilyFallback: appFontFallback,
                        fontSize: 13,
                        color: AppColors.textMuted,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  SizedBox(height: 22),
                ],
              );
            }

            final item = _problems[index - 1];

            return Padding(
              padding: const EdgeInsets.only(bottom: 10.0),
              child: InkWell(
                onTap: () => _onProblemSelected(item),
                borderRadius: BorderRadius.circular(7.0),
                child: AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                  child: Row(
                    children: [
                      // أيقونة الحماية/الأمان
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(7.0),
                        ),
                        child: Icon(
                          item.icon,
                          color: AppColors.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),

                      // اسم المشكلة فقط
                      Expanded(
                        child: Text(
                          item.title,
                          style: const TextStyle(
                            fontFamily: 'AppFont',
                            fontFamilyFallback: appFontFallback,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.dark,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // سهم التنقل
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textMuted,
                          size: 22,
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
