import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_header.dart';
import 'service_terms_screen.dart';

/// شاشة وصف المشكلة القانونية لخدمة «محاميك حالاً»
class ProblemDescriptionScreen extends StatefulWidget {
  final String problemTitle;

  const ProblemDescriptionScreen({
    super.key,
    required this.problemTitle,
  });

  @override
  State<ProblemDescriptionScreen> createState() => _ProblemDescriptionScreenState();
}

class _ProblemDescriptionScreenState extends State<ProblemDescriptionScreen> {
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  void _onContinue() {
    final text = _descriptionController.text.trim();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ServiceTermsScreen(
          problemTitle: widget.problemTitle,
          problemDescription: text.isNotEmpty ? text : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AppHeader(
        title: 'تفاصيل المشكلة',
        isInnerPage: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // رسمة توضيحية أعلى الصفحة بصيغة SVG مع RepaintBoundary لتحسين أداء التمرير
                    RepaintBoundary(
                      child: Center(
                        child: SvgPicture.asset(
                          'assets/images/mail_sent_rafiki.svg',
                          width: 180,
                          height: 155,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // شارة نوع الخدمة المختارة
                    AppCard(
                      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(7.0),
                            ),
                            child: const Icon(
                              Icons.policy_rounded,
                              color: AppColors.primary,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'الخدمة المختارة',
                                  style: TextStyle(
                                    fontFamily: 'AppFont',
                                    fontFamilyFallback: appFontFallback,
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.problemTitle,
                                  style: const TextStyle(
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
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // عنوان واضح لكتابة المشكلة باختصار
                    const Text(
                      'اكتب تفاصيل مشكلتك باختصار',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'AppFont',
                        fontFamilyFallback: appFontFallback,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.dark,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // النص التوضيحي
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text(
                        'يساعد هذا الوصف المحامي في الاطلاع على طبيعة الموقف وفهم المشكلة بدقة قبل الاستجابة لطلبك.',
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
                    const SizedBox(height: 18),

                    // صندوق نص كبير متعدد الأسطر مع placeholder مريح
                    TextField(
                      controller: _descriptionController,
                      minLines: 4,
                      maxLines: 6,
                      maxLength: 500,
                      style: const TextStyle(
                        fontFamily: 'AppFont',
                        fontFamilyFallback: appFontFallback,
                        fontSize: 14,
                        color: AppColors.dark,
                      ),
                      decoration: InputDecoration(
                        hintText: 'اكتب هنا ملخصاً سريعاً لما حدث، موقعك الحالي، وأي تفاصيل تود إطلاع المحامي عليها',
                        hintStyle: const TextStyle(
                          fontFamily: 'AppFont',
                          fontFamilyFallback: appFontFallback,
                          fontSize: 13,
                          color: AppColors.textMuted,
                          height: 1.5,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.all(16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16.0),
                          borderSide: const BorderSide(color: AppColors.cardBorder, width: 1.0),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16.0),
                          borderSide: const BorderSide(color: AppColors.cardBorder, width: 1.0),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16.0),
                          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // زر المتابعة إلى خريطة المحامين بالأسفل (مع مؤشر تحميل مدمج وحماية من الضغط المتكرر)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: AppButton.primary(
                text: 'المتابعة إلى خريطة المحامين',
                icon: Icons.arrow_forward_rounded,
                onPressed: _onContinue,
                height: 50,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

