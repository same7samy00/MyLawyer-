import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/image_source_page.dart';
import 'field_input.dart';

/// كود التسليم للموكل: يديه للشخص، والشخص يقوله للمحامي لما يقابله. نسخ أو شير على واتساب
class FieldCodeCard extends StatelessWidget {
  final String code;
  final String placeName;
  final void Function(String message) onNotice;

  const FieldCodeCard({super.key, required this.code, required this.placeName, required this.onNotice});

  String get _message => 'كود المحامي اللي هيقابلك في $placeName: $code\nقوله الكود لما يوصلك عشان نتأكد إنه المحامي الصح.';

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: code));
    onNotice('تم نسخ الكود');
  }

  Future<void> _share() async {
    final uri = Uri.https('wa.me', '/', {'text': _message});
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) onNotice('تعذر فتح واتساب، انسخ الكود وابعته');
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('كود الشخص', textAlign: TextAlign.center, style: fieldLabelStyle),
          const SizedBox(height: 4),
          const Text(
            'اديه للشخص، وهو يقوله للمحامي لما يقابله',
            textAlign: TextAlign.center,
            style: fieldMutedStyle,
          ),
          const SizedBox(height: 10),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              code,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'AppFont',
                fontFamilyFallback: appFontFallback,
                fontSize: 34,
                letterSpacing: 10,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: AppButton.outlined(text: 'نسخ الكود', icon: Icons.copy_rounded, height: 44, fontSize: 13, onPressed: _copy)),
              const SizedBox(width: 10),
              Expanded(child: AppButton.primary(text: 'شير', icon: Icons.share_rounded, height: 44, fontSize: 13, onPressed: _share)),
            ],
          ),
        ],
      ),
    );
  }
}

/// المحامي بيكتب الكود اللي الشخص قاله
class FieldCodeSheet extends StatefulWidget {
  const FieldCodeSheet({super.key});

  static Future<String?> ask(BuildContext context) => AppSheet.show<String>(context, builder: (_) => const FieldCodeSheet());

  @override
  State<FieldCodeSheet> createState() => _FieldCodeSheetState();
}

class _FieldCodeSheetState extends State<FieldCodeSheet> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      title: 'كود الشخص',
      actions: [
        AppButton.primary(
          text: 'تأكيد الوصول',
          height: 48,
          onPressed: _controller.text.length == 4 ? () => Navigator.of(context).pop(_controller.text) : null,
        ),
      ],
      children: [
        const Text(
          'اطلب الكود من الشخص بعد ما تقابله، واكتبه هنا',
          textAlign: TextAlign.center,
          style: fieldMutedStyle,
        ),
        const SizedBox(height: 14),
        Directionality(
          textDirection: TextDirection.ltr,
          child: TextField(
            controller: _controller,
            autofocus: true,
            maxLength: 4,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(fontSize: 28, letterSpacing: 12, fontWeight: FontWeight.w900, color: AppColors.dark),
            decoration: fieldDecoration(hint: '----'),
            onChanged: (_) => setState(() {}),
          ),
        ),
      ],
    );
  }
}

/// صورة إثبات للإدارة بس (القسم أو ورقة الاستقبال): كاميرا أو معرض
Future<String?> pickProofPhoto(BuildContext context) async {
  final source = await pickImageSource(context, title: 'صورة إثبات', note: 'الصورة بتتحفظ عند الإدارة بس، والموكل مش بيشوفها');
  if (source == null) return null;
  final picked = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 80);
  return picked?.path;
}
