import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/auth_service.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_pressable.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/auth_hero_header.dart';
import '../../core/widgets/password_strength_widget.dart';
import 'email_verification_screen.dart';

part 'lawyer_register_documents.dart';
part 'lawyer_register_review.dart';
part 'lawyer_register_steps.dart';

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
  final _experienceController = TextEditingController();
  final _passwordController = TextEditingController();

  final ImagePicker _imagePicker = ImagePicker();
  String? _syndicateCardPath;
  String? _profilePhotoPath;
  bool _isPickingPhoto = false;

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
    _experienceController.dispose();
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
        return 'أرفق صورتك الشخصية وصورة واضحة للكارنيه\nالإدارة بتراجعهم قبل الاعتماد';
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
          if (_isPickingPhoto) {
            _profilePhotoPath = pickedFile.path;
          } else {
            _syndicateCardPath = pickedFile.path;
          }
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'تعذر اختيار الصورة، يرجى التحقق من أذونات الكاميرا والصور';
      });
    }
  }

  void _showImageSourceModal({bool forPhoto = false}) {
    _isPickingPhoto = forPhoto;
    AppSheet.show<void>(
      context,
      builder: (context) {
        return AppSheet(
              title: _isPickingPhoto ? 'إرفاق صورتك الشخصية' : 'إرفاق صورة كارنيه نقابة المحامين',
              children: [
                Text(
                  _isPickingPhoto
                      ? 'صورة واضحة لوشك، وهتظهر للموكلين في ملفك'
                      : 'يرجى التأكد من وضوح الصورة وظهور كافة البيانات ورقم القيد جلياً',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
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
        );
      },
    );
  }

  Future<void> _validateAndAdvanceStep1() async {
    setState(() => _errorMessage = null);
    if (_step1FormKey.currentState!.validate()) {
      final taken = await AuthService.takenMessage(phone: _phoneController.text);
      if (!mounted) return;
      if (taken != null) {
        setState(() => _errorMessage = taken);
        return;
      }
      setState(() => _currentStep = 1);
    }
  }

  Future<void> _validateAndAdvanceStep2() async {
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
    final taken = await AuthService.takenMessage(email: _emailController.text);
    if (!mounted) return;
    if (taken != null) {
      setState(() => _errorMessage = taken);
      return;
    }
    setState(() => _currentStep = 2);
  }

  void _validateAndAdvanceStep3() {
    setState(() => _errorMessage = null);
    if (_profilePhotoPath == null) {
      setState(() {
        _errorMessage = 'يرجى إرفاق صورتك الشخصية للمتابعة';
      });
      return;
    }
    if (_syndicateCardPath == null) {
      setState(() {
        _errorMessage = 'يرجى إرفاق صورة كارنيه نقابة المحامين للمتابعة';
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
      profilePhotoPath: _profilePhotoPath,
      experienceYears: int.tryParse(_experienceController.text.trim()),
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

  void _update(VoidCallback change) => setState(change);
}
