import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

enum LocationServiceStatus {
  ready,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  error,
}

class LocationResult {
  final LocationServiceStatus status;
  final Position? position;
  final String? errorMessage;

  const LocationResult({
    required this.status,
    this.position,
    this.errorMessage,
  });

  bool get isSuccess => status == LocationServiceStatus.ready && position != null;
}

class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  /// Check permission and service availability, then fetch current single-point position
  /// [fresh] skips the stored position, for checks that depend on where the phone is now
  Future<LocationResult> checkAndRequestPermission({bool fresh = false}) async {
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const LocationResult(
          status: LocationServiceStatus.serviceDisabled,
          errorMessage: 'خدمة الموقع مقفولة على جهازك، شغّلها وحاول تاني',
        );
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return const LocationResult(
            status: LocationServiceStatus.permissionDenied,
            errorMessage: 'لازم تسمح بإذن الموقع عشان نحدد منطقتك',
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return const LocationResult(
          status: LocationServiceStatus.permissionDeniedForever,
          errorMessage: 'إذن الموقع مرفوض، فعّله من إعدادات التطبيق',
        );
      }

      // محاولة استرجاع آخر موقع مسجل فوراً لتسريع الاستجابة دون انتظار
      Position? position = fresh ? null : await Geolocator.getLastKnownPosition();
      // الأجهزة الضعيفة تحتاج وقتاً أطول لأول إشارة GPS
      position ??= await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: fresh ? LocationAccuracy.high : LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 15),
        ),
      );

      return LocationResult(
        status: LocationServiceStatus.ready,
        position: position,
      );
    } catch (e) {
      debugPrint('Location check error: $e');
      return const LocationResult(
        status: LocationServiceStatus.error,
        errorMessage: 'تعذر تحديد موقعك، حاول تاني',
      );
    }
  }

  /// Open device app settings
  Future<bool> openAppSettings() async {
    return Geolocator.openAppSettings();
  }
}
