import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_pressable.dart';
import '../../core/widgets/auth_hero_header.dart';
import '../../core/services/auth_service.dart';
import '../../core/widgets/app_button.dart';
import 'registration_success_screen.dart';
import 'session_router.dart';

/// شاشة التحقق من البريد الإلكتروني عبر رمز مكون من 6 أرقام
class EmailVerificationScreen extends StatefulWidget {
  final RegistrationData registrationData;

  const EmailVerificationScreen({
    super.key,
    required this.registrationData,
  });

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  static const int _codeLength = 6;
  static const int _resendCooldownSeconds = 60;

  final List<TextEditingController> _controllers = List.generate(
    _codeLength,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(
    _codeLength,
    (_) => FocusNode(),
  );

  int _secondsRemaining = _resendCooldownSeconds;
  Timer? _countdownTimer;
  bool _canResend = false;
  bool _isLoading = false;
  bool _isResending = false;
  String? _errorMessage;
  String? _successNotification;

  @override
  void initState() {
    super.initState();
    _startCooldownTimer();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startCooldownTimer() {
    _countdownTimer?.cancel();
    setState(() {
      _secondsRemaining = _resendCooldownSeconds;
      _canResend = false;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsRemaining <= 1) {
        timer.cancel();
        setState(() {
          _secondsRemaining = 0;
          _canResend = true;
        });
      } else {
        setState(() {
          _secondsRemaining--;
        });
      }
    });
  }

  String _formatTimer(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  String get _currentCode {
    return _controllers.map((c) => c.text).join();
  }

  /// توزيع رمز ملصوق من الحافظة عبر الخانات الست بالتوالي
  void _distributePastedCode(String rawText) {
    // تصفية الأرقام فقط
    final digits = rawText.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return;

    final lengthToFill = digits.length < _codeLength ? digits.length : _codeLength;
    for (int i = 0; i < lengthToFill; i++) {
      _controllers[i].text = digits[i];
    }

    // نقل التركيز لآخر خانة ممتلئة أو الأولى الفارغة
    if (lengthToFill < _codeLength) {
      _focusNodes[lengthToFill].requestFocus();
    } else {
      _focusNodes[_codeLength - 1].unfocus();
    }

    setState(() {
      _errorMessage = null;
      _successNotification = 'تم لصق الرمز بنجاح من الحافظة';
    });
  }

  /// زر قراءة ولصق محتوى الحافظة مباشرة
  Future<void> _pasteFromClipboard() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData != null && clipboardData.text != null && clipboardData.text!.isNotEmpty) {
      _distributePastedCode(clipboardData.text!);
    } else {
      setState(() {
        _errorMessage = 'الحافظة فارغة أو لا تحتوي على رمز صالح.';
      });
    }
  }

  /// معالجة إدخال خانة فردية مع التنقل التلقائي
  void _onDigitChanged(int index, String value) {
    setState(() {
      _errorMessage = null;
    });

    // حالة اللصق المباشر في الخانة
    if (value.length > 1) {
      _distributePastedCode(value);
      return;
    }

    if (value.isNotEmpty) {
      // نقل التركيز للخانة التالية
      if (index < _codeLength - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }
    }
  }

