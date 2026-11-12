import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_header.dart';
import '../../core/widgets/app_message.dart';
import '../../core/widgets/line_illustration.dart';
import '../../data/models/field_info.dart';
import 'field_input.dart';
import 'field_place_picker.dart';
import 'field_services.dart';
import 'field_terms_screen.dart';

/// طلب خدمة ميدانية (محضر، نيابة، جلسة، مجلس عرفي، مصلحة): ليك ولا لشخص تاني، والمكان باسمه، والتفاصيل
class FieldRequestScreen extends StatefulWidget {
  final String problemTitle;
  final String initialDescription;

  const FieldRequestScreen({super.key, required this.problemTitle, this.initialDescription = ''});

  @override
  State<FieldRequestScreen> createState() => _FieldRequestScreenState();
}

class _FieldRequestScreenState extends State<FieldRequestScreen> {
  late final TextEditingController _description = TextEditingController(text: widget.initialDescription);
  final TextEditingController _personName = TextEditingController();
  bool _forOther = false;
  bool _detained = false;
  String _relation = '';
  FieldPlace? _place;

  @override
  void dispose() {
    _description.dispose();
    _personName.dispose();
    super.dispose();
  }

  void _continue() {
    final place = _place;
    final description = _description.text.trim();
    final name = _personName.text.trim();
    String? problem;
    if (_forOther && name.isEmpty) {
      problem = 'اكتب اسم الشخص';
    } else if (place == null) {
      problem = 'اختار المكان الأول';
    } else if (description.length < 5) {
      problem = 'اكتب تفاصيل الطلب باختصار';
    }
    if (problem != null) {
      showAppMessage(context, SnackBar(content: Text(problem)));
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FieldTermsScreen(
          draft: FieldDraft(
            serviceTitle: widget.problemTitle,
            description: description,
            place: place!,
            forOther: _forOther,
            personName: name,
            relation: _relation,
            detained: _forOther && _detained,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AppHeader(title: 'تفاصيل الطلب', isInnerPage: true),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const RepaintBoundary(child: Center(child: LineIllustration(icon: Icons.edit_note_rounded, height: 90))),
                    const SizedBox(height: 16),
                    _serviceCard(),
                    const SizedBox(height: 18),
                    const Text('الطلب ده لمين؟', style: fieldLabelStyle),
                    const SizedBox(height: 8),
                    _whoToggle(),
                    if (_forOther) ..._personSection(),
                    const SizedBox(height: 18),
                    const Text('المكان اللي المحامي هيروحه', style: fieldLabelStyle),
                    const SizedBox(height: 8),
                    FieldPlacePicker(
                      hint: FieldServices.placeHint(widget.problemTitle),
                      selected: _place,
                      onChanged: (place) => setState(() => _place = place),
                    ),
                    const SizedBox(height: 18),
                    const Text('اكتب تفاصيل الطلب باختصار', style: fieldLabelStyle),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _description,
                      minLines: 4,
                      maxLines: 6,
                      maxLength: 500,
                      style: fieldTextStyle,
                      decoration: fieldDecoration(hint: 'اكتب هنا ملخصًا لما حصل، وأي ورق أو تفاصيل المحامي محتاج يعرفها'),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: AppButton.primary(text: 'المتابعة', onPressed: _continue, height: 50),
            ),
          ],
        ),
      ),
    );
  }

  Widget _serviceCard() {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(7.0)),
            child: const Icon(Icons.policy_rounded, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('الخدمة المختارة', style: fieldMutedStyle),
                const SizedBox(height: 2),
                Text(widget.problemTitle, style: fieldLabelStyle),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _whoToggle() {
    Widget option(String text, IconData icon, bool other) {
      final on = _forOther == other;
      return Expanded(
        child: InkWell(
          onTap: () => setState(() => _forOther = other),
          borderRadius: BorderRadius.circular(14.0),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: on ? AppColors.primaryLight : Colors.white,
              borderRadius: BorderRadius.circular(14.0),
              border: Border.all(color: on ? AppColors.primary : AppColors.cardBorder, width: on ? 1.4 : 1.0),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: on ? AppColors.primary : AppColors.textMuted),
                const SizedBox(width: 6),
                Text(text, style: fieldLabelStyle.copyWith(color: on ? AppColors.primary : AppColors.dark)),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        option('ليا أنا', Icons.person_rounded, false),
        const SizedBox(width: 10),
        option('لشخص تاني', Icons.group_rounded, true),
      ],
    );
  }

  List<Widget> _personSection() {
    return [
      const SizedBox(height: 14),
      TextField(
        controller: _personName,
        maxLength: 120,
        textInputAction: TextInputAction.next,
        style: fieldTextStyle,
        decoration: fieldDecoration(hint: 'اسم الشخص', icon: Icons.badge_rounded),
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final relation in FieldServices.relations)
            ChoiceChip(
              label: Text(relation),
              selected: _relation == relation,
              onSelected: (on) => setState(() => _relation = on ? relation : ''),
            ),
        ],
      ),
      if (FieldServices.asksDetained(widget.problemTitle)) ...[
        const SizedBox(height: 6),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('الشخص محبوس أو محتجز', style: fieldLabelStyle),
          subtitle: const Text('لو معاهوش تليفون، المحامي هيأكد وصوله معاك بدل الكود', style: fieldMutedStyle),
          value: _detained,
          onChanged: (on) => setState(() => _detained = on),
        ),
      ],
      const SizedBox(height: 4),
      const Text(
        'هيظهرلك كود من 4 أرقام بعد الدفع. اديه للشخص، وهو يقوله للمحامي لما يقابله',
        style: fieldMutedStyle,
      ),
    ];
  }
}
