import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import 'lawyer_model.dart';

/// بيانات المحامي المعروضة على الخريطة وفي ملفه التعريفي
class MapLawyer {
  final String id;
  final String name;
  final String title;
  final String specialization;
  final double rating;
  final int reviewsCount;
  final int experienceYears;
  final LatLng position;
  final double distanceMeters;
  final String avatarInitials;
  final Color avatarColor;
  final String imageUrl;
  final String? googleProfileUrl;

  const MapLawyer({
    required this.id,
    required this.name,
    required this.title,
    required this.specialization,
    required this.rating,
    this.reviewsCount = 0,
    this.experienceYears = 0,
    required this.position,
    this.distanceMeters = 0.0,
    this.avatarInitials = 'مح',
    this.avatarColor = AppColors.primary,
    this.imageUrl = '',
    this.googleProfileUrl,
  });

  factory MapLawyer.fromModel(LawyerModel lawyer) {
    final words = lawyer.name.trim().split(RegExp(r'\s+')).where((word) => word.isNotEmpty);
    final serverOrigin = ApiService.baseUrl.replaceAll('/api/v1', '');

    return MapLawyer(
      id: lawyer.id,
      name: lawyer.name,
      title: lawyer.degree,
      specialization: lawyer.specialty,
      rating: lawyer.rating,
      reviewsCount: lawyer.reviewsCount,
      experienceYears: lawyer.experienceYears,
      position: LatLng(lawyer.latitude, lawyer.longitude),
      distanceMeters: lawyer.distanceKm * 1000.0,
      avatarInitials: words.isNotEmpty ? words.last.substring(0, 1) : 'مح',
      imageUrl: lawyer.avatar.isNotEmpty ? '$serverOrigin${lawyer.avatar}' : '',
      googleProfileUrl: lawyer.googleProfileUrl,
    );
  }

  String get effectiveGoogleProfileUrl {
    if (googleProfileUrl != null && googleProfileUrl!.isNotEmpty) {
      return googleProfileUrl!;
    }
    final query = Uri.encodeComponent('$name محامٍ استشارات قانونية مصر');
    return 'https://www.google.com/search?q=$query';
  }
}
