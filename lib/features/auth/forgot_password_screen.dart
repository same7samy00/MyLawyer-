import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/auth_service.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_pressable.dart';
import '../../core/widgets/password_strength_widget.dart';

/// استعادة كلمة المرور: طلب رمز على البريد ثم تعيين كلمة مرور جديدة
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isCodeSent = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  String? _infoMessage;
  PasswordStrength _passwordStrength = AuthService.evaluatePasswordStrength('');

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_onPasswordChanged);
  }

  @override
  void dispose() {
    _passwordController.removeListener(_onPasswordChanged);
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onPasswordChanged() {
    setState(() {
      _passwordStrength = AuthService.evaluatePasswordStrength(_passwordController.text);
    });
  }

  void _handleBack() {
    if (_isCodeSent) {
      setState(() {
        _isCodeSent = false;
        _errorMessage = null;
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _sendCode() async {
    setState(() {
      _errorMessage = null;
      _infoMessage = null;
    });
    if (!_emailFormKey.currentState!.validate()) return;

    final result = await AuthService.requestPasswordReset(_emailController.text);
    if (!mounted) return;

    setState(() {
      if (result.success) {
        _isCodeSent = true;
        _infoMessage = result.message;
      } else {
        _errorMessage = result.message;
      }
    });
  }

  Future<void> _resetPassword() async {
    setState(() {
      _errorMessage = null;
      _infoMessage = null;
    });
    if (!_resetFormKey.currentState!.validate()) return;

    if (!_passwordStrength.isValidMin) {
      setState(() {
        _errorMessage = 'يرجى إدخال كلمة مرور قوية تحقق معايير الأمان قبل المتابعة';
      });
      return;
    }

    final result = await AuthService.resetPassword(
      email: _emailController.text,
      code: _codeController.text,
      newPassword: _passwordController.text,
    );
    if (!mounted) return;

    if (result.success) {
      Navigator.of(context).pop(result.message);
    } else {
      setState(() => _errorMessage = result.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isCodeSent,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                child: Row(
                  children: [
                    AppPressable(
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_rounded, color: AppColors.dark),
                        onPressed: _handleBack,
                        tooltip: 'رجوع',
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'استعادة كلمة المرور',
                      style: TextStyle(
                        fontFamily: 'AppFont',
                        fontFamilyFallback: appFontFallback,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.dark,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_errorMessage != null) ...[
                        _buildNotice(_errorMessage!, AppColors.danger, Icons.error_outline_rounded),
                        const SizedBox(height: 12),
                      ],
                      if (_infoMessage != null) ...[
                        _buildNotice(_infoMessage!, AppColors.success, Icons.check_circle_outline_rounded),
                        const SizedBox(height: 12),
                      ],
                      if (_isCodeSent) _buildResetForm() else _buildEmailForm(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotice(String text, Color color, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'AppFont',
              fontFamilyFallback: appFontFallback,
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmailForm() {
    return Form(
      key: _emailFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'اكتب البريد الإلكتروني المسجل في حسابك وهنبعتلك رمز لتعيين كلمة مرور جديدة',
            style: TextStyle(
              fontFamily: 'AppFont',
              fontFamilyFallback: appFontFallback,
              fontSize: 13,
              height: 1.5,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(
              hintText: 'البريد الإلكتروني',
              prefixIcon: Icon(Icons.alternate_email_rounded, color: AppColors.textMuted, size: 20),
            ),
            validator: (value) {
              final email = value?.trim() ?? '';
              if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                return 'يرجى إدخال بريد إلكتروني صحيح';
              }
              return null;
            },
          ),
          const SizedBox(height: 22),
          AppButton.primary(
            text: 'إرسال رمز الاستعادة',
            onPressed: _sendCode,
          ),
        ],
      ),
    );
  }

  Widget _buildResetForm() {
    return Form(
      key: _resetFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(
              hintText: 'رمز التحقق المكون من 6 أرقام',
              counterText: '',
              prefixIcon: Icon(Icons.pin_rounded, color: AppColors.textMuted, size: 20),
            ),
            validator: (value) {
              if (value == null || value.trim().length != 6) {
                return 'يرجى إدخال رمز التحقق كاملاً';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              hintText: 'كلمة المرور الجديدة',
              prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.textMuted, size: 20),
              suffixIcon: AppPressable(
                child: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
            validator: (value) {
              if (value == null || value.length < 8) {
                return 'كلمة المرور يجب ألا تقل عن 8 أحرف';
              }
              return null;
            },
          ),
          const SizedBox(height: 10),
          PasswordStrengthWidget(strength: _passwordStrength),
          const SizedBox(height: 22),
          AppButton.primary(
            text: 'تعيين كلمة المرور',
            onPressed: _resetPassword,
          ),
        ],
      ),
    );
  }
}