  Future<void> _handleVerify() async {
    setState(() {
      _errorMessage = null;
      _successNotification = null;
    });

    final code = _currentCode.trim();
    if (code.length < _codeLength) {
      setState(() {
        _errorMessage = 'يرجى إدخال كافة خانات رمز التحقق (6 أرقام).';
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final navigator = Navigator.of(context);
    final result = await AuthService.verifyEmailCode(
      registration: widget.registrationData,
      inputCode: code,
    );

    if (!mounted) return;

    if (!result.success) {
      setState(() {
        _isLoading = false;
        _errorMessage = result.message;
      });
      return;
    }

    if (result.data?['sessionOpened'] == true) {
      await SessionRouter.replaceStack(
        navigator,
        RegistrationSuccessScreen(registrationData: widget.registrationData),
      );
    } else {
      await SessionRouter.toLogin(
        navigator,
        message: 'تم تفعيل حسابك بنجاح، يرجى تسجيل الدخول للمتابعة.',
      );
    }
  }

  Future<void> _handleResend() async {
    if (!_canResend || _isResending) return;

    setState(() {
      _isResending = true;
      _errorMessage = null;
      _successNotification = null;
    });

    final result = await AuthService.resendVerificationCode(widget.registrationData.email);

    if (!mounted) return;

    setState(() {
      _isResending = false;
    });

    if (result.success) {
      setState(() {
        _successNotification = result.message;
      });
      // مسح الخانات وإعادة التركيز للأولى
      for (final c in _controllers) {
        c.clear();
      }
      _focusNodes[0].requestFocus();
      _startCooldownTimer();
    } else {
      setState(() {
        _errorMessage = result.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        // الرسمة تتحرك مع المحتوى حتى تبقى الحقول ظاهرة فوق لوحة المفاتيح
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            AuthHeroHeader(
              title: 'أدخــل رمز التحقــق',
              icon: Icons.mark_email_read_rounded,
              onBack: () => Navigator.of(context).pop(),
            ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // عرض البريد الإلكتروني الذي تم الإرسال إليه
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text.rich(
                        TextSpan(
                          style: const TextStyle(
                            fontFamily: 'AppFont',
                            fontFamilyFallback: appFontFallback,
                            fontSize: 13,
                            color: AppColors.textMain,
                            height: 1.5,
                          ),
                          children: [
                            const TextSpan(text: 'أرسلنا رمز تحقق مكون من 6 أرقام\nإلى بريدك الإلكتروني:\n'),
                            TextSpan(
                              text: widget.registrationData.email,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                                fontFamily: 'AppFont',
                                fontFamilyFallback: appFontFallback,
                              ),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // رسالة نجاح أو إشعار
                    if (_successNotification != null) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _successNotification!,
                                style: const TextStyle(
                                  fontFamily: 'AppFont',
                                  fontFamilyFallback: appFontFallback,
                                  fontSize: 12,
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // رسالة خطأ إن وجدت
                    if (_errorMessage != null) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  fontFamily: 'AppFont',
                                  fontFamilyFallback: appFontFallback,
                                  fontSize: 12,
                                  color: AppColors.danger,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // خانات إدخال الرمز الست بالتوالي
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_codeLength, (index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                            child: SizedBox(
                              width: 44,
                              height: 52,
                              child: KeyboardListener(
                                focusNode: FocusNode(),
                                onKeyEvent: (event) {
                                  if (event is KeyDownEvent &&
                                      event.logicalKey == LogicalKeyboardKey.backspace) {
                                    if (_controllers[index].text.isEmpty && index > 0) {
                                      _focusNodes[index - 1].requestFocus();
                                      _controllers[index - 1].clear();
                                    }
                                  }
                                },
                                child: TextFormField(
                                  controller: _controllers[index],
                                  focusNode: _focusNodes[index],
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  maxLength: 1,
                                  style: const TextStyle(
                                    fontFamily: 'AppFont',
                                    fontFamilyFallback: appFontFallback,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.dark,
                                  ),
                                  decoration: InputDecoration(
                                    counterText: '',
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: EdgeInsets.zero,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(7.0),
                                      borderSide: const BorderSide(color: AppColors.cardBorder, width: 1.2),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(7.0),
                                      borderSide: const BorderSide(color: AppColors.cardBorder, width: 1.2),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(7.0),
                                      borderSide: const BorderSide(color: AppColors.primary, width: 2.0),
                                    ),
                                  ),
                                  onChanged: (val) => _onDigitChanged(index, val),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // زر لصق الرمز من الحافظة
                    Center(
                      child: AppPressable(
                        child: TextButton.icon(
                        onPressed: _pasteFromClipboard,
                        icon: const Icon(Icons.paste_rounded, size: 16, color: AppColors.primary),
                        label: const Text(
                          'لصق الرمز من الحافظة',
                          style: TextStyle(
                            fontFamily: 'AppFont',
                            fontFamilyFallback: appFontFallback,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        ),
                      ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // زر التحقق والتفعيل الموحد
                    AppButton.primary(
                      text: 'تأكيد الرمز والتفعيل',
                      isLoading: _isLoading,
                      onPressed: _isLoading ? null : _handleVerify,
                    ),

                    const SizedBox(height: 20),

                    // مؤقت وزر إعادة الإرسال
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (!_canResend) ...[
                          const Icon(Icons.timer_outlined, size: 16, color: AppColors.textMuted),
                          const SizedBox(width: 6),
                          Text(
                            'إعادة إرسال الرمز خلال ${_formatTimer(_secondsRemaining)}',
                            style: const TextStyle(
                              fontFamily: 'AppFont',
                              fontFamilyFallback: appFontFallback,
                              fontSize: 13,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ] else ...[
                          const Text(
                            'لم يصلك الرمز؟',
                            style: TextStyle(
                              fontFamily: 'AppFont',
                              fontFamilyFallback: appFontFallback,
                              fontSize: 13,
                              color: AppColors.textMuted,
                            ),
                          ),
                          AppPressable(
                            child: TextButton(
                            onPressed: _isResending ? null : _handleResend,
                            style: TextButton.styleFrom(
                              overlayColor: Colors.transparent,
                              foregroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                            ),
                            child: _isResending
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text(
                                    'إعادة إرسال الرمز الآن',
                                    style: TextStyle(
                                      fontFamily: 'AppFont',
                                      fontFamilyFallback: appFontFallback,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary,
                                    ),
                                  ),
                          ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
