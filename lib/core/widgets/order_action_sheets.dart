import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_colors.dart';
import '../services/api_service.dart';
import 'app_button.dart';
import 'app_pressable.dart';
import 'app_sheet.dart';
import 'sheet_actions.dart';

const TextStyle _subtitleStyle = TextStyle(
  fontFamily: 'AppFont',
  fontFamilyFallback: appFontFallback,
  fontSize: 13,
  height: 1.4,
  color: AppColors.textMuted,
);

/// نوافذ الإجراءات: التقييم، والتحويل من المحفظة
/// كل نافذة تعيد true عندما يقبل الخادم الإجراء
class OrderActionSheets {
  OrderActionSheets._();

  static Future<bool> _show(BuildContext context, Widget child) async {
    final result = await AppSheet.show<bool>(context, builder: (context) => child);
    return result ?? false;
  }

  static Future<bool> review(
    BuildContext context, {
    required String lawyerName,
    required Future<ApiResponse<dynamic>> Function(int rating, String comment) onSubmit,
  }) {
    return _show(context, _ReviewSheet(lawyerName: lawyerName, onSubmit: onSubmit));
  }

  static Future<bool> reportReview(
    BuildContext context, {
    required Future<ApiResponse<dynamic>> Function(String reason) onSubmit,
  }) {
    return _show(context, _ReportReviewSheet(onSubmit: onSubmit));
  }

  static Future<bool> transfer(
    BuildContext context, {
    required Future<ApiResponse<dynamic>> Function(String phone) findRecipient,
    required Future<ApiResponse<dynamic>> Function(String phone, double amount) onSubmit,
  }) {
    return _show(context, _TransferSheet(findRecipient: findRecipient, onSubmit: onSubmit));
  }
}

class _ErrorText extends StatelessWidget {
  final String? message;

  const _ErrorText(this.message);

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        message!,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'AppFont',
          fontFamilyFallback: appFontFallback,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.danger,
        ),
      ),
    );
  }
}

class _ReviewSheet extends StatefulWidget {
  final String lawyerName;
  final Future<ApiResponse<dynamic>> Function(int rating, String comment) onSubmit;

  const _ReviewSheet({required this.lawyerName, required this.onSubmit});

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  final _controller = TextEditingController();
  int _rating = 0;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      setState(() => _error = 'اختار عدد النجوم');
      return;
    }

    final navigator = Navigator.of(context);
    final res = await widget.onSubmit(_rating, _controller.text.trim());
    if (!mounted) return;

    if (res.isOk) {
      navigator.pop(true);
    } else {
      setState(() => _error = res.error ?? 'تعذر إرسال التقييم');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      title: 'قيّم المحامي',
      children: [
        Text(widget.lawyerName, textAlign: TextAlign.center, style: _subtitleStyle),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int star = 1; star <= 5; star++)
              AppPressable(
                child: IconButton(
                  tooltip: '$star',
                  onPressed: () => setState(() => _rating = star),
                  icon: Icon(
                    star <= _rating ? Icons.star_rounded : Icons.star_border_rounded,
                    color: const Color(0xFFEAB308),
                    size: 36,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          maxLines: 3,
          maxLength: 1000,
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 14),
          decoration: const InputDecoration(hintText: 'اكتب تعليقك لو حابب', counterText: ''),
        ),
        const SizedBox(height: 12),
        _ErrorText(_error),
        AppButton.primary(text: 'إرسال التقييم', onPressed: _submit),
      ],
    );
  }
}

/// بلاغ المحامي عن تعليق، والإدارة بتقرر تخفيه أو تسيبه
class _ReportReviewSheet extends StatefulWidget {
  final Future<ApiResponse<dynamic>> Function(String reason) onSubmit;

  const _ReportReviewSheet({required this.onSubmit});

  @override
  State<_ReportReviewSheet> createState() => _ReportReviewSheetState();
}

