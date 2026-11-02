import 'package:flutter/material.dart';
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

/// نوافذ إجراءات الطلب: الشكوى، الاعتراض، والتقييم
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

  /// الشكوى اختيارين بس، والتفاصيل اختيارية
  static Future<bool> complaint(
    BuildContext context, {
    required Future<ApiResponse<dynamic>> Function(String kind, String details) onSubmit,
  }) {
    return _show(context, _ComplaintSheet(onSubmit: onSubmit));
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
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Stack(
        children: [
          const SheetLines(top: 16),
          SafeArea(
            top: false,
            child: Padding(
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

class _ComplaintSheet extends StatefulWidget {
  final Future<ApiResponse<dynamic>> Function(String kind, String details) onSubmit;

  const _ComplaintSheet({required this.onSubmit});

  @override
  State<_ComplaintSheet> createState() => _ComplaintSheetState();
}

class _ComplaintSheetState extends State<_ComplaintSheet> {
  static const _options = [
    ('MONEY', 'مشكلة في الفلوس', 'الفلوس بتتوقف لحد ما الإدارة تقرر', Icons.payments_rounded),
    ('BEHAVIOR', 'مشكلة في التعامل', 'الإدارة بتراجعها، والفلوس ما بتتأثرش', Icons.record_voice_over_rounded),
  ];

  final _controller = TextEditingController();
  String? _kind;
  String? _error;
  bool _isSending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_kind == null) {
      setState(() => _error = 'اختار نوع المشكلة');
      return;
    }

    setState(() => _isSending = true);
    final navigator = Navigator.of(context);
    final res = await widget.onSubmit(_kind!, _controller.text.trim());
    if (!mounted) return;

    if (res.isOk) {
      navigator.pop(true);
    } else {
      setState(() {
        _isSending = false;
        _error = res.error ?? 'تعذر الإرسال، حاول مرة أخرى';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      children: [
        const Text('عندك مشكلة؟', textAlign: TextAlign.center, style: _titleStyle),
        const SizedBox(height: 4),
        const Text('اختار نوع المشكلة والإدارة هتراجعها', textAlign: TextAlign.center, style: _subtitleStyle),
        const SizedBox(height: 16),
        for (final (kind, title, note, icon) in _options) ...[
          AppPressable(
            child: InkWell(
              borderRadius: BorderRadius.circular(7.0),
              onTap: () => setState(() {
                _kind = kind;
                _error = null;
              }),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _kind == kind ? AppColors.primaryLight : Colors.white,
                  borderRadius: BorderRadius.circular(7.0),
                  border: Border.all(color: _kind == kind ? AppColors.primary : AppColors.cardBorder, width: 1.2),
                ),
                child: Row(
                  children: [
                    Icon(icon, color: AppColors.primary, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: _optionTitleStyle),
                          const SizedBox(height: 2),
                          Text(note, style: _subtitleStyle),
                        ],
                      ),
                    ),
                    Icon(
                      _kind == kind ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                      color: _kind == kind ? AppColors.primary : AppColors.textMuted,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        TextField(
          controller: _controller,
          maxLines: 2,
          maxLength: 300,
          decoration: const InputDecoration(hintText: 'تفاصيل إضافية لو حابب (اختياري)'),
        ),
        const SizedBox(height: 4),
        _ErrorText(_error),
        AppButton.primary(text: 'إرسال الشكوى', onPressed: _isSending ? null : _submit),
      ],
    );
  }

  static const TextStyle _optionTitleStyle = TextStyle(
    fontFamily: 'AppFont',
    fontFamilyFallback: appFontFallback,
    fontSize: 14,
    fontWeight: FontWeight.w800,
    color: AppColors.dark,
  );
}
