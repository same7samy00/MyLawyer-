import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_header.dart';
import '../../data/models/consultation.dart';
import '../../data/repositories/consultation_repository.dart';
import 'consultation_evaluating_screen.dart';
import 'consultation_style.dart';

/// الخطوة 2: المشكلة بالتفصيل، وصور الورق لو اختار الاطلاع
class ConsultationDetailsScreen extends StatefulWidget {
  final ConsultationKind kind;

  const ConsultationDetailsScreen({super.key, required this.kind});

  @override
  State<ConsultationDetailsScreen> createState() => _ConsultationDetailsScreenState();
}

class _ConsultationDetailsScreenState extends State<ConsultationDetailsScreen> {
  final _details = TextEditingController();
  final List<XFile> _pages = [];
  ConsultationSettings _settings = const ConsultationSettings();

  bool get _withPapers => widget.kind == ConsultationKind.papers;

  @override
  void initState() {
    super.initState();
    _details.addListener(_onTyping);
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await ConsultationRepository.settings();
    if (mounted) setState(() => _settings = settings);
  }

  // بنعيد البناء بس لما العداد أو الزرار يتغير
  int _lastLength = 0;
  void _onTyping() {
    final length = _details.text.trim().length;
    final crossed = (length >= _settings.minDetailsChars) != (_lastLength >= _settings.minDetailsChars);
    _lastLength = length;
    if (crossed || length < _settings.minDetailsChars) setState(() {});
  }

  @override
  void dispose() {
    _details.removeListener(_onTyping);
    _details.dispose();
    super.dispose();
  }

  int get _length => _details.text.trim().length;

  bool get _canContinue => _settings.isOpen && _length >= _settings.minDetailsChars && (!_withPapers || _pages.isNotEmpty);

  Future<void> _addPages() async {
    final left = _settings.maxPages - _pages.length;
    if (left <= 0) return;
    final picked = await ImagePicker().pickMultiImage(maxWidth: 1600, imageQuality: 80);
    if (!mounted || picked.isEmpty) return;
    setState(() => _pages.addAll(picked.take(left)));
  }

  void _continue() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ConsultationEvaluatingScreen(
        kind: widget.kind,
        details: _details.text.trim(),
        pagePaths: _withPapers ? _pages.map((page) => page.path).toList() : const [],
        settings: _settings,
      ),
    ),);
  }

  @override
  Widget build(BuildContext context) {
    final missing = _settings.minDetailsChars - _length;
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
                    if (!_settings.isOpen) ...[
                      Text(
                        'الخدمة متوقفة دلوقتي\nجرب بعد شوية',
                        textAlign: TextAlign.center,
                        style: consultationText(13, FontWeight.w700, AppColors.danger, height: 1.5),
                      ),
                      const SizedBox(height: 14),
                    ],
                    Text('احكي مشكلتك بالتفصيل', style: consultationText(15, FontWeight.w800, AppColors.dark)),
                    const SizedBox(height: 4),
                    Text(
                      'اكتب اللي حصل، وإمتى، والأطراف اللي معاك\nكل ما التفاصيل تكتر، الاستشارة تبقى أدق',
                      style: consultationText(12, FontWeight.w600, AppColors.textMuted, height: 1.5),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _details,
                      minLines: 7,
                      maxLines: 12,
                      maxLength: 4000,
                      style: consultationText(14, FontWeight.w600, AppColors.dark, height: 1.6),
                      decoration: InputDecoration(
                        hintText: 'مثال: اتفقت مع صاحب الشقة على…',
                        hintStyle: consultationText(13, FontWeight.w500, AppColors.textMuted),
                        helperText: missing > 0 ? 'محتاجين $missing حرف كمان على الأقل' : null,
                        helperStyle: consultationText(11.5, FontWeight.w600, AppColors.textMuted),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16.0)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16.0),
                          borderSide: const BorderSide(color: AppColors.cardBorder),
                        ),
                      ),
                    ),
                    if (_withPapers) ...[
                      const SizedBox(height: 18),
                      Text('صور الورق (${_pages.length} من ${_settings.maxPages})', style: consultationText(15, FontWeight.w800, AppColors.dark)),
                      const SizedBox(height: 4),
                      Text('كل صورة لازم تكون ورقة واحدة بس', style: consultationText(12, FontWeight.w600, AppColors.textMuted)),
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
                child: Image.file(File(_pages[i].path), fit: BoxFit.cover, cacheWidth: 240),
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
        if (_pages.length < _settings.maxPages)
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