class _ReportReviewSheetState extends State<_ReportReviewSheet> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _controller.text.trim();
    if (reason.length < 3) {
      setState(() => _error = 'اكتب سبب البلاغ');
      return;
    }

    final navigator = Navigator.of(context);
    final res = await widget.onSubmit(reason);
    if (!mounted) return;

    if (res.isOk) {
      navigator.pop(true);
    } else {
      setState(() => _error = res.error ?? 'تعذر إرسال البلاغ');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      title: 'الإبلاغ عن التعليق',
      children: [
        const Text('الإدارة هتراجع التعليق وتقرر', textAlign: TextAlign.center, style: _subtitleStyle),
        const SizedBox(height: 12),
        TextField(
          controller: _controller,
          maxLines: 3,
          maxLength: 500,
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 14),
          decoration: const InputDecoration(hintText: 'ليه التعليق ده مخالف؟', counterText: ''),
        ),
        const SizedBox(height: 12),
        _ErrorText(_error),
        AppButton.primary(text: 'إرسال البلاغ', onPressed: _submit),
      ],
    );
  }
}

/// التحويل على خطوتين: الرقم والمبلغ، ثم تأكيد اسم المستلم قبل الإرسال
class _TransferSheet extends StatefulWidget {
  final Future<ApiResponse<dynamic>> Function(String phone) findRecipient;
  final Future<ApiResponse<dynamic>> Function(String phone, double amount) onSubmit;

  const _TransferSheet({required this.findRecipient, required this.onSubmit});

  @override
  State<_TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends State<_TransferSheet> {
  static const _minimum = 100;
  static const _dailyLimit = 10000;

  final _phone = TextEditingController();
  final _amount = TextEditingController();
  String? _recipientName;
  String? _error;
  bool _isBusy = false;

  @override
  void dispose() {
    _phone.dispose();
    _amount.dispose();
    super.dispose();
  }

  double get _amountValue => double.tryParse(_amount.text.trim()) ?? 0;

  Future<void> _next() async {
    final phone = _phone.text.trim();
    if (!RegExp(r'^01[0125][0-9]{8}$').hasMatch(phone)) {
      setState(() => _error = 'اكتب رقم موبايل صحيح');
      return;
    }
    if (_amountValue < _minimum || _amountValue > _dailyLimit) {
      setState(() => _error = 'المبلغ من $_minimum لـ $_dailyLimit ج.م');
      return;
    }

    setState(() => _isBusy = true);
    final res = await widget.findRecipient(phone);
    if (!mounted) return;
    setState(() {
      _isBusy = false;
      if (res.isOk && res.data is Map<String, dynamic>) {
        _recipientName = (res.data as Map<String, dynamic>)['name']?.toString();
        _error = null;
      } else {
        _error = res.error ?? 'تعذر العثور على الحساب';
      }
    });
  }

  Future<void> _send() async {
    setState(() => _isBusy = true);
    final navigator = Navigator.of(context);
    final res = await widget.onSubmit(_phone.text.trim(), _amountValue);
    if (!mounted) return;

    if (res.isOk) {
      navigator.pop(true);
    } else {
      setState(() {
        _isBusy = false;
        _error = res.error ?? 'تعذر التحويل';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final confirming = _recipientName != null;
    return AppSheet(
      title: 'تحويل من رصيدك',
      children: [
        Text(
          confirming ? 'راجع البيانات قبل التحويل' : 'من $_minimum لحد $_dailyLimit ج.م في اليوم، ومن غير رسوم',
          textAlign: TextAlign.center,
          style: _subtitleStyle,
        ),
        const SizedBox(height: 16),
        if (confirming) ...[
          Text(
            '${_amountValue.toStringAsFixed(0)} ج.م إلى $_recipientName',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'AppFont',
              fontFamilyFallback: appFontFallback,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.dark,
            ),
          ),
          Text(_phone.text.trim(), textAlign: TextAlign.center, style: _subtitleStyle),
          const SizedBox(height: 16),
          _ErrorText(_error),
          ...packSheetActions([
            SheetButton('تأكيد التحويل', _isBusy ? null : _send, isPrimary: true),
            SheetButton('تعديل', _isBusy ? null : () => setState(() => _recipientName = null)),
          ]),
        ] else ...[
          TextField(
            controller: _phone,
            autofocus: true,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(11)],
            style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 15),
            decoration: const InputDecoration(hintText: 'رقم موبايل المستلم'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _amount,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)],
            style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 15),
            decoration: const InputDecoration(hintText: 'المبلغ بالجنيه'),
          ),
          const SizedBox(height: 12),
          _ErrorText(_error),
          AppButton.primary(text: 'متابعة', onPressed: _isBusy ? null : _next),
        ],
      ],
    );
  }
}
