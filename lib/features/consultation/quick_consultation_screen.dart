import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_header.dart';
import '../../core/widgets/line_illustration.dart';

/// خدمة «استشارة سريعة»: الموكل يكتب مشكلته، يختار نوعها، يرفع ورقه لو فيه،
/// يشوف السعر الثابت ويدفع، والإدارة تكلمه خلال دقايق.
/// الواجهة بس دلوقتي، والأسعار هتيجي من لوحة التحكم بعدين
class ConsultationPricing {
  static const int consultOnly = 200;
  static const int reviewBase = 250;
  static const int perPage = 30;
  static const int maxPages = 10;
  static const int callMinutes = 7;

  static int total({required bool withPapers, required int pages}) =>
      withPapers ? reviewBase + pages * perPage : consultOnly;
}

const _categories = ['أحوال شخصية وأسرة', 'جنائي', 'عمل وعمال', 'إيجارات وعقارات', 'عقود ومعاملات', 'أخرى'];

TextStyle _text(double size, FontWeight weight, Color color, {double? height}) =>
    TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: size, fontWeight: weight, color: color, height: height);

class QuickConsultationScreen extends StatefulWidget {
  const QuickConsultationScreen({super.key});

  @override
  State<QuickConsultationScreen> createState() => _QuickConsultationScreenState();
}

class _QuickConsultationScreenState extends State<QuickConsultationScreen> {
  final _description = TextEditingController();
  String? _category;
  bool _withPapers = false;
  final List<XFile> _pages = [];

  @override
  void initState() {
    super.initState();
    _description.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  bool get _canContinue =>
      _category != null && _description.text.trim().length >= 20 && (!_withPapers || _pages.isNotEmpty);

  Future<void> _addPages() async {
    final left = ConsultationPricing.maxPages - _pages.length;
    if (left <= 0) return;
    final picked = await ImagePicker().pickMultiImage(maxWidth: 1600, imageQuality: 80);
    if (!mounted || picked.isEmpty) return;
    setState(() => _pages.addAll(picked.take(left)));
    if (picked.length > left) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('الحد الأقصى ${ConsultationPricing.maxPages} ورقات', style: _text(13, FontWeight.w600, Colors.white))),
      );
    }
  }

  void _continue() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ConsultationEvaluatingScreen(
        category: _category!,
        description: _description.text.trim(),
        withPapers: _withPapers,
        pages: _withPapers ? _pages.length : 0,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AppHeader(title: 'استشارة سريعة', isInnerPage: true),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: LineIllustration(icon: Icons.support_agent_rounded, height: 80)),
                    const SizedBox(height: 8),
                    Text(
                      'اكتب مشكلتك وادفع، وفريقنا القانوني يكلمك على تليفونك خلال دقايق',
                      textAlign: TextAlign.center,
                      style: _text(13, FontWeight.w600, AppColors.textMuted, height: 1.5),
                    ),
                    const SizedBox(height: 18),
                    _label('نوع المشكلة'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final c in _categories)
                          ChoiceChip(
                            label: Text(c, style: _text(12.5, FontWeight.w700, _category == c ? Colors.white : AppColors.dark)),
                            selected: _category == c,
                            showCheckmark: false,
                            selectedColor: AppColors.primary,
                            backgroundColor: Colors.white,
                            side: BorderSide(color: _category == c ? AppColors.primary : AppColors.cardBorder),
                            onSelected: (_) => setState(() => _category = c),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _label('اكتب مشكلتك'),
                    TextField(
                      controller: _description,
                      maxLines: 5,
                      maxLength: 600,
                      style: _text(14, FontWeight.w600, AppColors.dark, height: 1.5),
                      decoration: InputDecoration(
                        hintText: 'احكي المشكلة باختصار (20 حرف على الأقل)',
                        hintStyle: _text(13, FontWeight.w500, AppColors.textMuted),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(7.0)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(7.0),
                          borderSide: const BorderSide(color: AppColors.cardBorder),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _label('نوع الاستشارة'),
                    _typeOption(
                      selected: !_withPapers,
                      icon: Icons.call_rounded,
                      title: 'استشارة بس',
                      subtitle: 'مكالمة ${ConsultationPricing.callMinutes} دقايق من غير ورق',
                      onTap: () => setState(() => _withPapers = false),
                    ),
                    const SizedBox(height: 8),
                    _typeOption(
                      selected: _withPapers,
                      icon: Icons.description_rounded,
                      title: 'اطلاع على ورق واستشارة',
                      subtitle: 'ترفع صور الورق ونراجعها قبل المكالمة',
                      onTap: () => setState(() => _withPapers = true),
                    ),
                    if (_withPapers) ...[
                      const SizedBox(height: 16),
                      _label('صور الورق (${_pages.length} من ${ConsultationPricing.maxPages})'),
                      Text(
                        'كل صورة لازم تكون ورقة واحدة بس',
                        style: _text(12, FontWeight.w600, AppColors.textMuted),
                      ),
                      const SizedBox(height: 10),
                      _pagesGrid(),
                    ],
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.cardBorder))),
              child: AppButton.primary(text: 'متابعة', height: 48, onPressed: _canContinue ? _continue : null),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: _text(14, FontWeight.w800, AppColors.dark)),
      );

  Widget _typeOption({
    required bool selected,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? AppColors.primaryLight : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(7.0),
        side: BorderSide(color: selected ? AppColors.primary : AppColors.cardBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(7.0),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: _text(14, FontWeight.w800, AppColors.dark)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: _text(12, FontWeight.w600, AppColors.textMuted)),
                  ],
                ),
              ),
              Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: selected ? AppColors.primary : AppColors.cardBorder),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pagesGrid() {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: [
        for (var i = 0; i < _pages.length; i++)
          Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(7.0),
                child: Image.file(File(_pages[i].path), fit: BoxFit.cover),
              ),
              PositionedDirectional(
                top: 2,
                end: 2,
                child: GestureDetector(
                  onTap: () => setState(() => _pages.removeAt(i)),
                  child: const CircleAvatar(radius: 11, backgroundColor: Colors.black54, child: Icon(Icons.close_rounded, size: 14, color: Colors.white)),
                ),
              ),
            ],
          ),
        if (_pages.length < ConsultationPricing.maxPages)
          InkWell(
            borderRadius: BorderRadius.circular(7.0),
            onTap: _addPages,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(7.0),
                border: Border.all(color: AppColors.primary.withOpacity(0.4)),
              ),
              child: const Icon(Icons.add_a_photo_rounded, color: AppColors.primary),
            ),
          ),
      ],
    );
  }
}

