import '../../core/services/api_service.dart';
import '../../core/services/saved_data.dart';
import '../models/lawyer_model.dart';
import '../models/lifecycle_models.dart';

/// المستودع المسؤول عن استعلام وتحديث بيانات المحامين
class LawyerRepository {
  /// محامين مربعات الخريطة، والمربع واحد لكل الناس والسيرفر بيجهزه كل [MapCells.seconds]
  /// [kind] `top` = أعلى محامي في كل منطقة صغيرة بس (الخريطة وهي بعيدة)، ومن غيره كل المحامين
  static Future<ApiResponse<MapCells>> getMapCells({required String size, required List<String> cells, String? kind}) async {
    final res = await ApiService.get('/lawyers/map', queryParams: {'size': size, 'cells': cells.join(','), if (kind != null) 'kind': kind});
    final data = res.data;
    if (res.isOk && data is Map<String, dynamic> && data['cells'] is Map) {
      return ApiResponse<MapCells>(
        success: true,
        statusCode: res.statusCode,
        data: MapCells(
          seconds: (data['seconds'] as num?)?.toInt() ?? 300,
          cells: {
            for (final entry in (data['cells'] as Map).entries)
              entry.key.toString(): [
                for (final item in entry.value as List) LawyerModel.fromJson(item as Map<String, dynamic>),
              ],
          },
        ),
      );
    }
    return ApiResponse<MapCells>(
      success: false,
      statusCode: res.statusCode,
      error: res.error ?? 'تعذر تحميل المحامين',
      isConnectivityError: res.isConnectivityError,
    );
  }

  static String _topKey(String governorate) => 'top_lawyers_$governorate';

  /// آخر قايمة اتعرضت للمحافظة، عشان الشيت يترسم بيها من أول لحظة
  static List<LawyerModel>? peekTopInGovernorate(String governorate) {
    final saved = SavedData.peek(_topKey(governorate));
    if (saved is! List) return null;
    return [for (final item in saved) if (item is Map<String, dynamic>) LawyerModel.fromJson(item)];
  }

  /// أعلى المحامين تقييمًا في المحافظة، والسيرفر بيجهز القايمة كل 5 دقايق
  /// 20 في كل مرة، و[offset] للـ «المزيد». أول صفحة بس اللي بتتحفظ للرسم الفوري
  static Future<ApiResponse<List<LawyerModel>>> getTopInGovernorate(String governorate, {int offset = 0}) async {
    final res = await ApiService.get('/lawyers/top', queryParams: {'governorate': governorate, 'offset': '$offset', 'limit': '20'});
    if (res.isOk && res.data is List) {
      final list = res.data as List;
      if (offset == 0) SavedData.write(_topKey(governorate), list);
      return ApiResponse<List<LawyerModel>>(
        success: true,
        statusCode: res.statusCode,
        data: [for (final item in list) LawyerModel.fromJson(item as Map<String, dynamic>)],
      );
    }
    return ApiResponse<List<LawyerModel>>(
      success: false,
      statusCode: res.statusCode,
      error: res.error ?? 'تعذر تحميل المحامين',
      isConnectivityError: res.isConnectivityError,
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

/// مربعات الخريطة اللي رجعت، وكل مربع بمحاميه، ومدة صلاحيتها
class MapCells {
  final int seconds;
  final Map<String, List<LawyerModel>> cells;
  const MapCells({required this.seconds, required this.cells});
}
