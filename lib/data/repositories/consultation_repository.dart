import '../../core/services/api_service.dart';
import '../models/consultation.dart';

/// «استشارة سريعة»: الشروط، وتقييم السعر، والطلب بالدفع
class ConsultationRepository {
  static Future<ConsultationSettings> settings() async {
    final res = await ApiService.get('/consultations/settings');
    return res.isOk && res.data is Map<String, dynamic>
        ? ConsultationSettings.fromJson(res.data as Map<String, dynamic>)
        : const ConsultationSettings();
  }

  /// السعر بيتحسب في السيرفر بس، والتطبيق بيعرضه
  static Future<ApiResponse<ConsultationQuote>> quote(ConsultationKind kind, int pages) async {
    final res = await ApiService.post('/consultations/quote', {'kind': kind.code, 'pages': pages});
    if (res.isOk && res.data is Map<String, dynamic>) {
      return ApiResponse(success: true, statusCode: res.statusCode, data: ConsultationQuote.fromJson(res.data as Map<String, dynamic>));
    }
    return ApiResponse(success: false, statusCode: res.statusCode, error: res.error ?? 'تعذر تقييم السعر، حاول تاني');
  }

  /// الدفع والطلب مع بعض: التفاصيل وصور الورق وطريقة الدفع
  static Future<ApiResponse<Consultation>> submit(ConsultationDraft draft, {required bool fromBalance}) async {
    final res = await ApiService.uploadForm(
      '/consultations',
      {'kind': draft.kind.code, 'details': draft.details, 'method': fromBalance ? 'wallet' : 'direct'},
      draft.pagePaths,
    );
    if (res.isOk && res.data is Map<String, dynamic>) {
      return ApiResponse(success: true, statusCode: res.statusCode, data: Consultation.fromJson(res.data as Map<String, dynamic>));
    }
    return ApiResponse(success: false, statusCode: res.statusCode, error: res.error ?? 'الدفع ما تمش، جرب تاني');
  }
}