/// صفحة «جاري تقييم سعر الخدمة»، وبعدها الملخص بالسعر.
/// دلوقتي التقييم محلي، وبعدين السعر هييجي من السيرفر حسب إعدادات لوحة التحكم
class ConsultationEvaluatingScreen extends StatefulWidget {
  final String category;
  final String description;
  final bool withPapers;
  final int pages;

  const ConsultationEvaluatingScreen({
    super.key,
    required this.category,
    required this.description,
    required this.withPapers,
    required this.pages,
  });

  @override
  State<ConsultationEvaluatingScreen> createState() => _ConsultationEvaluatingScreenState();
}

class _ConsultationEvaluatingScreenState extends State<ConsultationEvaluatingScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => ConsultationCheckoutScreen(
          category: widget.category,
          description: widget.description,
          withPapers: widget.withPapers,
          pages: widget.pages,
        ),
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AppHeader(title: 'استشارة سريعة', isInnerPage: true),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const LineIllustration(icon: Icons.payments_rounded, height: 100),
                const SizedBox(height: 20),
                Text('جاري تقييم سعر الخدمة', textAlign: TextAlign.center, style: _text(18, FontWeight.w900, AppColors.dark)),
                const SizedBox(height: 8),
                Text(
                  widget.withPapers ? 'بنراجع نوع المشكلة وعدد الورق عشان نحددلك السعر' : 'بنراجع نوع المشكلة عشان نحددلك السعر',
                  textAlign: TextAlign.center,
                  style: _text(13, FontWeight.w600, AppColors.textMuted, height: 1.5),
                ),
                const SizedBox(height: 22),
                const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.8, color: AppColors.primary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ملخص الطلب والشروط والدفع
