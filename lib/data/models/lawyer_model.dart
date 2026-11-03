/// نموذج بيانات المحامي المشترك في المنصة
class LawyerModel {
  final String id;
  final String? profileId;
  final String? userId;
  final String name;
  final String degree;
  final double rating;
  final int reviewsCount;
  final int experienceYears;
  final bool isOnline;
  final String phone;
  final String avatar;
  final double latitude;
  final double longitude;
  final double distanceKm;
  final String? googleProfileUrl;
  final String? lastActiveAt;

  const LawyerModel({
    required this.id,
    this.profileId,
    this.userId,
    required this.name,
    required this.degree,
    required this.rating,
    required this.reviewsCount,
    required this.experienceYears,
    required this.isOnline,
    required this.phone,
    required this.avatar,
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
    this.googleProfileUrl,
    this.lastActiveAt,
  });

  factory LawyerModel.fromJson(Map<String, dynamic> json) {
    double parseLat = 30.0444;
    double parseLon = 31.2357;

    if (json['coordinates'] is List && (json['coordinates'] as List).length >= 2) {
      final list = json['coordinates'] as List;
      parseLat = (list[0] as num).toDouble();
      parseLon = (list[1] as num).toDouble();
    } else if (json['latitude'] != null && json['longitude'] != null) {
      parseLat = (json['latitude'] as num).toDouble();
      parseLon = (json['longitude'] as num).toDouble();
    }

    return LawyerModel(
      id: json['id']?.toString() ?? '',
      profileId: json['profileId']?.toString(),
      userId: json['userId']?.toString() ?? json['id']?.toString(),
      name: json['name']?.toString() ?? 'محامٍ معتمد',
      degree: json['degree']?.toString() ?? 'محامٍ معتمد',
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      reviewsCount: (json['reviewsCount'] as num?)?.toInt() ?? 0,
      experienceYears: (json['experienceYears'] as num?)?.toInt() ?? 0,
      isOnline: json['isOnline'] == true || json['isAvailable'] == true,
      phone: json['phone']?.toString() ?? '',
      avatar: json['avatar']?.toString() ?? '',
      latitude: parseLat,
      longitude: parseLon,
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0.0,
      googleProfileUrl: json['googleProfileUrl']?.toString(),
      lastActiveAt: json['lastActiveAt']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'profileId': profileId,
      'userId': userId,
      'name': name,
      'degree': degree,
      'rating': rating,
      'reviewsCount': reviewsCount,
      'experienceYears': experienceYears,
      'isOnline': isOnline,
      'phone': phone,
      'avatar': avatar,
      'coordinates': [latitude, longitude],
      'distanceKm': distanceKm,
      'googleProfileUrl': googleProfileUrl,
      'lastActiveAt': lastActiveAt,
    };
  }

  String get effectiveGoogleProfileUrl {
    if (googleProfileUrl != null && googleProfileUrl!.trim().isNotEmpty) {
      return googleProfileUrl!;
    }
    final query = Uri.encodeComponent('$name محامي مصر');
    return 'https://www.google.com/search?q=$query';
  }
}

