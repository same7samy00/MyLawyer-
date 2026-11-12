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

/// «اطلاع على ورق»: بعد ما العميل حكى مشكلته لمحاميحو، هنا بيضيف صور الورق (ورقة في كل صورة)
class ConsultationPagesScreen extends StatefulWidget {
  /// المشكلة اللي اتقالت لمحاميحو (بالكتابة أو بالصوت)
  final String details;
  final bool viaVoice;

  const ConsultationPagesScreen({super.key, required this.details, this.viaVoice = false});

  @override
  State<ConsultationPagesScreen> createState() => _ConsultationPagesScreenState();
}

class _ConsultationPagesScreenState extends State<ConsultationPagesScreen> {
  final List<XFile> _pages = [];
  ConsultationSettings _settings = const ConsultationSettings();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await ConsultationRepository.settings();
    if (mounted) setState(() => _settings = settings);
  }

  bool get _canContinue => _settings.isOpen && _pages.isNotEmpty;

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
        kind: ConsultationKind.papers,
        details: widget.details,
        pagePaths: _pages.map((page) => page.path).toList(),
        settings: _settings,
        viaVoice: widget.viaVoice,
      ),
    ),);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AppHeader(title: 'صور الورق', isInnerPage: true),
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
                    Text('صور الورق (${_pages.length} من ${_settings.maxPages})', style: consultationText(15, FontWeight.w800, AppColors.dark)),
                    const SizedBox(height: 4),
                    Text('كل صورة لازم تكون ورقة واحدة بس', style: consultationText(12, FontWeight.w600, AppColors.textMuted)),
                    const SizedBox(height: 10),
                    _pagesGrid(),
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
