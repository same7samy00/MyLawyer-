import '../models/lawyer_model.dart';
import '../models/lifecycle_models.dart';
import '../../core/services/api_service.dart';

/// المستودع المسؤول عن استعلام وتحديث بيانات المحامين
class LawyerRepository {
  /// استرجاع المحامين المتاحين بالقرب من موقع محدد
  static Future<ApiResponse<List<LawyerModel>>> getNearbyLawyers({
    required double lat,
    required double lon,
    double radiusKm = 1500.0,
  }) async {
    final queryParams = <String, String>{
      'lat': lat.toString(),
      'lon': lon.toString(),
      'radius_km': radiusKm.toString(),
    };

    final response = await ApiService.get('/lawyers/nearby', queryParams: queryParams);

    if (response.isOk && response.data is List) {
      final list = response.data as List;
      return ApiResponse<List<LawyerModel>>(
        success: true,
        statusCode: response.statusCode,
        data: list.map((item) => LawyerModel.fromJson(item as Map<String, dynamic>)).toList(),
      );
    }

    return ApiResponse<List<LawyerModel>>(
      success: false,
      statusCode: response.statusCode,
      error: response.error ?? 'تعذر البحث عن المحامين المتاحين',
      isConnectivityError: response.isConnectivityError,
    );
  }

  /// تحديث موقع وحالة المحامي اللحظية
  static Future<bool> updateLawyerLocation({
    required double lat,
    required double lon,
    bool isAvailable = true,
  }) async {
    final response = await ApiService.post('/lawyers/me/location', {
      'lat': lat,
      'lon': lon,
      'isAvailable': isAvailable,
    });
    return response.isOk;
  }

  static Future<bool?> getAvailability() async {
    final res = await ApiService.get('/lawyers/me');
    if (!res.isOk || res.data is! Map<String, dynamic>) return null;
    final profile = (res.data as Map<String, dynamic>)['profile'];
    return profile is Map<String, dynamic> ? profile['is_available'] == true : null;
  }

  static Future<Map<String, dynamic>?> getProfile() async {
    final res = await ApiService.get('/lawyers/me');
    final data = res.data;
    if (data is! Map<String, dynamic>) return null;
    final profile = data['profile'] ?? data;
    return profile is Map<String, dynamic> ? profile : null;
  }

  static Future<ApiResponse<dynamic>> acceptUrgentTerms() {
    return ApiService.post('/lawyers/me/urgent-terms', {});
  }

  static Future<ApiResponse<dynamic>> setAvailability(bool isAvailable) {
    return ApiService.post('/lawyers/me/availability', {'isAvailable': isAvailable});
  }

  static Future<ApiResponse<dynamic>> reportReview(String reviewId, String reason) {
    return ApiService.post('/lawyers/me/reviews/$reviewId/report', {'reason': reason});
  }

  static Future<ApiResponse<List<LawyerReview>>> getReviews(String lawyerId) async {
    final res = await ApiService.get('/lawyers/$lawyerId/reviews');
    if (res.isOk && res.data is List) {
      return ApiResponse<List<LawyerReview>>(
        success: true,
        statusCode: res.statusCode,
        data: (res.data as List)
            .map((item) => LawyerReview.fromJson(item as Map<String, dynamic>))
            .toList(),
      );
    }
    return ApiResponse<List<LawyerReview>>(
      success: false,
      statusCode: res.statusCode,
      error: res.error ?? 'تعذر تحميل التقييمات',
    );
  }
}
