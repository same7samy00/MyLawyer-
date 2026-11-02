import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_pressable.dart';
import '../../core/widgets/auth_hero_header.dart';
import '../../core/services/auth_service.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/password_strength_widget.dart';
import 'email_verification_screen.dart';
import 'specialty_picker_screen.dart';

/// شاشة إنشاء حساب محامي جديد بنظام متعدد الخطوات (Step-by-Step)
class LawyerRegisterScreen extends StatefulWidget {
  const LawyerRegisterScreen({super.key});

  @override
  State<LawyerRegisterScreen> createState() => _LawyerRegisterScreenState();
}

class _LawyerRegisterScreenState extends State<LawyerRegisterScreen> {
  final _step1FormKey = GlobalKey<FormState>();
  final _step2FormKey = GlobalKey<FormState>();

  int _currentStep = 0; // 0: بيانات مهنية, 1: بيانات الحساب, 2: مستندات, 3: مراجعة وإرسال

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _syndicateNumberController = TextEditingController();
  final _bioController = TextEditingController();
  String? _specialty;
  final _passwordController = TextEditingController();

  final ImagePicker _imagePicker = ImagePicker();
  String? _syndicateCardPath;

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
    _syndicateNumberController.dispose();
    _bioController.dispose();
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
        return 'انضم لشبكة المحامين المعتمدين\nويتم فحص بيانات القيد لضمان التوثيق';
      case 1:
        return 'حدد بريدك الإلكتروني وكلمة مرور آمنة\nللوصول لحسابك وإدارة قضاياك';
      case 2:
        return 'أرفق صورة واضحة لوجه الكارنيه النقابي\nساري المفعول للتحقق والاعتماد';
      default:
        return 'راجع بيانات ملفك المهني بعناية\nويمكنك تعديل أي خطوة من رمز التعديل';
    }
  }

  String _getStepTitle(int step) {
    switch (step) {
      case 0:
        return 'البيانات الشخصية والمهنية';
      case 1:
        return 'بيانات الحساب';
      case 2:
        return 'مستندات المحامي';
      case 3:
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

  Future<void> _pickSyndicateImage(ImageSource source) async {
    Navigator.of(context).pop(); // إغلاق البوتن شيت

    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );

      if (pickedFile != null) {
        setState(() {
          _syndicateCardPath = pickedFile.path;
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'تعذر اختيار الصورة، يرجى التحقق من أذونات الكاميرا والصور.';
      });
    }
  }

  void _showImageSourceModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.0)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.cardBorder,
                    borderRadius: BorderRadius.circular(2.0),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'إرفاق صورة كارنيه نقابة المحامين',
                  style: TextStyle(
                    fontFamily: 'AppFont',
                    fontFamilyFallback: appFontFallback,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.dark,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'يرجى التأكد من وضوح الصورة وظهور كافة البيانات ورقم القيد جلياً',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'AppFont',
                    fontFamilyFallback: appFontFallback,
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: AppPressable(
                        child: OutlinedButton.icon(
                        onPressed: () => _pickSyndicateImage(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_rounded, color: AppColors.primary, size: 20),
                        label: const Text(
                          'الكاميرا',
                          style: TextStyle(
                            fontFamily: 'AppFont',
                            fontFamilyFallback: appFontFallback,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.primary, width: 1.2),
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                        ),
                      ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: AppPressable(
                        child: ElevatedButton.icon(
                        onPressed: () => _pickSyndicateImage(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_rounded, color: Colors.white, size: 20),
                        label: const Text(
                          'معرض الصور',
                          style: TextStyle(
                            fontFamily: 'AppFont',
                            fontFamilyFallback: appFontFallback,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                        ),
                      ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickSpecialty(FormFieldState<String> field) async {
    final picked = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (context) => SpecialtyPickerScreen(selected: _specialty)),
    );
    if (picked == null || !mounted) return;

    setState(() => _specialty = picked);
    field.validate();
  }

  void _validateAndAdvanceStep1() {
    setState(() => _errorMessage = null);
    if (_step1FormKey.currentState!.validate()) {
      setState(() => _currentStep = 1);
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
    setState(() => _currentStep = 2);
  }

  void _validateAndAdvanceStep3() {
    setState(() => _errorMessage = null);
    if (_syndicateCardPath == null) {
      setState(() {
        _errorMessage = 'يرجى إرفاق صورة كارنيه نقابة المحامين للمتابعة.';
      });
      return;
    }
    setState(() => _currentStep = 3);
  }

  Future<void> _handleRegister() async {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    final regData = RegistrationData(
      accountType: UserAccountType.lawyer,
      fullName: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      syndicateNumber: _syndicateNumberController.text.trim(),
      syndicateCardPath: _syndicateCardPath,
      specialty: _specialty,
      bio: _bioController.text.trim(),
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
                title: 'إنشــاء حســاب محامي',
                description: _getStepDescription(_currentStep),
                onBack: _goToPreviousStep,
              ),

              // مؤشر تقدم الخطوات
              _buildProgressIndicator(),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // رسالة الخطأ إن وجدت
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

                      // محتوى الخطوة الحالية
                      if (_currentStep == 0) _buildStep1PersonalAndProfessionalData(),
                      if (_currentStep == 1) _buildStep2AccountData(),
                      if (_currentStep == 2) _buildStep3Documents(),
                      if (_currentStep == 3) _buildStep4ReviewAndSubmit(),
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

  /// مؤشر تقدم الخطوات المنظم (4 خطوات)
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
                'الخطوة ${_currentStep + 1} من 4: ${_getStepTitle(_currentStep)}',
                style: const TextStyle(
                  fontFamily: 'AppFont',
                  fontFamilyFallback: appFontFallback,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.dark,
                ),
              ),
              Text(
                '${((_currentStep + 1) / 4 * 100).round()}%',
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
            children: List.generate(4, (index) {
              final isPassed = index <= _currentStep;
              return Expanded(
                child: Container(
                  height: 4.5,
                  margin: EdgeInsets.only(
                    left: index == 0 ? 4 : 0,
                    right: index == 3 ? 4 : (index == 0 ? 0 : 4),
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

  /// الخطوة الأولى: البيانات الشخصية والمهنية
  Widget _buildStep1PersonalAndProfessionalData() {
    return Form(
      key: _step1FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [

          // 1. الاسم الرباعي
          _buildInputLabel('الاسم الرباعي (مطابق لكارنيه النقابة)', isRequired: true),
          const SizedBox(height: 8),
          TextFormField(
            controller: _nameController,
            style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 14),
            textInputAction: TextInputAction.next,
            decoration: _inputDecoration(
              hintText: 'مثال: أحمد محمود إبراهيم الشافعي',
              prefixIcon: Icons.badge_outlined,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'يرجى إدخال الاسم الرباعي كاملاً';
              }
              final parts = value.trim().split(RegExp(r'\s+'));
              if (parts.length < 3) {
                return 'يرجى إدخال الاسم ثلاثياً أو رباعياً على الأقل';
              }
              return null;
            },
          ),
          const SizedBox(height: 18),

          // 2. رقم الهاتف
          _buildInputLabel('رقم الهاتف المحمول', isRequired: true),
          const SizedBox(height: 8),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            textInputAction: TextInputAction.next,
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
                return 'يرجى إدخال رقم هاتف مصري صحيح مكون من 11 رقماً يبدأ بـ 01';
              }
              return null;
            },
          ),
          const SizedBox(height: 18),

          // 3. رقم القيد بالنقابة
          _buildInputLabel('رقم القيد بنقابة المحامين', isRequired: true),
          const SizedBox(height: 8),
          TextFormField(
            controller: _syndicateNumberController,
            keyboardType: TextInputType.number,
            textDirection: TextDirection.ltr,
            textInputAction: TextInputAction.done,
            style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 14),
            decoration: _inputDecoration(
              hintText: 'مثال: 582410',
              prefixIcon: Icons.verified_user_outlined,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'يرجى إدخال رقم القيد بالنقابة';
              }
              if (value.trim().length < 4) {
                return 'رقم القيد يجب أن يتكون من 4 أرقام على الأقل';
              }
              return null;
            },
          ),
          const SizedBox(height: 18),

          _buildInputLabel('التخصص', isRequired: true),
          const SizedBox(height: 8),
          FormField<String>(
            validator: (_) => _specialty == null ? 'اختار تخصصك' : null,
            builder: (field) => InputDecorator(
              decoration: _inputDecoration(
                hintText: 'اختار تخصصك',
                prefixIcon: Icons.policy_outlined,
              ).copyWith(errorText: field.errorText),
              child: InkWell(
                onTap: () => _pickSpecialty(field),
                child: Text(
                  _specialty ?? 'اختار تخصصك',
                  style: TextStyle(
                    fontFamily: 'AppFont',
                    fontFamilyFallback: appFontFallback,
                    fontSize: 14,
                    color: _specialty == null ? AppColors.textMuted : AppColors.dark,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),

          _buildInputLabel('نبذة تعريفية قصيرة'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _bioController,
            maxLength: 150,
            maxLines: 3,
            style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 14),
            decoration: _inputDecoration(
              hintText: 'اكتب سطرين عن خبرتك',
              prefixIcon: Icons.edit_note_rounded,
            ),
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

          // 1. البريد الإلكتروني
          _buildInputLabel('البريد الإلكتروني المهني', isRequired: true),
          const SizedBox(height: 8),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textDirection: TextDirection.ltr,
            textInputAction: TextInputAction.next,
            style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 14),
            decoration: _inputDecoration(
              hintText: 'lawyer@example.com',
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

          // 2. كلمة المرور
          _buildInputLabel('كلمة المرور', isRequired: true),
          const SizedBox(height: 8),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textDirection: TextDirection.ltr,
            style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 14),
            decoration: _inputDecoration(
              hintText: 'أدخل كلمة مرور قوية لحماية حسابك المهني',
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

          // شريط قوة كلمة المرور فقط دون شارات
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
                  text: 'مستندات المحامي',
                  onPressed: _validateAndAdvanceStep2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// الخطوة الثالثة: مستندات المحامي (إرفاق ومعاينة صورة كارنيه النقابة)
  Widget _buildStep3Documents() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildInputLabel('صورة كارنيه نقابة المحامين (ساري)', isRequired: true),
        const SizedBox(height: 14),

        if (_syndicateCardPath == null)
          AppCard(
            isDashed: true,
            padding: EdgeInsets.zero,
            onTap: _showImageSourceModal,
            child: Container(
              height: 160,
              alignment: Alignment.center,
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined, color: AppColors.primary, size: 36),
                  SizedBox(height: 10),
                  Text(
                    'اضغط هنا لالتقاط أو اختيار صورة الكارنيه',
                    style: TextStyle(
                      fontFamily: 'AppFont',
                      fontFamilyFallback: appFontFallback,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'صيغ JPG, PNG حتى 10 ميجابايت',
                    style: TextStyle(
                      fontFamily: 'AppFont',
                      fontFamilyFallback: appFontFallback,
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          AppCard(
            isDashed: true,
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14.0),
                  child: Image.file(
                    File(_syndicateCardPath!),
                    height: 190,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 190,
                      color: AppColors.background,
                      alignment: Alignment.center,
                      child: const Text('تعذر تحميل معاينة الصورة محلياً'),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AppPressable(
                        child: OutlinedButton.icon(
                        onPressed: _showImageSourceModal,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text(
                          'تغيير الصورة',
                          style: TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.primary, width: 1.2),
                          minimumSize: const Size(double.infinity, 44),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.0)),
                        ),
                      ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    AppPressable(
                      child: IconButton(
                      onPressed: () {
                        setState(() {
                          _syndicateCardPath = null;
                        });
                      },
                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                      tooltip: 'حذف الصورة',
                    ),
                    ),
                  ],
                ),
              ],
            ),
          ),

        const SizedBox(height: 32),

        // أزرار التنقل
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
                onPressed: _validateAndAdvanceStep3,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// الخطوة الرابعة: مراجعة وإرسال البيانات
  Widget _buildStep4ReviewAndSubmit() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [

        // بطاقة الملخص الشامل للمحامي
        AppCard(
          padding: const EdgeInsets.all(16.0),
          isDashed: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'ملخص ملف المحامي المهني',
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
                label: 'الاسم الرباعي (النقابي):',
                value: _nameController.text.trim(),
                icon: Icons.badge_outlined,
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
                label: 'رقم القيد بالنقابة:',
                value: _syndicateNumberController.text.trim(),
                icon: Icons.verified_user_outlined,
                isLtr: true,
                onEdit: () => setState(() => _currentStep = 0),
              ),
              const Divider(height: 20, color: AppColors.cardBorder),

              _buildSummaryItem(
                label: 'البريد الإلكتروني المهني:',
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
              const Divider(height: 20, color: AppColors.cardBorder),

              // مستند الكارنيه
              Row(
                children: [
                  const Icon(Icons.document_scanner_outlined, color: AppColors.primary, size: 18),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'صورة كارنيه النقابة:',
                      style: TextStyle(
                        fontFamily: 'AppFont',
                        fontFamilyFallback: appFontFallback,
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (_syndicateCardPath != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10.0),
                      child: Image.file(
                        File(_syndicateCardPath!),
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                      ),
                    ),
                  AppPressable(
                    child: IconButton(
                    onPressed: () => setState(() => _currentStep = 2),
                    icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                    tooltip: 'تعديل',
                  ),
                  ),
                ],
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
                text: 'إرسال طلب التسجيل',
                isLoading: _isLoading,
                onPressed: _isLoading ? null : _handleRegister,
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),
        const Center(
          child: Text(
            'بإرسال الطلب، فإنك تؤكد صحة كافة البيانات المقدمة وتوافق على ميثاق العمل المهني لـ My Lawyer',
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
