import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_pressable.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_header.dart';

/// صفحة تعريف خدمة «محاميك حالاً» الخاصة بالمحامي
/// تقدم شرحاً شاملاً لدور المحامي وآلية الانضمام وتقديم الخدمة دون بدء طلب موكل أو عرض خرائط
class LawyerUrgentServiceIntroScreen extends StatefulWidget {
  const LawyerUrgentServiceIntroScreen({super.key});

  @override
  State<LawyerUrgentServiceIntroScreen> createState() => _LawyerUrgentServiceIntroScreenState();
}

class _LawyerUrgentServiceIntroScreenState extends State<LawyerUrgentServiceIntroScreen> {
  bool _isApplied = false;

  void _handleApply() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(7.0), // حواف 7.0px ملزمة للمربعات الحوارية
          ),
          backgroundColor: Colors.white,
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: AppColors.success, size: 24),
              SizedBox(width: 8),
              Text(
                'طلب الانضمام للخدمة',
                style: TextStyle(
                  fontFamily: 'AppFont',
                  fontFamilyFallback: appFontFallback,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.dark,
                ),
              ),
            ],
          ),
          content: const Text(
            'تم تسجيل رغبتك في الانضمام إلى مقدمي خدمة «محاميك حالاً» بنجاح. سيتم مراجعة بيانات القيد والاعتماد والتواصل معك لتفعيل استقبال الطلبات.',
            style: TextStyle(
              fontFamily: 'AppFont',
              fontFamilyFallback: appFontFallback,
              fontSize: 13,
              height: 1.5,
              color: AppColors.textMain,
            ),
          ),
          actions: [
            AppPressable(
              child: TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _isApplied = true;
                });
              },
              style: TextButton.styleFrom(
                overlayColor: Colors.transparent,
                foregroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
              child: const Text(
                'حسناً، فهمت',
                style: TextStyle(
                  fontFamily: 'AppFont',
                  fontFamilyFallback: appFontFallback,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AppHeader(
        title: 'محاميك حالاً',
        isInnerPage: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // رسم توضيحي للمحامي
              Center(
                child: RepaintBoundary(
                  child: SvgPicture.asset(
                    'assets/images/lawyer_pana.svg',
                    height: 180,
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // العنوان الرئيسي
              const Text(
                'خدمة «محاميك حالاً» للمحامين',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'AppFont',
                  fontFamilyFallback: appFontFallback,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.dark,
                ),
              ),
              const SizedBox(height: 8),

              // الوصف والتعريف بالخدمة
              const Text(
                'منظومة المساعدة القانونية الفورية لربط المحامي بالموكلين في نطاقه الجغرافي عند الحاجة العاجلة للاستشارة أو الحضور الميداني.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'AppFont',
                  fontFamilyFallback: appFontFallback,
                  fontSize: 13,
                  color: AppColors.textMuted,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 24),

              // بطاقة دور المحامي في الخدمة
              const AppCard(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.shield_rounded, color: AppColors.primary, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'دور المحامي في الخدمة',
                          style: TextStyle(
                            fontFamily: 'AppFont',
                            fontFamilyFallback: appFontFallback,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.dark,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Text(
                      'بصفتك محامياً مقيداً ومعتمداً، تتيح لك الخدمة استقبال إشعارات بالحالات القانونية الطارئة القريبة منك، وتقديم الاستشارة العاجلة أو التوجه للحضور القضائي والتمثيل القانوني عند موافقتك على الطلب.',
                      style: TextStyle(
                        fontFamily: 'AppFont',
                        fontFamilyFallback: appFontFallback,
                        fontSize: 13,
                        height: 1.5,
                        color: AppColors.textMain,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // بطاقة آلية المشاركة والعمل
              AppCard(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.checklist_rounded, color: AppColors.primary, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'آلية المشاركة والعمل',
                          style: TextStyle(
                            fontFamily: 'AppFont',
                            fontFamilyFallback: appFontFallback,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.dark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildStepRow(
                      number: '1',
                      title: 'تحديد الجاهزية والاستعداد',
                      description: 'تفعيل حالة التواجد واستقبال الإشعارات في الأوقات المناسبة لجدول عملك.',
                    ),
                    const SizedBox(height: 12),
                    _buildStepRow(
                      number: '2',
                      title: 'استعراض الطلب والموافقة',
                      description: 'الاطلاع على نوع المشكلة والمسافة الجغرافية قبل اتخاذ قرار قبول الطلب.',
                    ),
                    const SizedBox(height: 12),
                    _buildStepRow(
                      number: '3',
                      title: 'التواصل والتمثيل المباشر',
                      description: 'الاتصال الفوري بالموكل أو التوجه لمكان الواقعة وفق الضوابط والاتفاق.',
                    ),
                    const SizedBox(height: 12),
                    _buildStepRow(
                      number: '4',
                      title: 'تسوية الأتعاب القانونية',
                      description: 'إيداع أتعاب الخدمة مباشرة في محفظتك القانونية داخل التطبيق بأمان وشفافية.',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // زر التقديم على الخدمة
              AppButton(
                text: _isApplied ? 'تم تقديم الطلب بنجاح' : 'تقديم على الخدمة',
                icon: _isApplied ? Icons.check_circle_rounded : Icons.send_rounded,
                backgroundColor: _isApplied ? AppColors.success : AppColors.primary,
                textColor: Colors.white,
                onPressed: _isApplied ? null : _handleApply,
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepRow({
    required String number,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.primary, width: 1.2),
            borderRadius: BorderRadius.circular(7.0),
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                fontFamily: 'AppFont',
                fontFamilyFallback: appFontFallback,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
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
                description,
                style: const TextStyle(
                  fontFamily: 'AppFont',
                  fontFamilyFallback: appFontFallback,
                  fontSize: 12,
                  color: AppColors.textMuted,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
