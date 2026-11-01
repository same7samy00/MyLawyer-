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
  Future<LocationResult> checkAndRequestPermission() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const LocationResult(
          status: LocationServiceStatus.serviceDisabled,
          errorMessage: 'Location services are disabled on this device. Please turn on GPS.',
        );
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return const LocationResult(
            status: LocationServiceStatus.permissionDenied,
            errorMessage: 'Location permission was denied. Location access is required to determine your area.',
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return const LocationResult(
          status: LocationServiceStatus.permissionDeniedForever,
          errorMessage: 'Location permissions are permanently denied. Please enable them in app settings.',
        );
      }

      // محاولة استرجاع آخر موقع مسجل فوراً لتسريع الاستجابة دون انتظار
      Position? position = await Geolocator.getLastKnownPosition();
      position ??= await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 5),
        ),
      );

      return LocationResult(
        status: LocationServiceStatus.ready,
        position: position,
      );
    } catch (e) {
      debugPrint('Location check error: $e');
      return LocationResult(
        status: LocationServiceStatus.error,
        errorMessage: 'Failed to obtain GPS position: ${e.toString()}',
      );
    }
  }

  /// Open device app settings
  Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }

  /// Open device location settings
  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }
}
