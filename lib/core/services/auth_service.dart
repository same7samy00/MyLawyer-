import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'background_location_service.dart';
import 'order_store.dart';
import 'saved_data.dart';
import 'device_permission_service.dart';
import 'push_service.dart';

/// نوع الحساب في منصة My Lawyer
enum UserAccountType {
  client,
  lawyer,
}

/// نتيجة عمليات التحقق والمصادقة
class AuthResult {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;

  /// حالة الحساب القادمة من الخادم عند رفض الدخول (مثل انتظار تأكيد البريد)
  final String? accountStatus;

  const AuthResult({
    required this.success,
    required this.message,
    this.data,
    this.accountStatus,
  });
}

/// حالة الجلسة بعد التحقق منها، وتحدد الوجهة الصحيحة عند فتح التطبيق
enum SessionStatus {
  unauthenticated,
  expired,
  client,
  lawyerApproved,
  lawyerPending,
  lawyerRejected,
  accountBlocked,
  accountSuspended,
  serverUnreachable,
}

/// نتيجة فحص الجلسة مع رسالة توضيحية عند الحاجة
class SessionCheck {
  final SessionStatus status;
  final String? message;

  const SessionCheck(this.status, {this.message});
}

/// مقياس قوة كلمة المرور
class PasswordStrength {
  final double score; // من 0.0 إلى 1.0
  final String label;
  final bool hasMinLength;
  final bool hasUppercase;
  final bool hasLowercase;
  final bool hasDigits;
  final bool hasSpecialChars;

  const PasswordStrength({
    required this.score,
    required this.label,
    required this.hasMinLength,
    required this.hasUppercase,
    required this.hasLowercase,
    required this.hasDigits,
    required this.hasSpecialChars,
  });

  bool get isStrong => score >= 0.8 && hasMinLength && (hasUppercase || hasLowercase) && hasDigits;
  bool get isValidMin => score >= 0.5 && hasMinLength;
}

/// نموذج بيانات إنشاء الحساب الجديد
class RegistrationData {
  final UserAccountType accountType;
  final String fullName;
  final String phone;
  final String email;
  final String password;
  final String? syndicateNumber;
  final String? syndicateCardPath;
  final String? profilePhotoPath;
  final int? experienceYears;

  const RegistrationData({
    required this.accountType,
    required this.fullName,
    required this.phone,
    required this.email,
    required this.password,
    this.syndicateNumber,
    this.syndicateCardPath,
    this.profilePhotoPath,
    this.experienceYears,
  });

  String get firstName {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    return parts.isNotEmpty ? parts.first : fullName;
  }
}

/// خدمة إدارة المصادقة والتسجيل والتحقق من البريد في My Lawyer
class AuthService {
  static const String _prefAccountType = 'user_account_type';
  static const String _prefUserName = 'user_name';
  static const String _prefUserPhone = 'user_phone';
  static const String _prefLoginPhone = 'login_phone';
  static const String _prefUserEmail = 'user_email';
  static const String _prefSyndicateNumber = 'syndicate_number';
  static const String _prefSyndicateCardPath = 'syndicate_card_path';
  static const String _prefProfilePhotoPath = 'pending_profile_photo_path';
  static const String _prefIsEmailVerified = 'is_email_verified';
  static const String _prefApprovalStatus = 'lawyer_approval_status';
  static const String _prefUserStatus = 'user_account_status';

