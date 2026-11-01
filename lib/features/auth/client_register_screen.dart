import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_pressable.dart';
import '../../core/widgets/auth_hero_header.dart';
import '../../core/services/auth_service.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/password_strength_widget.dart';
import 'email_verification_screen.dart';

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
        _errorMessage = 'يرجى إدخال كلمة مرور قوية تحقق معايير الأمان قبل المتابعة.';
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
  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'الخطوة ${_currentStep + 1} من 3: ${_getStepTitle(_currentStep)}',
                style: const TextStyle(
                  fontFamily: 'AppFont',
                  fontFamilyFallback: appFontFallback,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.dark,
                ),
              ),
              Text(
                '${((_currentStep + 1) / 3 * 100).round()}%',
                style: const TextStyle(
                  fontFamily: 'AppFont',
                  fontFamilyFallback: appFontFallback,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(3, (index) {
              final isPassed = index <= _currentStep;
              return Expanded(
                child: Container(
                  height: 4.5,
                  margin: EdgeInsets.only(
                    left: index == 0 ? 4 : 0,
                    right: index == 2 ? 4 : (index == 0 ? 0 : 4),
                  ),
                  decoration: BoxDecoration(
                    color: isPassed ? AppColors.primary : AppColors.cardBorder,
                    borderRadius: BorderRadius.circular(7.0),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  /// الخطوة الأولى: البيانات الشخصية
  Widget _buildStep1PersonalData() {
    return Form(
      key: _step1FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [

          // 1. حقل الاسم الكامل
          _buildInputLabel('الاسم الكامل', isRequired: true),
          const SizedBox(height: 8),
          TextFormField(
            controller: _nameController,
            style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 14),
            textInputAction: TextInputAction.next,
            decoration: _inputDecoration(
              hintText: 'مثال: محمد أحمد علي',
              prefixIcon: Icons.person_outline_rounded,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'يرجى إدخال الاسم الكامل';
              }
              if (value.trim().split(' ').length < 2) {
                return 'يرجى إدخال الاسم ثنائياً على الأقل';
              }
              return null;
            },
          ),
          const SizedBox(height: 18),

          // 2. حقل رقم الهاتف المحمول
          _buildInputLabel('رقم الهاتف المحمول', isRequired: true),
          const SizedBox(height: 8),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            textInputAction: TextInputAction.done,
            style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 14),
            decoration: _inputDecoration(
              hintText: '01xxxxxxxxx',
              prefixIcon: Icons.phone_android_rounded,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'يرجى إدخال رقم الهاتف المحمول';
              }
              final clean = value.trim();
              if (!RegExp(r'^01[0125][0-9]{8}$').hasMatch(clean)) {
                return 'يرجى إدخال رقم هاتف محمول مصري صحيح مكون من 11 رقماً يبدأ بـ 01';
              }
              return null;
            },
          ),
          const SizedBox(height: 32),

          // زر المتابعة للخطوة التالية 24.0px
          AppButton.primary(
            text: 'بيانات الحساب',
            onPressed: _validateAndAdvanceStep1,
          ),
        ],
      ),
    );
  }

  /// الخطوة الثانية: بيانات الحساب
  Widget _buildStep2AccountData() {
    return Form(
      key: _step2FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [

          // 1. حقل البريد الإلكتروني
          _buildInputLabel('البريد الإلكتروني', isRequired: true),
          const SizedBox(height: 8),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textDirection: TextDirection.ltr,
            textInputAction: TextInputAction.next,
            style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 14),
            decoration: _inputDecoration(
              hintText: 'name@example.com',
              prefixIcon: Icons.mail_outline_rounded,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'يرجى إدخال البريد الإلكتروني لتفعيل الحساب';
              }
              final clean = value.trim();
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(clean)) {
                return 'يرجى إدخال بريد إلكتروني بصيغة صحيحة';
              }
              return null;
            },
          ),
          const SizedBox(height: 18),

          // 2. حقل كلمة المرور (مع شريط القوة فقط بدون شارات أو تأكيد)
          _buildInputLabel('كلمة المرور', isRequired: true),
          const SizedBox(height: 8),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textDirection: TextDirection.ltr,
            style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 14),
            decoration: _inputDecoration(
              hintText: 'أدخل كلمة مرور قوية',
              prefixIcon: Icons.lock_outline_rounded,
              suffixWidget: AppPressable(
                child: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: AppColors.textMuted,
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'يرجى إدخال كلمة المرور';
              }
              if (value.length < 8) {
                return 'كلمة المرور يجب ألا تقل عن 8 خانات';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),

          // شريط قوة كلمة المرور فقط دون أي شارات
          PasswordStrengthWidget(strength: _passwordStrength),
          const SizedBox(height: 32),

          // أزرار التنقل (السابق + التالي)
          Row(
            children: [
              Expanded(
                flex: 4,
                child: AppPressable(
                  child: OutlinedButton(
                  onPressed: _goToPreviousStep,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.cardBorder, width: 1.2),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24.0),
                    ),
                  ),
                  child: const Text(
                    'السابق',
                    style: TextStyle(
                      fontFamily: 'AppFont',
                      fontFamilyFallback: appFontFallback,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.dark,
                    ),
                  ),
                ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 6,
                child: AppButton.primary(
                  text: 'مراجعة البيانات',
                  onPressed: _validateAndAdvanceStep2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// الخطوة الثالثة: مراجعة وإرسال البيانات
  Widget _buildStep3ReviewAndSubmit() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [

        // بطاقة ملخص البيانات المدخلة
        AppCard(
          padding: const EdgeInsets.all(16.0),
          isDashed: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'ملخص بيانات الموكل',
                style: TextStyle(
                  fontFamily: 'AppFont',
                  fontFamilyFallback: appFontFallback,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: AppColors.dark,
                ),
              ),
              const SizedBox(height: 14),

              _buildSummaryItem(
                label: 'الاسم الكامل:',
                value: _nameController.text.trim(),
                icon: Icons.person_rounded,
                onEdit: () => setState(() => _currentStep = 0),
              ),
              const Divider(height: 20, color: AppColors.cardBorder),

              _buildSummaryItem(
                label: 'رقم الهاتف المحمول:',
                value: _phoneController.text.trim(),
                icon: Icons.phone_android_rounded,
                isLtr: true,
                onEdit: () => setState(() => _currentStep = 0),
              ),
              const Divider(height: 20, color: AppColors.cardBorder),

              _buildSummaryItem(
                label: 'البريد الإلكتروني:',
                value: _emailController.text.trim(),
                icon: Icons.mail_rounded,
                isLtr: true,
                onEdit: () => setState(() => _currentStep = 1),
              ),
              const Divider(height: 20, color: AppColors.cardBorder),

              _buildSummaryItem(
                label: 'كلمة المرور:',
                value: '•••••••• (محمية ومطابقة للشروط)',
                icon: Icons.lock_rounded,
                onEdit: () => setState(() => _currentStep = 1),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // أزرار التنقل والإرسال
        Row(
          children: [
            Expanded(
              flex: 4,
              child: AppPressable(
                child: OutlinedButton(
                onPressed: _isLoading ? null : _goToPreviousStep,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.cardBorder, width: 1.2),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24.0),
                  ),
                ),
                child: const Text(
                  'السابق',
                  style: TextStyle(
                    fontFamily: 'AppFont',
                    fontFamilyFallback: appFontFallback,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.dark,
                  ),
                ),
              ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 6,
              child: AppButton.primary(
                text: 'إنشاء الحساب والمتابعة',
                isLoading: _isLoading,
                onPressed: _isLoading ? null : _handleRegister,
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),
        const Center(
          child: Text(
            'بالتسجيل فإنك توافق على شروط الخدمة وسياسة الخصوصية الخاصة بـ My Lawyer',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'AppFont',
              fontFamilyFallback: appFontFallback,
              fontSize: 11,
              color: AppColors.textMuted,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryItem({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onEdit,
    bool isLtr = false,
  }) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'AppFont',
                  fontFamilyFallback: appFontFallback,
                  fontSize: 11,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                textDirection: isLtr ? TextDirection.ltr : null,
                style: const TextStyle(
                  fontFamily: 'AppFont',
                  fontFamilyFallback: appFontFallback,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.dark,
                ),
              ),
            ],
          ),
        ),
        AppPressable(
          child: IconButton(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
          tooltip: 'تعديل',
        ),
        ),
      ],
    );
  }

  Widget _buildInputLabel(String label, {bool isRequired = false}) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'AppFont',
            fontFamilyFallback: appFontFallback,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.dark,
          ),
        ),
        if (isRequired) ...[
          const SizedBox(width: 4),
          const Text(
            '*',
            style: TextStyle(
              color: AppColors.danger,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
        ],
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixWidget,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        fontFamily: 'AppFont',
        fontFamilyFallback: appFontFallback,
        fontSize: 13,
        color: AppColors.textMuted,
      ),
      prefixIcon: Icon(prefixIcon, color: AppColors.textMuted, size: 20),
      suffixIcon: suffixWidget,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 15.0),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.0),
        borderSide: const BorderSide(color: AppColors.cardBorder, width: 1.0),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.0),
        borderSide: const BorderSide(color: AppColors.cardBorder, width: 1.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.0),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.0),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.0),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.0),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.4),
      ),
    );
  }
}
