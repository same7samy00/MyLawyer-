import '../../core/services/api_service.dart';

/// بيانات الحساب المسجل من `/users/me`
class ProfileRepository {
  static Future<ApiResponse<dynamic>>? _loading;

  /// الشاشات اللي بتفتح مع بعض بتستنى نفس الطلب بدل ما كل واحدة تبعت طلب،
  /// ومفيش نسخة قديمة بتتحفظ، فأي تحميل بعد ما الطلب يخلص بيجيب الجديد
  static Future<ApiResponse<dynamic>> me() {
    return _loading ??= ApiService.get('/users/me').whenComplete(() => _loading = null);
  }

  static Future<ApiResponse<dynamic>> uploadPhoto(String filePath) {
    return ApiService.uploadFile('/users/me/profile-photo', filePath);
  }
}
