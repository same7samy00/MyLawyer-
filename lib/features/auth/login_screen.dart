import '../../core/services/biometric_service.dart';
import '../../core/widgets/app_loader.dart';
import 'biometric_setup_screen.dart';
import '../../core/widgets/line_illustration.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_pressable.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/auth_service.dart';
import 'email_verification_screen.dart';
import 'forgot_password_screen.dart';
import 'account_suspended_screen.dart';
import 'session_router.dart';
import 'user_type_selection_screen.dart';

class LoginScreen extends StatefulWidget {
  /// رسالة توضيحية عند الوصول لهذه الشاشة بسبب انتهاء الجلسة أو إيقاف الحساب
  final String? initialMessage;

  const LoginScreen({super.key, this.initialMessage});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _rememberMe = true;
  bool _phoneLocked = false;
  String? _errorMessage;
  String? _infoMessage;

  @override
  void initState() {
    super.initState();
    _errorMessage = widget.initialMessage;
    _loadSavedPhone();
    _loadBiometric();
  }

  bool _biometricReady = false;
  bool _isBiometricBusy = false;

  /// لو البصمة متفعلة: الزرار يظهر، وطلب البصمة يفتح لوحده أول ما الصفحة تفتح
  Future<void> _loadBiometric() async {
    final ready = await BiometricService.isEnabled();
    if (!mounted || !ready) return;
    setState(() => _biometricReady = true);
    if (widget.initialMessage == null) _loginWithBiometric();
  }

  Future<void> _loginWithBiometric() async {
    if (_isBiometricBusy) return;
    setState(() {
      _isBiometricBusy = true;
      _errorMessage = null;
    });
    final saved = await BiometricService.unlock();
    if (!mounted) return;
    if (saved == null) {
      setState(() => _isBiometricBusy = false);
      return;
    }
    await _loginWith(saved.identifier, saved.password, fromBiometric: true);
    if (mounted) setState(() => _isBiometricBusy = false);
  }

