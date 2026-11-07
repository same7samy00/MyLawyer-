import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// الدخول بالبصمة زي التطبيقات العالمية:
/// بيانات الدخول بتتحفظ مشفرة في خزنة الموبايل (Keystore) ومبتطلعش منها غير بعد البصمة.
/// بتفضل محفوظة بعد تسجيل الخروج، وبتتمسح لو الباسورد اتغير أو المستخدم قفلها
class BiometricService {
  BiometricService._();

  static final LocalAuthentication _auth = LocalAuthentication();
  static const FlutterSecureStorage _vault = FlutterSecureStorage();

  static const _keyIdentifier = 'bio_identifier';
  static const _keyPassword = 'bio_password';
  static const _prefAskedPrefix = 'bio_asked_';

  /// الموبايل فيه بصمة أو وش متسجل
  /// في الاختبارات مفيش بصمة، فالخدمة كلها بتقف
  static final bool _inTests = Platform.environment.containsKey('FLUTTER_TEST');

  static Future<bool> isAvailable() async {
    if (_inTests) return false;
    try {
      if (!await _auth.isDeviceSupported()) return false;
      final types = await _auth.getAvailableBiometrics();
      return types.isNotEmpty;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<String?> enabledIdentifier() async {
    if (_inTests) return null;
    try {
      return await _vault.read(key: _keyIdentifier);
    } catch (_) {
      return null;
    }
  }

  /// آخر حالة معروفة، عشان سطر البصمة في الحساب يتبني من أول لحظة من غير ما يظهر متأخر
  static bool cachedAvailable = false;
  static bool cachedEnabled = false;

  /// بتتنادى مرة مع فتح التطبيق
  static Future<void> warmUp() async {
    cachedAvailable = await isAvailable();
    cachedEnabled = cachedAvailable && await enabledIdentifier() != null;
  }

  static Future<bool> isEnabled() async => (await enabledIdentifier()) != null && await isAvailable();

  /// طلب البصمة نفسه، بيرجع true لو اتأكدت
  static Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
    } on PlatformException {
      return false;
    }
  }

  /// تفعيل: البصمة الأول، وبعدين الحفظ في الخزنة
  static Future<bool> enable(String identifier, String password) async {
    if (!await authenticate('أكد بصمتك عشان تفعّل الدخول بالبصمة')) return false;
    await _vault.write(key: _keyIdentifier, value: identifier);
    await _vault.write(key: _keyPassword, value: password);
    await markAsked(identifier);
    return true;
  }

  /// تحديث المحفوظ بعد ما الباسورد اتغير، والبصمة كانت متأكدة قبل كده
  static Future<void> enableSilently(String identifier, String password) async {
    await _vault.write(key: _keyIdentifier, value: identifier);
    await _vault.write(key: _keyPassword, value: password);
  }

  static Future<void> disable() async {
    await _vault.delete(key: _keyIdentifier);
    await _vault.delete(key: _keyPassword);
  }

  /// بيرجع بيانات الدخول بعد البصمة، أو null لو اتلغت
  static Future<({String identifier, String password})?> unlock() async {
    final identifier = await _vault.read(key: _keyIdentifier);
    final password = await _vault.read(key: _keyPassword);
    if (identifier == null || password == null) return null;
    if (!await authenticate('سجّل دخولك بالبصمة')) return null;
    return (identifier: identifier, password: password);
  }

  /// صفحة التفعيل بتظهر مرة واحدة لكل حساب، ولو قال «مش دلوقتي» مش هتظهر تاني
  static Future<bool> shouldOffer(String identifier) async {
    if (!await isAvailable()) return false;
    if (await enabledIdentifier() == identifier) return false;
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool('$_prefAskedPrefix$identifier') ?? false);
  }

  static Future<void> markAsked(String identifier) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefAskedPrefix$identifier', true);
  }
}
