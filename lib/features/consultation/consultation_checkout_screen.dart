import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_header.dart';
import '../../data/models/consultation.dart';
import '../urgent_service/payment_screen.dart';
import 'consultation_style.dart';

/// الخطوة 4: الملخص بالسعر والشروط، وبعدها صفحات الدفع المشتركة مع «محاميك حالاً»
class ConsultationCheckoutScreen extends StatefulWidget {
  final ConsultationDraft draft;
  final ConsultationSettings settings;

  const ConsultationCheckoutScreen({super.key, required this.draft, required this.settings});

  @override
  State<ConsultationCheckoutScreen> createState() => _ConsultationCheckoutScreenState();
}

class _ConsultationCheckoutScreenState extends State<ConsultationCheckoutScreen> {
  bool _agreed = false;

  ConsultationDraft get _draft => widget.draft;

  void _pay() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PaymentScreen(
        consultation: _draft,
        problemTitle: _draft.serviceTitle,
        problemDescription: _draft.viaVoice ? 'طلب بالصوت، وفريق المحامين هيسمعه' : _draft.details,
        locationName: '',
        price: _draft.quote.total,
      ),
    ),);
  }

  @override
  Widget build(BuildContext context) {
    final withPapers = _draft.kind == ConsultationKind.papers;
    final terms = [
      'مدة المكالمة ${_draft.quote.callMinutes} دقايق',
      'فريقنا هيكلمك على رقم تليفونك المسجل خلال دقايق من الدفع',
      if (withPapers) 'كل صورة لازم تكون ورقة واحدة، والحد الأقصى ${widget.settings.maxPages} ورقات',
      'لو الإدارة رفضت الطلب، المبلغ كله بيرجع لرصيدك',
      'الاستشارة رأي قانوني مبدئي، ومش توكيل في قضية',
    ];
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AppHeader(title: 'ملخص الاستشارة', isInnerPage: true),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _row('نوع الاستشارة', _draft.kind.label),
                          if (withPapers) _row('عدد الورق', '${_draft.pagePaths.length}'),
                          const SizedBox(height: 6),
                          Text(
                            _draft.viaVoice ? 'كلامك اتسجّل وهيوصل لفريق المحامين' : _draft.details,
                            maxLines: 5,
                            overflow: TextOverflow.ellipsis,
                            style: consultationText(13, FontWeight.w600, AppColors.textMain, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppCard(
                      child: Column(
                        children: [
                          for (final line in _draft.quote.lines) _row(line.label, '${line.amount} ج.م'),
                          const Divider(color: AppColors.cardBorder),
                          Row(
                            children: [
                              Text('الإجمالي', style: consultationText(14, FontWeight.w900, AppColors.dark)),
                              const Spacer(),
                              Text('${_draft.quote.total} ج.م', style: consultationText(18, FontWeight.w900, AppColors.primary)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('الشروط', style: consultationText(14, FontWeight.w800, AppColors.dark)),
                    const SizedBox(height: 6),
                    for (final term in terms)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 3),
                              child: Icon(Icons.check_circle_rounded, size: 16, color: AppColors.primary),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(term, style: consultationText(13, FontWeight.w600, AppColors.textMain, height: 1.5))),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      value: _agreed,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: AppColors.primary,
                      title: Text('موافق على الشروط', style: consultationText(13, FontWeight.w700, AppColors.dark)),
                      onChanged: (value) => setState(() => _agreed = value ?? false),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: AppButton.primary(text: 'متابعة للدفع', height: 50, onPressed: _agreed ? _pay : null),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Text(label, style: consultationText(13, FontWeight.w700, AppColors.textMuted)),
            const Spacer(),
            Text(value, style: consultationText(13, FontWeight.w800, AppColors.dark)),
          ],
        ),
      );
}
