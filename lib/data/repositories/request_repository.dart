import '../../core/services/api_service.dart';
import '../models/service_request.dart';

/// الطلب اللي بيروح لأقرب المحامين وعروض أسعارهم
class RequestRepository {
  static Future<ApiResponse<(int, int)>> getRange(String? problemType) async {
    final res = await ApiService.get('/requests/range', queryParams: {if (problemType != null) 'problemType': problemType});
    if (res.isOk && res.data is Map<String, dynamic>) {
      final data = res.data as Map<String, dynamic>;
      return ApiResponse(
        success: true,
        statusCode: res.statusCode,
        data: ((data['minPrice'] as num).round(), (data['maxPrice'] as num).round()),
      );
    }
    return ApiResponse(success: false, statusCode: res.statusCode, error: res.error ?? 'تعذر تحميل حدود السعر');
  }

  static Future<ApiResponse<String>> send({
    required String serviceTitle,
    required String problemType,
    required String problemDescription,
    required double clientLat,
    required double clientLon,
    String? clientAddress,
  }) async {
    final res = await ApiService.post('/requests', {
      'serviceTitle': serviceTitle,
      'problemType': problemType,
      'problemDescription': problemDescription,
      'clientLat': clientLat,
      'clientLon': clientLon,
      'clientAddress': clientAddress,
    });
    if (res.isOk && res.data is Map<String, dynamic>) {
      return ApiResponse(success: true, statusCode: res.statusCode, data: (res.data as Map<String, dynamic>)['id'].toString());
    }
    return ApiResponse(success: false, statusCode: res.statusCode, error: res.error ?? 'تعذر إرسال طلبك');
  }

  static Future<ApiResponse<ClientRequest>> follow(String id) async {
    final res = await ApiService.get('/requests/$id');
    if (res.isOk && res.data is Map<String, dynamic>) {
      return ApiResponse(success: true, statusCode: res.statusCode, data: ClientRequest.fromJson(res.data as Map<String, dynamic>));
    }
    return ApiResponse(success: false, statusCode: res.statusCode, error: res.error);
  }

  static Future<ApiResponse<dynamic>> cancel(String id) => ApiService.post('/requests/$id/cancel', {});

  static Future<ApiResponse<SelectedOffer>> select(String id, String offerId) async {
    final res = await ApiService.post('/requests/$id/offers/$offerId/select', {});
    if (res.isOk && res.data is Map<String, dynamic>) {
      final data = res.data as Map<String, dynamic>;
      return ApiResponse(
        success: true,
        statusCode: res.statusCode,
        data: SelectedOffer(
          orderId: data['orderId'].toString(),
          orderNumber: data['orderNumber'].toString(),
          price: (data['price'] as num).round(),
          lawyerId: data['lawyerId'].toString(),
        ),
      );
    }
    return ApiResponse(success: false, statusCode: res.statusCode, error: res.error ?? 'تعذر اختيار العرض');
  }

  static Future<ApiResponse<List<IncomingRequest>>> incoming() async {
    final res = await ApiService.get('/requests/incoming');
    if (res.isOk && res.data is List) {
      return ApiResponse(
        success: true,
        statusCode: res.statusCode,
        data: (res.data as List).map((item) => IncomingRequest.fromJson(item as Map<String, dynamic>)).toList(),
      );
    }
    return ApiResponse(success: false, statusCode: res.statusCode, error: res.error);
  }

  static Future<ApiResponse<dynamic>> sendOffer(String id, int price) => ApiService.post('/requests/$id/offer', {'price': price});

  static Future<ApiResponse<dynamic>> withdrawOffer(String id) => ApiService.post('/requests/$id/offer/withdraw', {});
}