  Future<void> _loadSavedPhone() async {
    final phone = await AuthService.savedLoginPhone();
    if (phone == null || phone.isEmpty || !mounted) return;
    setState(() {
      _phoneController.text = phone;
      _phoneLocked = true;
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() {
      _errorMessage = null;
      _infoMessage = null;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    await _loginWith(_phoneController.text.trim(), _passwordController.text.trim());
  }

  Future<void> _loginWith(String identifier, String password, {bool fromBiometric = false}) async {
    final navigator = Navigator.of(context);

    final result = await AuthService.loginUser(
      identifier: identifier,
      password: password,
      rememberMe: _rememberMe,
    );

    if (!mounted) return;

    if (result.success) {
      if (!fromBiometric) {
        // الباسورد اتغير والبصمة متفعلة لنفس الحساب: نحدّث المحفوظ من غير ما نسأل
        if (await BiometricService.enabledIdentifier() == identifier) {
          await BiometricService.disable();
          await BiometricService.enableSilently(identifier, password);
        } else if (await BiometricService.shouldOffer(identifier)) {
          await SessionRouter.replaceStack(
            navigator,
            BiometricSetupScreen(
              identifier: identifier,
              password: password,
              onDone: () => SessionRouter.openCurrentAccount(navigator),
            ),
          );
          return;
        }
      }
      // يبقى التحميل ظاهراً حتى تبدأ شاشة الحساب فلا يومض الزر قبل الانتقال
      await SessionRouter.openCurrentAccount(navigator);
      return;
    }

    if (result.accountStatus == 'suspended') {
      await SessionRouter.replaceStack(navigator, const AccountSuspendedScreen(hasSession: false));
      return;
    }

    if (result.accountStatus == 'pending_email_verification') {
      _openEmailVerification(result.data?['email']?.toString() ?? identifier, password);
      return;
    }

    setState(() {
      _errorMessage = fromBiometric
          ? '${result.message}\nلو غيرت الباسورد، ادخل بيه مرة وهنحدّث البصمة'
          : result.message;
    });
  }

  /// حساب لم يكمل تأكيد بريده: يستكمل التحقق بدل الوقوف عند رسالة خطأ
  void _openEmailVerification(String email, String password) {
    AuthService.resendVerificationCode(email);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EmailVerificationScreen(
          registrationData: RegistrationData(
            accountType: UserAccountType.client,
            fullName: '',
            phone: '',
            email: email,
            password: password,
          ),
        ),
      ),
    );
  }

  Future<void> _openForgotPassword() async {
    final message = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
    );
    if (message != null && mounted) {
      setState(() {
        _errorMessage = null;
        _infoMessage = message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Official Logo
                  SizedBox(
                    height: 190,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        // الخط يمتد خارج هامش المحتوى ليصل إلى حافتي الشاشة
                        const Positioned.fill(child: EdgeLine()),
                        Image.asset(
                          'assets/images/app_logo.png',
                          height: 110,
                          fit: BoxFit.contain,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const SizedBox(height: 6),
                  const Center(
                    child: Text(
                      'سجل دخولك برقم الهاتف',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'AppFont',
                        fontFamilyFallback: appFontFallback,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Error Message Banner (if any)
                  if (_errorMessage != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                fontFamily: 'AppFont',
                                fontFamilyFallback: appFontFallback,
                                color: AppColors.danger,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  if (_infoMessage != null) ...[
                    Text(
                      _infoMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'AppFont',
                        fontFamilyFallback: appFontFallback,
                        color: AppColors.success,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Phone Number Label
                  const Text(
                    'رقم الهاتف المحمول',
                    style: TextStyle(
                      fontFamily: 'AppFont',
                      fontFamilyFallback: appFontFallback,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.dark,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Egyptian Phone Input
                  TextFormField(
                    controller: _phoneController,
                    enabled: !_phoneLocked,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(
                      fontFamily: 'AppFont',
                      fontFamilyFallback: appFontFallback,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.dark,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'مثلاً: 01012345678',
                      prefixIcon: Icon(Icons.phone_android_rounded, color: AppColors.textMuted, size: 20),
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'يرجى إدخال رقم الهاتف المحمول';
                      }
                      if (value.trim().length < 10) {
                        return 'رقم الهاتف غير مكتمل، يرجى كتابته كاملاً';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),

                  // Password Label
                  const Text(
                    'كلمة المرور',
                    style: TextStyle(
                      fontFamily: 'AppFont',
                      fontFamilyFallback: appFontFallback,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.dark,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Password Input
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: const TextStyle(
                      fontFamily: 'AppFont',
                      fontFamilyFallback: appFontFallback,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.dark,
                    ),
                    decoration: InputDecoration(
                      hintText: 'أدخل كلمة المرور الخاصة بك',
                      prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.textMuted, size: 20),
                      suffixIcon: AppPressable(
                        child: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
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
                      if (value == null || value.trim().isEmpty) {
                        return 'يرجى إدخال كلمة المرور';
                      }
                      if (value.length < 6) {
                        return 'كلمة المرور يجب ألا تقل عن 6 خانات';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Remember Me & Forgot Password Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: _rememberMe,
                              activeColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(7.0), // Strictly 7.0px
                              ),
                              onChanged: (val) {
                                setState(() {
                                  _rememberMe = val ?? true;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'تذكر بياناتي على هذا الجهاز',
                            style: TextStyle(
                              fontFamily: 'AppFont',
                              fontFamilyFallback: appFontFallback,
                              fontSize: 13,
                              color: AppColors.darkSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      AppPressable(
                        child: TextButton(
                        onPressed: _openForgotPassword,
                        child: const Text(
                          'نسيت كلمة المرور؟',
                          style: TextStyle(
                            fontFamily: 'AppFont',
                            fontFamilyFallback: appFontFallback,
                            fontSize: 13,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),

                  // Submit Button
                  Row(
                    children: [
                      Expanded(
                        child: AppButton.primary(
                          text: 'تسجيل الدخول',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          onPressed: _handleLogin,
                        ),
                      ),
                      if (_biometricReady) ...[
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 50,
                          height: 50,
                          child: Material(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(12.0),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12.0),
                              onTap: _isBiometricBusy ? null : _loginWithBiometric,
                              child: Center(
                                child: _isBiometricBusy
                                    ? const AppLoader.inline(size: 22)
                                    : const Icon(Icons.fingerprint_rounded, color: AppColors.primary, size: 30),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 32),

                  // رابط إنشاء حساب جديد
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'ليس لديك حساب بعد؟',
                        style: TextStyle(
                          fontFamily: 'AppFont',
                          fontFamilyFallback: appFontFallback,
                          fontSize: 14,
                          color: AppColors.textMain,
                        ),
                      ),
                      AppPressable(
                        child: TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const UserTypeSelectionScreen(),
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          overlayColor: Colors.transparent,
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                        ),
                        child: const Text(
                          'إنشاء حساب جديد',
                          style: TextStyle(
                            fontFamily: 'AppFont',
                            fontFamilyFallback: appFontFallback,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Safety Privacy Assurance Text (Without Container)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.security_rounded, color: AppColors.textMuted, size: 31),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'بياناتك وموقعك في أمان تام ومحمية\nبأعلى معايير التشفير والخصوصية وفقاً للقانون',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'AppFont',
                              fontFamilyFallback: appFontFallback,
                              fontSize: 11,
                              height: 1.4,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
