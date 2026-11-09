import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/auth_service.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_header.dart';
import '../../core/widgets/line_illustration.dart';
import '../../core/widgets/terms_accordion.dart';
import '../../core/widgets/top_message.dart';
import '../../data/repositories/lawyer_repository.dart';

/// صفحة تعريف خدمة «محاميك حالاً» الخاصة بالمحامي
/// تقدم شرحاً شاملاً لدور المحامي وآلية الانضمام وتقديم الخدمة دون بدء طلب موكل أو عرض خرائط
class LawyerUrgentServiceIntroScreen extends StatefulWidget {
  const LawyerUrgentServiceIntroScreen({super.key});

  @override
  State<LawyerUrgentServiceIntroScreen> createState() => _LawyerUrgentServiceIntroScreenState();
}

class _LawyerUrgentServiceIntroScreenState extends State<LawyerUrgentServiceIntroScreen> {
  static const List<TermsSection> _terms = [
    TermsSection(
      icon: Icons.verified_user_rounded,
      title: 'السعر والأتعاب',
      items: [
        'السعر اللي بيدفعه الموكل بيشمل أتعابك وانتقالاتك والضريبة',
        'مش من حقك تطلب من الموكل أي مبلغ زيادة',
        'الضريبة بتتخصم الأول، وبعدها المنصة بتاخد نسبتها من الصافي',
        'التطبيق بيعرضلك صافي أتعابك قبل قبول أي طلب',
      ],
    ),
    TermsSection(
      icon: Icons.location_on_rounded,
      title: 'الحالة والموقع',
      items: [
        'طول ما أنت «متاح» موقعك بيتحدث حتى والتطبيق مقفول',
        'لو ما رديتش على طلبين ورا بعض بتتحول لغير متاح',
        'لو موقعك ما وصلش ساعة بتتحول لغير متاح، ولازم تفعّل حالتك بنفسك',
      ],
    ),
    TermsSection(
      icon: Icons.security_rounded,
      title: 'تنفيذ المهمة',
      items: [
        'عندك دقيقتين لقبول الطلب',
        'سجل «وصلت» وانت على بعد 50 متر من الموكل، ده إثبات إنكم اتقابلتوا',
        'زرار «إنهاء المهمة» بيظهر بعد الوصول، ولازم تنهيها خلال 24 ساعة من الدفع',
      ],
    ),
    TermsSection(
      icon: Icons.policy_rounded,
      title: 'الأتعاب والمخالفات',
      items: [
        'أتعابك بتتحجز 24 ساعة بعد الإنهاء، والشكوى بتجمدها لحد قرار الإدارة',
        'الاعتذار بعد الدفع بيرجع المبلغ للموكل وبيتسجل مخالفة',
        '3 مخالفات من نفس النوع في 30 يوم بتوقف الحساب أسبوع',
      ],
    ),
  ];

  /// NONE أو PENDING أو APPROVED أو REJECTED من الخادم
  String _status = 'NONE';
  String? _rejectionReason;
  bool _accepted = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await LawyerRepository.getProfile();
    if (mounted && profile != null) {
      setState(() {
        _status = profile['urgent_status']?.toString() ?? 'NONE';
        _rejectionReason = profile['urgent_rejection_reason']?.toString();
      });
    }
    // الصورة والكارنيه من التسجيل يتحاولوا تاني لو رفعهم الأول فشل
    await AuthService.uploadPendingDocuments();
  }

  Future<void> _handleApply() async {
    final res = await LawyerRepository.acceptUrgentTerms();
    if (!mounted) return;

    if (res.isOk) setState(() => _status = 'PENDING');
    showTopMessage(context, 
      SnackBar(content: Text(res.isOk ? 'تم إرسال طلبك للإدارة' : (res.error ?? 'تعذر التقديم، حاول تاني'))),
    );
  }

  String get _buttonText => switch (_status) {
        'APPROVED' => 'أنت محامٍ معتمد في الخدمة',
        'PENDING' => 'طلبك قيد المراجعة',
        'REJECTED' => 'قدم مرة تانية',
        _ => 'تقديم على الخدمة',
      };

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
              const Center(
                child: RepaintBoundary(
                  child: LineIllustration(icon: Icons.shield_rounded, height: 100),
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
                'منظومة المساعدة القانونية الفورية لربط المحامي بالموكلين في نطاقه الجغرافي عند الحاجة العاجلة للاستشارة أو الحضور الميداني',
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
                      'بصفتك محامياً مقيداً ومعتمداً، تتيح لك الخدمة استقبال إشعارات بالحالات القانونية الطارئة القريبة منك، وتقديم الاستشارة العاجلة أو التوجه للحضور القضائي والتمثيل القانوني عند موافقتك على الطلب',
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
                      description: 'تفعيل حالة التواجد واستقبال الإشعارات في الأوقات المناسبة لجدول عملك',
                    ),
                    const SizedBox(height: 12),
                    _buildStepRow(
                      number: '2',
                      title: 'استعراض الطلب والموافقة',
                      description: 'الاطلاع على نوع المشكلة والمسافة الجغرافية قبل اتخاذ قرار قبول الطلب',
                    ),
                    const SizedBox(height: 12),
                    _buildStepRow(
                      number: '3',
                      title: 'التواصل والتمثيل المباشر',
                      description: 'الاتصال الفوري بالموكل أو التوجه لمكان الواقعة وفق الضوابط والاتفاق',
                    ),
                    const SizedBox(height: 12),
                    _buildStepRow(
                      number: '4',
                      title: 'تسوية الأتعاب القانونية',
                      description: 'إيداع أتعاب الخدمة مباشرة في محفظتك القانونية داخل التطبيق بأمان وشفافية',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              const TermsAccordion(sections: _terms),
              const SizedBox(height: 28),

              if (_status == 'REJECTED' && _rejectionReason != null) ...[
                Text(
                  'سبب الرفض: $_rejectionReason',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'AppFont',
                    fontFamilyFallback: appFontFallback,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.danger,
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // الموافقة شرط لتفعيل زر التقديم
              if (_status == 'NONE' || _status == 'REJECTED')
                CheckboxListTile(
                  value: _accepted,
                  onChanged: (value) => setState(() => _accepted = value ?? false),
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppColors.primary,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text(
                    'قرأت الشروط وأوافق عليها',
                    style: TextStyle(
                      fontFamily: 'AppFont',
                      fontFamilyFallback: appFontFallback,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.dark,
                    ),
                  ),
                ),

              AppButton(
                text: _buttonText,
                icon: _status == 'APPROVED' ? Icons.check_circle_rounded : Icons.send_rounded,
                backgroundColor: _status == 'APPROVED' ? AppColors.success : AppColors.primary,
                textColor: Colors.white,
                onPressed: _accepted && (_status == 'NONE' || _status == 'REJECTED') ? _handleApply : null,
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
