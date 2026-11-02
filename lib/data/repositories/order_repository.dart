import '../models/lifecycle_models.dart';
import '../models/order_model.dart';
import '../../core/services/api_service.dart';

/// المستودع المسؤول عن إنشاء ومتابعة وتحديث طلبات الخدمة
class OrderRepository {
  /// إنشاء طلب خدمة جديد
  static Future<ApiResponse<OrderModel>> createOrder({
    required String lawyerId,
    required String serviceTitle,
    required String problemDescription,
    required double clientLat,
    required double clientLon,
    String? problemType,
    String? clientAddress,
  }) async {
    final payload = {
      'lawyerId': lawyerId,
      'serviceType': 'lawyer_now',
      'serviceTitle': serviceTitle,
      'problemType': problemType,
      'problemDescription': problemDescription,
      'clientLat': clientLat,
      'clientLon': clientLon,
      'clientAddress': clientAddress,
    };

    final res = await ApiService.post('/orders', payload);

    if (res.isOk && res.data is Map<String, dynamic>) {
      final order = OrderModel.fromJson(res.data as Map<String, dynamic>);
      return ApiResponse<OrderModel>(
        success: true,
        statusCode: res.statusCode,
        message: res.message,
        data: order,
      );
    }

    return ApiResponse<OrderModel>(
      success: false,
      statusCode: res.statusCode,
      error: res.error ?? 'فشل إنشاء الطلب',
    );
  }

  /// الحصول على تفاصيل طلب محدد بالمعرف
  static Future<ApiResponse<OrderModel>> getOrderById(String orderId) async {
    final res = await ApiService.get('/orders/$orderId');

    if (res.isOk && res.data is Map<String, dynamic>) {
      final data = res.data as Map<String, dynamic>;
      final orderJson = data['order'] is Map<String, dynamic> ? data['order'] as Map<String, dynamic> : data;
      return ApiResponse<OrderModel>(
        success: true,
        statusCode: res.statusCode,
        message: res.message,
        data: OrderModel.fromJson(orderJson),
      );
    }

    return ApiResponse<OrderModel>(
      success: false,
      statusCode: res.statusCode,
      error: res.error ?? 'تعذر العثور على الطلب',
      isConnectivityError: res.isConnectivityError,
    );
  }

  /// جلب قائمة طلبات المستخدم الحالي (عميل أو محامٍ)
  static Future<ApiResponse<List<OrderModel>>> getOrders({String? status}) async {
    final queryParams = status != null ? {'status': status} : null;
    final res = await ApiService.get('/orders', queryParams: queryParams);

    if (res.isOk && res.data is List) {
      final list = res.data as List;
      return ApiResponse<List<OrderModel>>(
        success: true,
        statusCode: res.statusCode,
        data: list.map((item) => OrderModel.fromJson(item as Map<String, dynamic>)).toList(),
      );
    }

    return ApiResponse<List<OrderModel>>(
      success: false,
      statusCode: res.statusCode,
      error: res.error ?? 'تعذر تحميل الطلبات',
      isConnectivityError: res.isConnectivityError,
    );
  }

  /// قبول الطلب من قبل المحامي
  static Future<ApiResponse<OrderModel>> acceptOrder(String orderId, {double? lat, double? lon}) async {
    final res = await ApiService.post('/orders/$orderId/accept', {
      if (lat != null && lon != null) ...{'latitude': lat, 'longitude': lon},
    });
    if (res.isOk && res.data is Map<String, dynamic>) {
      final order = OrderModel.fromJson(res.data as Map<String, dynamic>);
      return ApiResponse<OrderModel>(
        success: true,
        statusCode: res.statusCode,
        message: res.message,
        data: order,
      );
    }
    return ApiResponse<OrderModel>(
      success: false,
      statusCode: res.statusCode,
      error: res.error ?? 'تعذر قبول الطلب',
    );
  }

  /// رفض الطلب أو الاعتذار عنه
  static Future<ApiResponse<OrderModel>> rejectOrder(String orderId, {String? reason}) async {
    final res = await ApiService.post('/orders/$orderId/reject', {
      'reason': reason ?? 'المحامي غير متاح حالياً للمهمة',
    });
    if (res.isOk && res.data is Map<String, dynamic>) {
      final order = OrderModel.fromJson(res.data as Map<String, dynamic>);
      return ApiResponse<OrderModel>(
        success: true,
        statusCode: res.statusCode,
        message: res.message,
        data: order,
      );
    }
    return ApiResponse<OrderModel>(
      success: false,
      statusCode: res.statusCode,
      error: res.error ?? 'تعذر رفض الطلب',
    );
  }

