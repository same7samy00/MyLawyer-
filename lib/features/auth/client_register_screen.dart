import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_pressable.dart';
import '../../core/widgets/auth_hero_header.dart';
import '../../core/services/auth_service.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/password_strength_widget.dart';
import 'email_verification_screen.dart';
part 'client_register_steps.dart';

/// شاشة إنشاء حساب موكل جديد بنظام متعدد الخطوات (Step-by-Step)
class ClientRegisterScreen extends StatefulWidget {
  const ClientRegisterScreen({super.key});

  @override
  State<ClientRegisterScreen> createState() => _ClientRegisterScreenState();
}

class _ClientRegisterScreenState extends State<ClientRegisterScreen> {
  final _step1FormKey = GlobalKey<FormState>();
  final _step2FormKey = GlobalKey<FormState>();

  int _currentStep = 0; // 0: البيانات الشخصية, 1: بيانات الحساب, 2: مراجعة وإرسال

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;
  PasswordStrength _passwordStrength = const PasswordStrength(
    score: 0.0,
    label: 'أدخل كلمة المرور',
    hasMinLength: false,
    hasUppercase: false,
    hasLowercase: false,
    hasDigits: false,
    hasSpecialChars: false,
  );

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_onPasswordChanged);
  }

  @override
  void dispose() {
    _passwordController.removeListener(_onPasswordChanged);
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onPasswordChanged() {
    setState(() {
      _passwordStrength = AuthService.evaluatePasswordStrength(_passwordController.text);
    });
  }

  String _getStepDescription(int step) {
    switch (step) {
      case 0:
        return 'أدخل اسمك ورقم هاتفك للتواصل\nومتابعة استشاراتك وطلباتك القانونية';
      case 1:
        return 'حدد بريدك الإلكتروني وكلمة مرور آمنة\nلتسجيل الدخول وحماية خصوصيتك';
      default:
        return 'راجع بياناتك بدقة قبل تأكيد التسجيل\nويمكنك تعديل أي حقل بالضغط عليه';
    }
  }

  String _getStepTitle(int step) {
    switch (step) {
      case 0:
        return 'البيانات الشخصية';
      case 1:
        return 'بيانات الحساب';
      case 2:
        return 'مراجعة وإرسال البيانات';
      default:
        return '';
    }
  }

  void _goToPreviousStep() {
    if (_currentStep > 0) {
      setState(() {
        _errorMessage = null;
        _currentStep--;
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  void _validateAndAdvanceStep1() {
    setState(() => _errorMessage = null);
    if (_step1FormKey.currentState!.validate()) {
      setState(() {
        _currentStep = 1;
      });
    }
  }

  void _validateAndAdvanceStep2() {
    setState(() => _errorMessage = null);
    if (!_step2FormKey.currentState!.validate()) {
      return;
    }
    if (!_passwordStrength.isValidMin) {
      setState(() {
        _errorMessage = 'يرجى إدخال كلمة مرور قوية تحقق معايير الأمان قبل المتابعة';
      });
      return;
    }
    setState(() {
      _currentStep = 2;
    });
  }

  Future<void> _handleRegister() async {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    final regData = RegistrationData(
      accountType: UserAccountType.client,
      fullName: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    final result = await AuthService.registerUser(regData);

    if (!mounted) return;

    if (result.success) {
      // الاستبدال يمنع الرجوع لنموذج أُرسل بالفعل وإعادة إرساله
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => EmailVerificationScreen(
            registrationData: regData,
          ),
        ),
      );
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = result.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentStep == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _currentStep > 0) {
          _goToPreviousStep();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          // الرسمة تتحرك مع المحتوى حتى تبقى الحقول ظاهرة فوق لوحة المفاتيح
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              AuthHeroHeader(
                title: 'إنشــاء حســاب موكل',
                description: _getStepDescription(_currentStep),
                onBack: _goToPreviousStep,
              ),

              // شريط تقدم الخطوات المرئي
              _buildProgressIndicator(),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // رسالة الخطأ العامة إن وجدت
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

                      // محتوى الخطوة المحددة
                      if (_currentStep == 0) _buildStep1PersonalData(),
                      if (_currentStep == 1) _buildStep2AccountData(),
                      if (_currentStep == 2) _buildStep3ReviewAndSubmit(),
                    ],
                  ),
                ),
                ],
              ),
            ),
        ),
      ),
    );
  }

  /// مؤشر تقدم الخطوات المنظم

  void _update(VoidCallback change) => setState(change);
}