  /// تجزئة كلمة المرور بتقنية SHA-256 لضمان عدم حفظها بنص صريح إطلاقاً
  static String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// فحص وحساب قوة كلمة المرور وتحديد مدى مطابقتها للمعايير الصارمة
  static PasswordStrength evaluatePasswordStrength(String password) {
    if (password.isEmpty) {
      return const PasswordStrength(
        score: 0.0,
        label: 'أدخل كلمة المرور',
        hasMinLength: false,
        hasUppercase: false,
        hasLowercase: false,
        hasDigits: false,
        hasSpecialChars: false,
      );
    }

    final hasMinLength = password.length >= 8;
    final hasUppercase = password.contains(RegExp(r'[A-Z]'));
    final hasLowercase = password.contains(RegExp(r'[a-z]'));
    final hasDigits = password.contains(RegExp(r'[0-9]'));
    final hasSpecialChars = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=\\/\[\]~`]'));

    int criteriaMet = 0;
    if (hasMinLength) criteriaMet++;
    if (hasUppercase) criteriaMet++;
    if (hasLowercase) criteriaMet++;
    if (hasDigits) criteriaMet++;
    if (hasSpecialChars) criteriaMet++;

    double score;
    String label;

    if (criteriaMet <= 2) {
      score = 0.25;
      label = 'ضعيفة';
    } else if (criteriaMet == 3 || criteriaMet == 4) {
      score = 0.65;
      label = 'متوسطة';
    } else {
      score = 1.0;
      label = 'قوية';
    }

    return PasswordStrength(
      score: score,
      label: label,
      hasMinLength: hasMinLength,
      hasUppercase: hasUppercase,
      hasLowercase: hasLowercase,
      hasDigits: hasDigits,
      hasSpecialChars: hasSpecialChars,
    );
  }

  /// تسجيل الدخول الحقيقي برقم الهاتف أو البريد الإلكتروني وكلمة المرور
  static Future<AuthResult> loginUser({
    required String identifier,
    required String password,
    bool rememberMe = true,
  }) async {
    final res = await ApiService.post('/auth/login', {
      'identifier': identifier.trim(),
      'password': password,
      'rememberMe': rememberMe,
    });

    if (!res.isOk || res.data is! Map<String, dynamic>) {
      final failure = res.data is Map<String, dynamic> ? res.data as Map<String, dynamic> : null;
      return AuthResult(
        success: false,
        message: res.error ?? 'بيانات الدخول غير صحيحة، يرجى التأكد والمحاولة ثانية',
        data: failure,
        accountStatus: failure?['status']?.toString(),
      );
    }

    final data = res.data as Map<String, dynamic>;
    final accessToken = data['accessToken'] as String?;
    final refreshToken = data['refreshToken'] as String?;
    final user = data['user'] as Map<String, dynamic>?;

    if (accessToken == null || refreshToken == null || user == null) {
      return const AuthResult(
        success: false,
        message: 'تعذر إتمام تسجيل الدخول، يرجى المحاولة مرة أخرى',
      );
    }

    await ApiService.saveTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
      persist: rememberMe,
    );

    await _storeProfile(
      role: user['role']?.toString(),
      userStatus: user['status']?.toString(),
      approvalStatus: user['lawyerApprovalStatus']?.toString(),
      fullName: user['fullName']?.toString(),
      phone: user['phone']?.toString() ?? identifier,
      email: user['email']?.toString(),
    );

    // رقم القيد لا يعود مع استجابة الدخول، ولا يمنع فشل جلبه من إتمام الدخول
    await syncProfile();

    return AuthResult(
      success: true,
      message: res.message ?? 'تم تسجيل الدخول بنجاح',
      data: data,
    );
  }

  static Future<void> _storeProfile({
    String? role,
    String? userStatus,
    String? approvalStatus,
    String? fullName,
    String? phone,
    String? email,
    String? syndicateNumber,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (role != null) await prefs.setString(_prefAccountType, role.toLowerCase());
    if (userStatus != null) await prefs.setString(_prefUserStatus, userStatus);
    if (phone != null && phone.isNotEmpty) {
      await prefs.setString(_prefUserPhone, phone);
      await prefs.setString(_prefLoginPhone, phone);
    }
    if (email != null && email.isNotEmpty) await prefs.setString(_prefUserEmail, email);
    if (fullName != null && fullName.isNotEmpty) await prefs.setString(_prefUserName, fullName);
    if (syndicateNumber != null && syndicateNumber.isNotEmpty) {
      await prefs.setString(_prefSyndicateNumber, syndicateNumber);
    }
    if (approvalStatus != null && approvalStatus.isNotEmpty) {
      await prefs.setString(_prefApprovalStatus, approvalStatus);
    } else {
      await prefs.remove(_prefApprovalStatus);
    }
  }

  /// صورة المحامي والكارنيه المختارين وقت التسجيل يترفعوا أول ما يبقى فيه جلسة، ولو فشلوا يتحاولوا تاني من صفحة الخدمة
  static Future<void> uploadPendingDocuments() async {
    await _uploadPending(_prefSyndicateCardPath, '/lawyers/me/documents');
    await _uploadPending(_prefProfilePhotoPath, '/users/me/profile-photo');
  }

  static Future<void> _uploadPending(String key, String endpoint) async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(key);
    if (path == null) return;
    if (!File(path).existsSync()) {
      await prefs.remove(key);
      return;
    }

    final res = await ApiService.uploadFile(endpoint, path);
    if (res.isOk) await prefs.remove(key);
  }

  /// جلب الحساب الحالي من الخادم وتحديث نسخته المحلية
  static Future<ApiResponse<dynamic>> syncProfile({Duration timeout = const Duration(seconds: 8)}) async {
    final res = await ApiService.get('/users/me', timeout: timeout);
    if (res.isOk && res.data is Map<String, dynamic>) {
      final user = res.data as Map<String, dynamic>;
      await _storeProfile(
        role: user['role']?.toString(),
        userStatus: user['status']?.toString(),
        approvalStatus: user['approvalStatus']?.toString(),
        fullName: user['fullName']?.toString(),
        phone: user['phone']?.toString(),
        email: user['email']?.toString(),
        syndicateNumber: user['syndicateNumber']?.toString(),
      );
    }
    return res;
  }

  /// فحص الجلسة المحفوظة مع الخادم عند فتح التطبيق
  /// لا تُمسح الجلسة إلا عند ثبوت انتهائها، أما تعذر الاتصال فيترك الجلسة كما هي
  static Future<SessionCheck> restoreSession() async {
    final hasSession = await ApiService.getRefreshToken() != null || await ApiService.getAccessToken() != null;
    if (!hasSession) {
      await clearLocalSession();
      return const SessionCheck(SessionStatus.unauthenticated);
    }

    ApiService.muteSessionExpiry = true;
    try {
      final res = await syncProfile(timeout: const Duration(seconds: 6));
      if (res.isOk) {
        final check = await currentSession();
        if (check.status == SessionStatus.accountBlocked) {
          await logout();
        }
        return check;
      }

      if (ApiService.isSuspended(res)) return const SessionCheck(SessionStatus.accountSuspended);

      final stillHasSession = await ApiService.getRefreshToken() != null;
      if (res.statusCode == 401 || !stillHasSession) {
        await clearLocalSession();
        return const SessionCheck(
          SessionStatus.expired,
          message: 'انتهت جلستك، يرجى تسجيل الدخول مرة أخرى',
        );
      }

      return SessionCheck(
        SessionStatus.serverUnreachable,
        message: res.error ?? 'تعذر الاتصال بالخادم، يرجى التأكد من اتصال الإنترنت',
      );
    } finally {
      ApiService.muteSessionExpiry = false;
    }
  }

  /// نوع الحساب المحفوظ: client أو lawyer
  static Future<String?> currentRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefAccountType);
  }

  /// تحديد وجهة المستخدم من آخر بيانات حساب تأكدت مع الخادم
  static Future<SessionCheck> currentSession() async {
    final prefs = await SharedPreferences.getInstance();
    return resolveSession(
      role: prefs.getString(_prefAccountType),
      userStatus: prefs.getString(_prefUserStatus),
      approvalStatus: prefs.getString(_prefApprovalStatus),
    );
  }

  /// تحويل بيانات الحساب إلى وجهته الصحيحة
  static SessionCheck resolveSession({
    required String? role,
    required String? userStatus,
    required String? approvalStatus,
  }) {
    if (userStatus == 'suspended' || approvalStatus == 'suspended') {
      return const SessionCheck(SessionStatus.accountSuspended);
    }

    if (role == 'client') {
      return const SessionCheck(SessionStatus.client);
    }

    if (role == 'lawyer') {
      if (userStatus == 'rejected' || approvalStatus == 'rejected') {
        return const SessionCheck(SessionStatus.lawyerRejected);
      }
      if (approvalStatus == 'approved' && userStatus == 'active') {
        return const SessionCheck(SessionStatus.lawyerApproved);
      }
      return const SessionCheck(SessionStatus.lawyerPending);
    }

    return const SessionCheck(
      SessionStatus.accountBlocked,
      message: 'هذا الحساب غير مدعوم داخل التطبيق',
    );
  }

  /// بدء عملية تسجيل المستخدم وإرسال رمز التحقق للبريد
  static Future<AuthResult> registerUser(RegistrationData data) async {
    final role = data.accountType == UserAccountType.lawyer ? 'lawyer' : 'client';
    final res = await ApiService.post('/auth/register', {
      'phone': data.phone.trim(),
      'email': data.email.trim().toLowerCase(),
      'password': data.password,
      'confirmPassword': data.password,
      'role': role,
      'agreeTerms': true,
      'fullName': data.fullName.trim(),
      if (role == 'lawyer' && data.syndicateNumber != null)
        'syndicateNumber': data.syndicateNumber!.trim(),
      if (role == 'lawyer' && data.experienceYears != null) 'experienceYears': data.experienceYears,
    });

    if (res.isOk) {
      return AuthResult(
        success: true,
        message: res.message ?? 'تم إرسال رمز التحقق بنجاح إلى ${data.email}',
        data: res.data is Map<String, dynamic> ? res.data as Map<String, dynamic> : null,
      );
    }

    return AuthResult(
      success: false,
      message: res.error ?? 'فشل إنشاء الحساب، يرجى مراجعة البيانات المدخلة',
    );
  }

  /// التحقق من كود البريد الإلكتروني المدخل وتفعيل الحساب ثم فتح جلسة حقيقية للمستخدم
  static Future<AuthResult> verifyEmailCode({
    required RegistrationData registration,
    required String inputCode,
  }) async {
    final cleanCode = inputCode.trim();

    if (cleanCode.length != 6) {
      return const AuthResult(
        success: false,
        message: 'يجب إدخال رمز التحقق كاملاً المكون من 6 أرقام',
      );
    }

    final res = await ApiService.post('/auth/verify-otp', {
      'email': registration.email.trim().toLowerCase(),
      'otp': cleanCode,
    });

    if (!res.isOk) {
      return AuthResult(
        success: false,
        message: res.error ?? 'رمز التحقق غير صحيح، يرجى التأكد وإعادة المحاولة',
      );
    }

    if (registration.phone.trim().isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefLoginPhone, registration.phone.trim());
    }

    // الخادم لا يصدر جلسة مع التفعيل، لذلك يتم الدخول ببيانات التسجيل نفسها
    final login = await loginUser(
      identifier: registration.email,
      password: registration.password,
    );

    if (login.success) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefIsEmailVerified, true);
      if (registration.fullName.trim().isNotEmpty) {
        await prefs.setString(_prefUserName, registration.fullName.trim());
      }
      if (registration.syndicateCardPath != null) {
        await prefs.setString(_prefSyndicateCardPath, registration.syndicateCardPath!);
      }
      if (registration.profilePhotoPath != null) {
        await prefs.setString(_prefProfilePhotoPath, registration.profilePhotoPath!);
      }
      await uploadPendingDocuments();
    }

    return AuthResult(
      success: true,
      message: res.message ?? 'تم التحقق من البريد بنجاح وتفعيل الحساب',
      data: {'sessionOpened': login.success},
    );
  }

  /// إعادة إرسال رمز التحقق للبريد الإلكتروني
  static Future<AuthResult> resendVerificationCode(String email) async {
    final res = await ApiService.post('/auth/resend-otp', {
      'email': email.trim().toLowerCase(),
    });

    if (res.isOk) {
      return AuthResult(
        success: true,
        message: res.message ?? 'تم إعادة إرسال رمز التحقق الجديد إلى بريدك',
      );
    }

    return AuthResult(
      success: false,
      message: res.error ?? 'يرجى الانتظار قليلاً قبل طلب رمز تحقق جديد',
    );
  }

  /// طلب رمز استعادة كلمة المرور على البريد المسجل
  static Future<AuthResult> requestPasswordReset(String email) async {
    final res = await ApiService.post('/auth/forgot-password', {
      'email': email.trim().toLowerCase(),
    });

    return AuthResult(
      success: res.isOk,
      message: res.isOk
          ? (res.message ?? 'إذا كان البريد الإلكتروني مسجلاً، فقد تم إرسال رمز التحقق إليه')
          : (res.error ?? 'تعذر إرسال رمز الاستعادة، يرجى المحاولة مرة أخرى'),
    );
  }

  /// تعيين كلمة مرور جديدة برمز الاستعادة
  static Future<AuthResult> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final res = await ApiService.post('/auth/reset-password', {
      'email': email.trim().toLowerCase(),
      'otp': code.trim(),
      'newPassword': newPassword,
      'confirmPassword': newPassword,
    });

    return AuthResult(
      success: res.isOk,
      message: res.isOk
          ? (res.message ?? 'تم تغيير كلمة المرور بنجاح')
          : (res.error ?? 'رمز التحقق غير صحيح أو منتهي'),
    );
  }

  /// تسجيل الخروج وإنهاء الجلسة على الخادم ثم مسح بياناتها محلياً
  static Future<void> logout() async {
    await PushService.stop();
    final refreshToken = await ApiService.getRefreshToken();
    if (refreshToken != null) {
      await ApiService.post(
        '/auth/logout',
        {'refreshToken': refreshToken},
        timeout: const Duration(seconds: 5),
      );
    }
    await clearLocalSession();
  }

  /// رقم الحساب المثبت على هذا الجهاز لشاشة الدخول
  static Future<String?> savedLoginPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefLoginPhone);
  }

  /// مسح كل بيانات الحساب من الجهاز عدا رقم الدخول حتى لا يطلع عليها حساب لاحق
  static Future<void> clearLocalSession() async {
    await ApiService.clearTokens();
    await SavedData.clear();
    OrderStore.clear();
    // الخروج ما يستناش نظام الموبايل
    unawaited(BackgroundLocationService.stopAll());
    final prefs = await SharedPreferences.getInstance();
    final loginPhone = prefs.getString(_prefLoginPhone);
    final permissionsAsked = await DevicePermissionService.instance.hasRequestedInitialPermissions();
    await prefs.clear();
    if (loginPhone != null) await prefs.setString(_prefLoginPhone, loginPhone);
    if (permissionsAsked) await DevicePermissionService.instance.markInitialPermissionsRequested();
  }
}
