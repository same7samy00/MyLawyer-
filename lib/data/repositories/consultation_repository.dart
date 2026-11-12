import 'dart:async';
import '../../core/services/api_service.dart';
import '../../core/services/saved_data.dart';
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

  /// آخر نسخة محفوظة، عشان الاستشارات تظهر مع الطلبات من أول لحظة
  static List<Consultation> peek() {
    final saved = SavedData.peek('consultations');
    return saved is List ? saved.whereType<Map<String, dynamic>>().map(Consultation.fromJson).toList() : const [];
  }

  /// استشاراتي، عشان تظهر في صفحة الطلبات
  static Future<ApiResponse<List<Consultation>>> list() async {
    final res = await ApiService.get('/consultations');
    if (res.isOk && res.data is List) {
      unawaited(SavedData.write('consultations', res.data));
      final items = (res.data as List).whereType<Map<String, dynamic>>().map(Consultation.fromJson).toList();
      return ApiResponse(success: true, statusCode: res.statusCode, data: items);
    }
    return ApiResponse(success: false, statusCode: res.statusCode, error: res.error ?? 'تعذر تحميل الاستشارات');
  }

  static Future<ApiResponse<Consultation>> get(String id) async {
    final res = await ApiService.get('/consultations/$id');
    if (res.isOk && res.data is Map<String, dynamic>) {
      return ApiResponse(success: true, statusCode: res.statusCode, data: Consultation.fromJson(res.data as Map<String, dynamic>));
    }
    return ApiResponse(success: false, statusCode: res.statusCode, error: res.error ?? 'تعذر تحميل الاستشارة');
  }

  /// «طلب التواصل» بعد ما الفريق ما قدرش يوصله
  static Future<ApiResponse<Consultation>> requestContact(String id) async {
    final res = await ApiService.post('/consultations/$id/contact', const {});
    if (res.isOk && res.data is Map<String, dynamic>) {
      return ApiResponse(success: true, statusCode: res.statusCode, data: Consultation.fromJson(res.data as Map<String, dynamic>), message: res.message);
    }
    return ApiResponse(success: false, statusCode: res.statusCode, error: res.error ?? 'تعذر إرسال الطلب، حاول تاني');
  }

  /// الدفع والطلب مع بعض: التفاصيل وصور الورق وطريقة الدفع
  static Future<ApiResponse<Consultation>> submit(ConsultationDraft draft, {required bool fromBalance}) async {
    final res = await ApiService.uploadForm(
      '/consultations',
      {
        'kind': draft.kind.code,
        'details': draft.details,
        'method': fromBalance ? 'wallet' : 'direct',
        if (draft.viaVoice) 'inputMethod': 'voice',
      },
      draft.pagePaths,
    );
    if (res.isOk && res.data is Map<String, dynamic>) {
      return ApiResponse(success: true, statusCode: res.statusCode, data: Consultation.fromJson(res.data as Map<String, dynamic>));
    }
    return ApiResponse(success: false, statusCode: res.statusCode, error: res.error ?? 'الدفع ما تمش، جرب تاني');
  }
}
