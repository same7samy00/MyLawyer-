import 'dart:async';
import '../../core/services/api_service.dart';
import '../../core/services/saved_data.dart';

/// بيانات الحساب المسجل من `/users/me`
class ProfileRepository {
  static const String _savedKey = 'profile';
  static Future<ApiResponse<dynamic>>? _loading;

  /// آخر بيانات اتعرضت، عشان الكروت تظهر فورًا من غير ما تستنى السيرفر.
  /// بتتمسح مع الخروج من الحساب (`SavedData.clear`)
  static Map<String, dynamic>? get saved {
    final value = SavedData.peek(_savedKey);
    return value is Map<String, dynamic> ? value : null;
  }

  /// الشاشات اللي بتفتح مع بعض بتستنى نفس الطلب بدل ما كل واحدة تبعت طلب،
  /// والرد بيتحفظ عشان المرة الجاية تظهر على طول
  static Future<ApiResponse<dynamic>> me() {
    return _loading ??= ApiService.get('/users/me').then((res) {
      if (res.isOk && res.data is Map<String, dynamic>) {
        // الرقم والإيميل ما بيتحفظوش على الموبايل، بيظهروا أول ما السيرفر يرد
        final shown = Map<String, dynamic>.of(res.data as Map<String, dynamic>)
          ..remove('phone')
          ..remove('email');
        unawaited(SavedData.write(_savedKey, shown));
      }
      return res;
    }).whenComplete(() => _loading = null);
  }

  static Future<ApiResponse<dynamic>> uploadPhoto(String filePath) {
    return ApiService.uploadFile('/users/me/profile-photo', filePath);
  }
}
