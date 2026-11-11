import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/api_service.dart';
import 'app_sheet.dart';
import 'line_illustration.dart';
import 'sheet_actions.dart';

/// نافذة حذف الحساب للموكل والمحامي: كلمة السر بتأكد إنه صاحب الحساب.
/// الخادم بيرفض لو فيه طلب أو تذكرة أو رصيد مفتوح، وبيقول السبب، فالرسالة بتظهر هنا.
/// بعد النجاح الحساب بيخرج من كل الأجهزة، ودخوله تاني خلال 30 يوم بيلغي الحذف.
class DeleteAccountSheet extends StatefulWidget {
  /// بيتنده بعد ما الطلب يتسجل، عشان الشاشة تخرّج الحساب وتفتح الدخول
  final Future<void> Function() onDeleted;

  const DeleteAccountSheet({super.key, required this.onDeleted});

  static Future<void> show(BuildContext context, {required Future<void> Function() onDeleted}) {
    return AppSheet.show<void>(context, builder: (context) => DeleteAccountSheet(onDeleted: onDeleted));
  }

  @override
  State<DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends State<DeleteAccountSheet> {
  final TextEditingController _password = TextEditingController();
  bool _isBusy = false;
  String? _error;

  static const TextStyle _bodyStyle = TextStyle(
    fontFamily: 'AppFont',
    fontFamilyFallback: appFontFallback,
    fontSize: 13,
    height: 1.5,
    color: AppColors.textMuted,
    fontWeight: FontWeight.w500,
  );

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_password.text.isEmpty) {
      setState(() => _error = 'اكتب كلمة السر عشان نتأكد إنه حسابك');
      return;
    }
    setState(() {
      _isBusy = true;
      _error = null;
    });
    final res = await ApiService.post('/users/me/delete', {'password': _password.text});
    if (!mounted) return;
    if (res.isOk) {
      Navigator.of(context).pop();
      await widget.onDeleted();
      return;
    }
    setState(() {
      _isBusy = false;
      _error = res.error ?? 'تعذر حذف الحساب دلوقتي';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      title: 'حذف الحساب',
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
      children: [
        const LineIllustration(icon: Icons.person_remove_outlined, height: 96),
        const SizedBox(height: 8),
        const Text(
          'حسابك هيخرج من كل الأجهزة دلوقتي، وبياناتك هتتمسح بعد 30 يوم. لو دخلت تاني قبلها، الحذف بيتلغي.\n'
          'الطلبات والمدفوعات القديمة بتفضل عندنا من غير اسمك، عشان الحسابات.',
          textAlign: TextAlign.center,
          style: _bodyStyle,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _password,
          obscureText: true,
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 15),
          decoration: const InputDecoration(hintText: 'كلمة السر'),
          onSubmitted: (_) => _isBusy ? null : _delete(),
        ),
        const SizedBox(height: 12),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'AppFont',
                fontFamilyFallback: appFontFallback,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.danger,
              ),
            ),
          ),
        ...packSheetActions([
          SheetButton('حذف حسابي', _isBusy ? null : _delete, isDanger: true),
          SheetButton('إلغاء', _isBusy ? null : () => Navigator.of(context).pop()),
        ]),
      ],
    );
  }
}
