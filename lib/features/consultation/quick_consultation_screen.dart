import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_header.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/line_illustration.dart';
import '../urgent_service/payment_screen.dart';

/// خدمة «استشارة سريعة»، كل خطوة في صفحة:
/// نوع الاستشارة ← تفاصيل المشكلة والورق ← تقييم السعر ← الملخص والشروط ← نفس صفحات الدفع بتاعة «محاميك حالاً».
/// الواجهة بس دلوقتي، والأسعار هتيجي من لوحة التحكم بعدين
class ConsultationPricing {
  static const int consultOnly = 200;
  static const int reviewBase = 250;
  static const int perPage = 30;
  static const int maxPages = 10;
  static const int callMinutes = 7;
  static const int minDetails = 50;

  static int total({required bool withPapers, required int pages}) =>
      withPapers ? reviewBase + pages * perPage : consultOnly;
}

TextStyle _text(double size, FontWeight weight, Color color, {double? height}) =>
    TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: size, fontWeight: weight, color: color, height: height);

String _typeName(bool withPapers) => withPapers ? 'اطلاع على ورق واستشارة' : 'استشارة بس';

/// الخطوة 1: نوع الاستشارة
class QuickConsultationScreen extends StatelessWidget {
  const QuickConsultationScreen({super.key});