class ConsultationCheckoutScreen extends StatefulWidget {
  final String category;
  final String description;
  final bool withPapers;
  final int pages;

  const ConsultationCheckoutScreen({
    super.key,
    required this.category,
    required this.description,
    required this.withPapers,
    required this.pages,
  });

  @override
  State<ConsultationCheckoutScreen> createState() => _ConsultationCheckoutScreenState();
}

class _ConsultationCheckoutScreenState extends State<ConsultationCheckoutScreen> {
  bool _agreed = false;

  int get _total => ConsultationPricing.total(withPapers: widget.withPapers, pages: widget.pages);

  void _pay() {
    // الدفع الحقيقي هيتربط بعد بوابة الدفع
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const ConsultationDoneScreen()),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    final terms = [
      'مدة المكالمة ${ConsultationPricing.callMinutes} دقايق.',
      'فريقنا هيكلمك على رقم تليفونك المسجل خلال دقايق من الدفع.',
      if (widget.withPapers) 'كل صورة لازم تكون ورقة واحدة، والحد الأقصى ${ConsultationPricing.maxPages} ورقات.',
      'الاستشارة رأي قانوني مبدئي، ومش توكيل في قضية.',
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
                          _row('نوع المشكلة', widget.category),
                          _row('نوع الاستشارة', widget.withPapers ? 'اطلاع على ورق واستشارة' : 'استشارة بس'),
                          const SizedBox(height: 6),
                          Text(widget.description, maxLines: 4, overflow: TextOverflow.ellipsis, style: _text(13, FontWeight.w600, AppColors.textMain, height: 1.5)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppCard(
                      child: Column(
                        children: [
                          if (widget.withPapers) ...[
                            _row('الاطلاع والاستشارة', '${ConsultationPricing.reviewBase} ج.م'),
                            _row('${widget.pages} ورقة × ${ConsultationPricing.perPage}', '${widget.pages * ConsultationPricing.perPage} ج.م'),
                          ] else
                            _row('استشارة', '${ConsultationPricing.consultOnly} ج.م'),
                          const Divider(color: AppColors.cardBorder),
                          Row(
                            children: [
                              Text('الإجمالي', style: _text(14, FontWeight.w900, AppColors.dark)),
                              const Spacer(),
                              Text('$_total ج.م', style: _text(18, FontWeight.w900, AppColors.primary)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('الشروط', style: _text(14, FontWeight.w800, AppColors.dark)),
                    const SizedBox(height: 6),
                    for (final t in terms)
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
                            Expanded(child: Text(t, style: _text(13, FontWeight.w600, AppColors.textMain, height: 1.5))),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      value: _agreed,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: AppColors.primary,
                      title: Text('موافق على الشروط', style: _text(13, FontWeight.w700, AppColors.dark)),
                      onChanged: (v) => setState(() => _agreed = v ?? false),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: AppButton.primary(text: 'ادفع $_total ج.م', height: 50, onPressed: _agreed ? _pay : null),
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
            Text(label, style: _text(13, FontWeight.w700, AppColors.textMuted)),
            const Spacer(),
            Text(value, style: _text(13, FontWeight.w800, AppColors.dark)),
          ],
        ),
      );
}

/// بعد الدفع: الطلب وصل للإدارة
class ConsultationDoneScreen extends StatelessWidget {
  const ConsultationDoneScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Center(child: LineIllustration(icon: Icons.phone_in_talk_rounded, height: 110)),
              const SizedBox(height: 18),
              Text('طلبك وصل', textAlign: TextAlign.center, style: _text(20, FontWeight.w900, AppColors.dark)),
              const SizedBox(height: 8),
              Text(
                'فريقنا القانوني هيكلمك على تليفونك خلال دقايق. خلي تليفونك جنبك',
                textAlign: TextAlign.center,
                style: _text(14, FontWeight.w600, AppColors.textMuted, height: 1.6),
              ),
              const Spacer(),
              AppButton.primary(text: 'رجوع للرئيسية', height: 50, onPressed: () => Navigator.of(context).pop()),
            ],
          ),
        ),
      ),
    );
  }
}