  /// تأكيد سداد قيمة الطلب
  static Future<ApiResponse<OrderModel>> confirmPayment(String orderId, {bool fromBalance = false}) async {
    final res = await ApiService.post('/orders/$orderId/confirm-payment', {
      if (fromBalance) 'method': 'wallet',
    });
    if (res.isOk && res.data is Map<String, dynamic>) {
      final order = OrderModel.fromJson(res.data as Map<String, dynamic>);
      return ApiResponse<OrderModel>(
        success: true,
        statusCode: res.statusCode,
        message: res.message,
        data: order,
      );
    }
    return ApiResponse<OrderModel>(
      success: false,
      statusCode: res.statusCode,
      error: res.error ?? 'تعذر تأكيد السداد',
    );
  }

  /// إلغاء الطلب من قبل العميل
  static Future<ApiResponse<OrderModel>> cancelOrder(String orderId, {String? reason}) async {
    final res = await ApiService.post('/orders/$orderId/cancel', {
      'reason': reason ?? 'طلب العميل إلغاء الخدمة',
    });
    if (res.isOk && res.data is Map<String, dynamic>) {
      final order = OrderModel.fromJson(res.data as Map<String, dynamic>);
      return ApiResponse<OrderModel>(
        success: true,
        statusCode: res.statusCode,
        message: res.message,
        data: order,
      );
    }
    return ApiResponse<OrderModel>(
      success: false,
      statusCode: res.statusCode,
      error: res.error ?? 'تعذر إلغاء الطلب',
    );
  }

  /// السعر الذي يراه الموكل قبل إرسال طلبه
  static Future<ApiResponse<int>> getQuote(String? problemType) async {
    final res = await ApiService.post('/orders/quote', {'problemType': problemType});
    if (res.isOk && res.data is Map<String, dynamic>) {
      final price = (res.data as Map<String, dynamic>)['price'] as num? ?? 0;
      return ApiResponse<int>(success: true, statusCode: res.statusCode, data: price.round());
    }
    return ApiResponse<int>(
      success: false,
      statusCode: res.statusCode,
      error: res.error ?? 'تعذر تقييم سعر الخدمة',
    );
  }

  /// تسجيل وصول المحامي، والخادم يتحقق من قربه من الموكل
  static Future<ApiResponse<dynamic>> markArrived(String orderId, double lat, double lon) {
    return ApiService.post('/orders/$orderId/arrive', {'latitude': lat, 'longitude': lon});
  }

  /// اعتذار المحامي بعد الدفع
  static Future<ApiResponse<dynamic>> withdrawFromOrder(String orderId) {
    return ApiService.post('/orders/$orderId/withdraw', {});
  }

  static Future<ApiResponse<dynamic>> updateReview(String orderId, int rating, String comment) {
    return ApiService.put('/orders/$orderId/review', {
      'rating': rating,
      if (comment.isNotEmpty) 'comment': comment,
    });
  }

  /// المحامي ينهي المهمة بعد ما يسجل وصوله على بعد 50 متر من الموكل
  static Future<ApiResponse<dynamic>> completeOrder(String orderId) {
    return ApiService.post('/orders/$orderId/complete', {});
  }

  static Future<ApiResponse<dynamic>> submitAppeal(String orderId, String reason) {
    return ApiService.post('/orders/$orderId/appeal', {'reason': reason});
  }

  static Future<ApiResponse<dynamic>> submitReview(String orderId, int rating, String comment) {
    return ApiService.post('/orders/$orderId/review', {
      'rating': rating,
      if (comment.isNotEmpty) 'comment': comment,
    });
  }

  static Future<ApiResponse<LawyerWallet>> getLawyerWallet() async {
    final res = await ApiService.get('/orders/wallet/me');
    if (res.isOk && res.data is Map<String, dynamic>) {
      return ApiResponse<LawyerWallet>(
        success: true,
        statusCode: res.statusCode,
        data: LawyerWallet.fromJson(res.data as Map<String, dynamic>),
      );
    }
    return ApiResponse<LawyerWallet>(
      success: false,
      statusCode: res.statusCode,
      error: res.error ?? 'تعذر تحميل بيانات المحفظة',
    );
  }

  static Future<ApiResponse<double>> getClientBalance() async {
    final res = await ApiService.get('/orders/wallet/me');
    if (res.isOk && res.data is Map<String, dynamic>) {
      final balance = (res.data as Map<String, dynamic>)['balance'] as num? ?? 0;
      return ApiResponse<double>(success: true, statusCode: res.statusCode, data: balance.toDouble());
    }
    return ApiResponse<double>(
      success: false,
      statusCode: res.statusCode,
      error: res.error ?? 'تعذر تحميل الرصيد',
    );
  }

  /// اسم صاحب الرقم مختصر، عشان المحوّل يتأكد قبل الإرسال
  static Future<ApiResponse<dynamic>> findTransferRecipient(String phone) {
    return ApiService.get('/wallet/recipient', queryParams: {'phone': phone});
  }

  /// تحويل من رصيدي لأي حساب برقم الموبايل
  static Future<ApiResponse<dynamic>> transfer(String phone, double amount) {
    return ApiService.post('/wallet/transfer', {'phone': phone, 'amount': amount});
  }
}
