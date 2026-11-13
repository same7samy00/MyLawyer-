import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/auth_service.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/app_pressable.dart';
import '../../core/widgets/auth_hero_header.dart';
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

  // خانة واحدة مخفية بتستقبل الرمز كله، والست مربعات للعرض بس.
  // كده الكيبورد بيفضل مفتوح ثابت وانت بتكتب، واللصق بيشتغل من غير رسايل
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _codeFocus = FocusNode();

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
    _codeController.dispose();
    _codeFocus.dispose();
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
    return _codeController.text;
  }

  void _setCode(String rawText) {
    final digits = rawText.replaceAll(RegExp(r'\D'), '');
    final code = digits.length > _codeLength ? digits.substring(0, _codeLength) : digits;
    _codeController.value = TextEditingValue(text: code, selection: TextSelection.collapsed(offset: code.length));
    _onCodeChanged(code);
  }

  /// زر اللصق: الرمز بيتحط في المربعات على طول من غير أي رسالة
  Future<void> _pasteFromClipboard() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    final text = clipboardData?.text ?? '';
    if (text.replaceAll(RegExp(r'\D'), '').isEmpty) return;
    _setCode(text);
  }

  void _onCodeChanged(String value) {
    if (_errorMessage != null) setState(() => _errorMessage = null);
    setState(() {});
    if (value.length == _codeLength) _codeFocus.unfocus();
  }

  Future<void> _handleVerify() async {
    setState(() {
      _errorMessage = null;
      _successNotification = null;
    });

    final code = _currentCode.trim();
    if (code.length < _codeLength) {
      setState(() {
        _errorMessage = 'يرجى إدخال كافة خانات رمز التحقق (6 أرقام)';
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
        message: 'تم تفعيل حسابك بنجاح، يرجى تسجيل الدخول للمتابعة',
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
      _codeController.clear();
      _codeFocus.requestFocus();
      _startCooldownTimer();
    } else {
      setState(() {
        _errorMessage = result.message;
      });
    }
  }

  Widget _buildCodeBoxes() {
    final code = _codeController.text;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _codeFocus.requestFocus(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // الخانة الحقيقية شفافة فوق المربعات
          Opacity(
            opacity: 0,
            child: SizedBox(
              height: 52,
              child: TextField(
                controller: _codeController,
                focusNode: _codeFocus,
                autofocus: true,
                keyboardType: TextInputType.number,
                maxLength: _codeLength,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                showCursor: false,
                enableInteractiveSelection: false,
                decoration: const InputDecoration(counterText: '', border: InputBorder.none),
                onChanged: (value) => _onCodeChanged(value),
              ),
            ),
          ),
          IgnorePointer(
            child: ListenableBuilder(
              listenable: _codeFocus,
              builder: (context, _) => Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_codeLength, (index) {
                  final active = _codeFocus.hasFocus && (index == code.length || (index == _codeLength - 1 && code.length == _codeLength));
                  return Container(
                    width: 44,
                    height: 52,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(7.0),
                      border: Border.all(color: active ? AppColors.primary : AppColors.cardBorder, width: active ? 2.0 : 1.2),
                    ),
                    child: Text(
                      index < code.length ? code[index] : '',
                      style: const TextStyle(
                        fontFamily: 'AppFont',
                        fontFamilyFallback: appFontFallback,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.dark,
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
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
                      child: _buildCodeBoxes(),
                    ),

                    const SizedBox(height: 14),

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
                            borderRadius: BorderRadius.circular(7.0),
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
                                borderRadius: BorderRadius.circular(7.0),
                              ),
                            ),
                            child: _isResending
                                ? const AppLoader.inline(size: 16)
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
