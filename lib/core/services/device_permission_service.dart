import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'push_service.dart';

/// خدمة إدارة وتنسيق أذونات الجهاز الأصلية
/// تضمن استدعاء نوافذ النظام الرسمية دون أي نوافذ بديلة شكلية
/// وتتعامل مع حالات الرفض والرفض الدائم بأمان تام
class DevicePermissionService {
  DevicePermissionService._();
  static final DevicePermissionService instance = DevicePermissionService._();

  static const String _prefInitialPermissionRequested = 'has_requested_initial_permissions';

  /// فحص ما إذا كان تم طلب الأذونات الابتدائية مسبقاً لمنع الإزعاج المتكرر عند كل فتح للتطبيق
  Future<bool> hasRequestedInitialPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefInitialPermissionRequested) ?? false;
  }

  /// تسجيل إتمام فحص وطلب الأذونات الابتدائية
  Future<void> markInitialPermissionsRequested() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefInitialPermissionRequested, true);
  }

  /// طلب إذني الموقع والإشعارات عبر نوافذ النظام، ورفض أي منهما لا يوقف التطبيق
  Future<void> requestInitialPermissions() async {
    await markInitialPermissionsRequested();
    try {
      if (await Geolocator.checkPermission() == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
    } catch (e) {
      debugPrint('Request location permission error: $e');
    }
    await PushService.requestPermission();
  }

  /// فحص حالة إذن الموقع الحالية دون إظهار نافذة طلب جديدة
  Future<bool> isLocationPermissionGranted() async {
    try {
      final permission = await Geolocator.checkPermission();
      return permission == LocationPermission.always || permission == LocationPermission.whileInUse;
    } catch (e) {
      debugPrint('Check location permission error: $e');
      return false;
    }
  }
}

