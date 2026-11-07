import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_header.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/line_illustration.dart';
import '../../data/models/consultation.dart';
import '../../data/repositories/consultation_repository.dart';
import 'consultation_checkout_screen.dart';
import 'consultation_style.dart';

/// الخطوة 3: «جاري تقييم سعر الخدمة»، والسعر نفسه من السيرفر حسب أسعار لوحة التحكم
class ConsultationEvaluatingScreen extends StatefulWidget {
  final ConsultationKind kind;
  final String details;
  final List<String> pagePaths;
  final ConsultationSettings settings;

  const ConsultationEvaluatingScreen({
    super.key,
    required this.kind,
    required this.details,
    required this.pagePaths,
    required this.settings,
  });

  @override
  State<ConsultationEvaluatingScreen> createState() => _ConsultationEvaluatingScreenState();
}

class _ConsultationEvaluatingScreenState extends State<ConsultationEvaluatingScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    _evaluate();
  }

  Future<void> _evaluate() async {
    if (_error != null) setState(() => _error = null);
    // الصفحة بتفضل ظاهرة شوية حتى لو السيرفر رد بسرعة، عشان الموكل يقراها
    final asking = ConsultationRepository.quote(widget.kind, widget.pagePaths.length);
    await Future.delayed(const Duration(milliseconds: 1800));
    final res = await asking;
    if (!mounted) return;
    final quote = res.data;
    if (!res.isOk || quote == null) {
      setState(() => _error = res.error ?? 'تعذر تقييم السعر، حاول تاني');
      return;
    }
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => ConsultationCheckoutScreen(
        draft: ConsultationDraft(kind: widget.kind, details: widget.details, pagePaths: widget.pagePaths, quote: quote),
        settings: widget.settings,
      ),
    ),);
  }

  @override
  Widget build(BuildContext context) {
    final withPapers = widget.kind == ConsultationKind.papers;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AppHeader(title: 'استشارة سريعة', isInnerPage: true),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: LineIllustration(icon: Icons.payments_rounded, height: 100)),
                const SizedBox(height: 20),
                Text(
                  _error == null ? 'جاري تقييم سعر الخدمة' : 'تعذر تقييم السعر',
                  textAlign: TextAlign.center,
                  style: consultationText(18, FontWeight.w900, AppColors.dark),
                ),
                const SizedBox(height: 8),
                Text(
                  _error ?? (withPapers ? 'بنراجع تفاصيل مشكلتك وعدد الورق\nعشان نحددلك السعر' : 'بنراجع تفاصيل مشكلتك\nعشان نحددلك السعر'),
                  textAlign: TextAlign.center,
                  style: consultationText(13, FontWeight.w600, _error == null ? AppColors.textMuted : AppColors.danger, height: 1.5),
                ),
                if (_error == null)
                  const AppLoader()
                else ...[
                  const SizedBox(height: AppLoader.gap),
                  AppButton.primary(text: 'حاول تاني', height: 48, onPressed: _evaluate),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