  void _choose(BuildContext context, bool withPapers) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ConsultationDetailsScreen(withPapers: withPapers)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AppHeader(title: 'استشارة سريعة', isInnerPage: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: LineIllustration(icon: Icons.support_agent_rounded, height: 90)),
              const SizedBox(height: 10),
              Text('اختار نوع الاستشارة', textAlign: TextAlign.center, style: _text(18, FontWeight.w900, AppColors.dark)),
              const SizedBox(height: 6),
              Text(
                'فريقنا القانوني هيكلمك على تليفونك\nخلال دقايق من الدفع',
                textAlign: TextAlign.center,
                style: _text(13, FontWeight.w600, AppColors.textMuted, height: 1.5),
              ),
              const SizedBox(height: 22),
              _TypeCard(
                icon: Icons.call_rounded,
                title: 'استشارة بس',
                subtitle: 'تحكي مشكلتك والمستشار يرد عليك\nفي مكالمة ${ConsultationPricing.callMinutes} دقايق',
                onTap: () => _choose(context, false),
              ),
              const SizedBox(height: 12),
              _TypeCard(
                icon: Icons.description_rounded,
                title: 'اطلاع على ورق واستشارة',
                subtitle: 'ترفع صور الورق ونراجعها\nوبعدها نكلمك بالرأي القانوني',
                onTap: () => _choose(context, true),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _TypeCard({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(12.0)),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _text(15, FontWeight.w800, AppColors.dark)),
                const SizedBox(height: 4),
                Text(subtitle, style: _text(12, FontWeight.w600, AppColors.textMuted, height: 1.5)),
              ],
            ),
          ),
          const Icon(Icons.keyboard_arrow_left_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

/// الخطوة 2: المشكلة بالتفصيل، وصور الورق لو اختار الاطلاع
class ConsultationDetailsScreen extends StatefulWidget {
  final bool withPapers;

  const ConsultationDetailsScreen({super.key, required this.withPapers});

  @override
  State<ConsultationDetailsScreen> createState() => _ConsultationDetailsScreenState();
}

class _ConsultationDetailsScreenState extends State<ConsultationDetailsScreen> {
  final _details = TextEditingController();
  final List<XFile> _pages = [];

  @override
  void initState() {
    super.initState();
    _details.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  int get _length => _details.text.trim().length;

  bool get _canContinue => _length >= ConsultationPricing.minDetails && (!widget.withPapers || _pages.isNotEmpty);

  Future<void> _addPages() async {
    final left = ConsultationPricing.maxPages - _pages.length;
    if (left <= 0) return;
    final picked = await ImagePicker().pickMultiImage(maxWidth: 1600, imageQuality: 80);
    if (!mounted || picked.isEmpty) return;
    setState(() => _pages.addAll(picked.take(left)));
  }

  void _continue() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ConsultationEvaluatingScreen(
        description: _details.text.trim(),
        withPapers: widget.withPapers,
        pages: widget.withPapers ? _pages.length : 0,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final missing = ConsultationPricing.minDetails - _length;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AppHeader(title: 'تفاصيل المشكلة', isInnerPage: true),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('احكي مشكلتك بالتفصيل', style: _text(15, FontWeight.w800, AppColors.dark)),
                    const SizedBox(height: 4),
                    Text(
                      'اكتب اللي حصل، وإمتى، والأطراف اللي معاك\nكل ما التفاصيل تكتر، الاستشارة تبقى أدق',
                      style: _text(12, FontWeight.w600, AppColors.textMuted, height: 1.5),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _details,
                      minLines: 7,
                      maxLines: 12,
                      maxLength: 2000,
                      style: _text(14, FontWeight.w600, AppColors.dark, height: 1.6),
                      decoration: InputDecoration(
                        hintText: 'مثال: اتفقت مع صاحب الشقة على…',
                        hintStyle: _text(13, FontWeight.w500, AppColors.textMuted),
                        helperText: missing > 0 ? 'محتاجين $missing حرف كمان على الأقل' : null,
                        helperStyle: _text(11.5, FontWeight.w600, AppColors.textMuted),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(7.0)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(7.0),
                          borderSide: const BorderSide(color: AppColors.cardBorder),
                        ),
                      ),
                    ),
                    if (widget.withPapers) ...[
                      const SizedBox(height: 18),
                      Text('صور الورق (${_pages.length} من ${ConsultationPricing.maxPages})', style: _text(15, FontWeight.w800, AppColors.dark)),
                      const SizedBox(height: 4),
                      Text('كل صورة لازم تكون ورقة واحدة بس', style: _text(12, FontWeight.w600, AppColors.textMuted)),
                      const SizedBox(height: 10),
                      _pagesGrid(),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: AppButton.primary(text: 'متابعة', height: 48, onPressed: _canContinue ? _continue : null),
            ),
          ],
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

/// الخطوة 3: «جاري تقييم سعر الخدمة»، وبعدها الملخص بالسعر.
/// دلوقتي التقييم محلي، وبعدين السعر هييجي من السيرفر حسب إعدادات لوحة التحكم
class ConsultationEvaluatingScreen extends StatefulWidget {
  final String description;
  final bool withPapers;
  final int pages;

  const ConsultationEvaluatingScreen({super.key, required this.description, required this.withPapers, required this.pages});

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
                  widget.withPapers ? 'بنراجع تفاصيل مشكلتك وعدد الورق\nعشان نحددلك السعر' : 'بنراجع تفاصيل مشكلتك\nعشان نحددلك السعر',
                  textAlign: TextAlign.center,
                  style: _text(13, FontWeight.w600, AppColors.textMuted, height: 1.5),
                ),
                const AppLoader(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// الخطوة 4: الملخص والشروط، والدفع بنفس صفحات «محاميك حالاً»
class ConsultationCheckoutScreen extends StatefulWidget {
  final String description;
  final bool withPapers;
  final int pages;

  const ConsultationCheckoutScreen({super.key, required this.description, required this.withPapers, required this.pages});

  @override
  State<ConsultationCheckoutScreen> createState() => _ConsultationCheckoutScreenState();
}

class _ConsultationCheckoutScreenState extends State<ConsultationCheckoutScreen> {
  bool _agreed = false;

  int get _total => ConsultationPricing.total(withPapers: widget.withPapers, pages: widget.pages);

  void _pay() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PaymentScreen(
        consultation: true,
        problemTitle: 'استشارة سريعة: ${_typeName(widget.withPapers)}',
        problemDescription: widget.description,
        locationName: '',
        price: _total,
        orderNumber: 'C-${DateTime.now().millisecondsSinceEpoch % 1000000}',
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final terms = [
      'مدة المكالمة ${ConsultationPricing.callMinutes} دقايق',
      'فريقنا هيكلمك على رقم تليفونك المسجل خلال دقايق من الدفع',
      if (widget.withPapers) 'كل صورة لازم تكون ورقة واحدة، والحد الأقصى ${ConsultationPricing.maxPages} ورقات',
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
                          _row('نوع الاستشارة', _typeName(widget.withPapers)),
                          const SizedBox(height: 6),
                          Text(widget.description, maxLines: 5, overflow: TextOverflow.ellipsis, style: _text(13, FontWeight.w600, AppColors.textMain, height: 1.5)),
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
            Text(label, style: _text(13, FontWeight.w700, AppColors.textMuted)),
            const Spacer(),
            Text(value, style: _text(13, FontWeight.w800, AppColors.dark)),
          ],
        ),
      );
}
