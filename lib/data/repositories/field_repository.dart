import '../../core/services/api_service.dart';
import '../models/field_info.dart';

/// الخدمات الميدانية: البحث عن المكان، وإرسال الطلب، وكود التسليم، ورفض الشخص، وصورة الإثبات.
/// بعد ما الطلب يتبعت بيكمل زي أي طلب: عروض ودفع وطلب في صفحة الطلبات
class FieldRepository {
  /// أماكن بالاسم، وفاضية لو السيرفر ما لقاش أو ما ردش
  static Future<List<FieldPlace>> places(String text) async {
    final res = await ApiService.get('/field/places', queryParams: {'q': text}, timeout: const Duration(seconds: 8));
    if (!res.isOk || res.data is! List) return const [];
    return [for (final item in res.data as List) FieldPlace.fromJson(item as Map<String, dynamic>)];
  }

  static Future<ApiResponse<String>> send(FieldDraft draft) async {
    final res = await ApiService.post('/field/requests', draft.toJson());
    if (res.isOk && res.data is Map<String, dynamic>) {
      return ApiResponse(success: true, statusCode: res.statusCode, data: (res.data as Map<String, dynamic>)['id'].toString());
    }
    return ApiResponse(success: false, statusCode: res.statusCode, error: res.error ?? 'تعذر إرسال طلبك');
  }

  /// المحامي بيكتب الكود اللي الشخص قاله، فيتسجل الوصول
  static Future<ApiResponse<dynamic>> submitCode(String orderId, String code) =>
      ApiService.post('/field/orders/$orderId/code', {'code': code});

  /// الشخص رفض المحامي بعد ما قابله، والأتعاب بتفضل للمحامي
  static Future<ApiResponse<dynamic>> personRefused(String orderId) => ApiService.post('/field/orders/$orderId/refused', {});

  /// صورة بتتحفظ عند الإدارة بس
  static Future<ApiResponse<dynamic>> uploadProof(String orderId, String imagePath) =>
      ApiService.uploadFile('/field/orders/$orderId/proof', imagePath);
}
