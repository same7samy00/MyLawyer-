import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class TermsSection {
  final IconData icon;
  final String title;
  final List<String> items;

  const TermsSection({required this.icon, required this.title, required this.items});
}

/// الشروط مقسمة أقسام، وقسم واحد بس مفتوح دايمًا: الأول في البداية،
/// وفتح أي قسم بيقفل اللي كان مفتوح، والمفتوح ما يتقفلش غير بفتح غيره
class TermsAccordion extends StatefulWidget {
  final List<TermsSection> sections;

  const TermsAccordion({super.key, required this.sections});

  @override
  State<TermsAccordion> createState() => _TermsAccordionState();
}

class _TermsAccordionState extends State<TermsAccordion> {
  late List<ExpansionTileController> _controllers;
  int _open = 0;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.sections.length, (_) => ExpansionTileController());
  }

  @override
  void didUpdateWidget(TermsAccordion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sections.length != widget.sections.length) {
      _controllers = List.generate(widget.sections.length, (_) => ExpansionTileController());
      _open = 0;
    }
  }

  void _changed(int index, bool expanded) {
    if (expanded) {
      final previous = _open;
      _open = index;
      if (previous != index) _controllers[previous].collapse();
    } else if (index == _open) {
      // المفتوح يفضل مفتوح، عشان الصفحة ما تبقاش كلها مقفولة
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _open == index) _controllers[index].expand();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < widget.sections.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _TermsTile(
            section: widget.sections[i],
            controller: _controllers[i],
            initiallyExpanded: i == _open,
            onChanged: (expanded) => _changed(i, expanded),
          ),
        ],
      ],
    );
  }
}

class _TermsTile extends StatelessWidget {
  final TermsSection section;
  final ExpansionTileController controller;
  final bool initiallyExpanded;
  final ValueChanged<bool> onChanged;

  const _TermsTile({required this.section, required this.controller, required this.initiallyExpanded, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(7.0),
      side: const BorderSide(color: AppColors.cardBorder),
    );

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        controller: controller,
        initiallyExpanded: initiallyExpanded,
        onExpansionChanged: onChanged,
        backgroundColor: Colors.white,
        collapsedBackgroundColor: Colors.white,
        shape: shape,
        collapsedShape: shape,
        iconColor: AppColors.primary,
        collapsedIconColor: AppColors.textMuted,
        tilePadding: const EdgeInsets.symmetric(horizontal: 14),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(7.0),
          ),
          child: Icon(section.icon, color: AppColors.primary, size: 19),
        ),
        title: Text(
          section.title,
          style: const TextStyle(
            fontFamily: 'AppFont',
            fontFamilyFallback: appFontFallback,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.dark,
          ),
        ),
        children: [
          for (final item in section.items)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                item,
                style: const TextStyle(
                  fontFamily: 'AppFont',
                  fontFamilyFallback: appFontFallback,
                  fontSize: 13,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMain,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
