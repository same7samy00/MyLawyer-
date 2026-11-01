import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../services/api_service.dart';
import 'app_button.dart';
import 'app_pressable.dart';
import 'sheet_lines.dart';

const TextStyle _titleStyle = TextStyle(
  fontFamily: 'AppFont',
  fontFamilyFallback: appFontFallback,
  fontSize: 17,
  fontWeight: FontWeight.w900,
  color: AppColors.dark,
);

const TextStyle _subtitleStyle = TextStyle(
  fontFamily: 'AppFont',
  fontFamilyFallback: appFontFallback,
  fontSize: 13,
  height: 1.4,
  color: AppColors.textMuted,
);

/// نوافذ إجراءات الطلب: كود الإنهاء، الشكوى، الاعتراض، والتقييم
/// كل نافذة تعيد true عندما يقبل الخادم الإجراء
class OrderActionSheets {
  OrderActionSheets._();

  static Future<bool> _show(BuildContext context, Widget child) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (context) => child,
    );
    return result ?? false;
  }

  static Future<bool> completion(BuildContext context, {required Future<ApiResponse<dynamic>> Function(String code) onSubmit}) {
    return _show(context, _CompletionCodeSheet(onSubmit: onSubmit));
  }

  static Future<bool> text(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String hint,
    required String buttonText,
    required Future<ApiResponse<dynamic>> Function(String text) onSubmit,
  }) {
    return _show(
      context,
      _TextActionSheet(title: title, subtitle: subtitle, hint: hint, buttonText: buttonText, onSubmit: onSubmit),
    );
  }

  static Future<bool> review(
    BuildContext context, {
    required String lawyerName,
    required Future<ApiResponse<dynamic>> Function(int rating, String comment) onSubmit,
  }) {
    return _show(context, _ReviewSheet(lawyerName: lawyerName, onSubmit: onSubmit));
  }
}

class _SheetFrame extends StatelessWidget {
  final List<Widget> children;

  const _SheetFrame({required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Stack(
        children: [
          const SheetLines(top: 16),
          SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.cardBorder,
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                    ),
                  ),
                  const SizedBox(height: 62),
                  ...children,
                ],
              ),
            ),
          ),
        ],
      ),
    );
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

class _CompletionCodeSheet extends StatefulWidget {
  final Future<ApiResponse<dynamic>> Function(String code) onSubmit;

  const _CompletionCodeSheet({required this.onSubmit});

  @override
  State<_CompletionCodeSheet> createState() => _CompletionCodeSheetState();
}

class _CompletionCodeSheetState extends State<_CompletionCodeSheet> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _controller.text.trim();
    if (code.length != 4) {
      setState(() => _error = 'اكتب الكود كامل من 4 أرقام');
      return;
    }

    final navigator = Navigator.of(context);
    final res = await widget.onSubmit(code);
    if (!mounted) return;

    if (res.isOk) {
      navigator.pop(true);
    } else {
      setState(() => _error = res.error ?? 'تعذر إنهاء المهمة');
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      children: [
        const Text('إنهاء المهمة', textAlign: TextAlign.center, style: _titleStyle),
        const SizedBox(height: 4),
        const Text('اكتب الكود اللي مع الموكل', textAlign: TextAlign.center, style: _subtitleStyle),
        const SizedBox(height: 16),
        TextField(
          controller: _controller,
          autofocus: true,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(4),
          ],
          style: const TextStyle(
            fontFamily: 'AppFont',
            fontFamilyFallback: appFontFallback,
            fontSize: 26,
            letterSpacing: 10,
            fontWeight: FontWeight.w900,
            color: AppColors.dark,
          ),
        ),
        const SizedBox(height: 12),
        _ErrorText(_error),
        AppButton.primary(text: 'إنهاء المهمة', onPressed: _submit),
      ],
    );
  }
}

class _TextActionSheet extends StatefulWidget {
  final String title;
  final String subtitle;
  final String hint;
  final String buttonText;
  final Future<ApiResponse<dynamic>> Function(String text) onSubmit;

  const _TextActionSheet({
    required this.title,
    required this.subtitle,
    required this.hint,
    required this.buttonText,
    required this.onSubmit,
  });

  @override
  State<_TextActionSheet> createState() => _TextActionSheetState();
}

class _TextActionSheetState extends State<_TextActionSheet> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.length < 10) {
      setState(() => _error = 'اكتب التفاصيل في 10 أحرف على الأقل');
      return;
    }

    final navigator = Navigator.of(context);
    final res = await widget.onSubmit(text);
    if (!mounted) return;

    if (res.isOk) {
      navigator.pop(true);
    } else {
      setState(() => _error = res.error ?? 'تعذر الإرسال، حاول مرة أخرى');
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      children: [
        Text(widget.title, textAlign: TextAlign.center, style: _titleStyle),
        const SizedBox(height: 4),
        Text(widget.subtitle, textAlign: TextAlign.center, style: _subtitleStyle),
        const SizedBox(height: 14),
        TextField(
          controller: _controller,
          maxLines: 4,
          maxLength: 2000,
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 14),
          decoration: InputDecoration(hintText: widget.hint, counterText: ''),
        ),
        const SizedBox(height: 12),
        _ErrorText(_error),
        AppButton.primary(text: widget.buttonText, onPressed: _submit),
      ],
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
    return _SheetFrame(
      children: [
        const Text('قيّم المحامي', textAlign: TextAlign.center, style: _titleStyle),
        const SizedBox(height: 4),
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
