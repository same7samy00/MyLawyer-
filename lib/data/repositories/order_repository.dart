import 'dart:async';
import '../models/lifecycle_models.dart';
import '../models/order_model.dart';
import '../models/payment_record.dart';
import '../../core/services/api_service.dart';
import '../../core/services/saved_data.dart';

/// المستودع المسؤول عن إنشاء ومتابعة وتحديث طلبات الخدمة
class OrderRepository {
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

  // الأرقام والإيميل والمكان الدقيق ما بيتحفظوش على الموبايل
  static const _privateFields = ['clientPhone', 'lawyerPhone', 'clientEmail', 'clientAddress', 'clientLatitude', 'clientLongitude', 'lawyerLatitude', 'lawyerLongitude'];

  static Object? _withoutPrivate(Object? item) {
    if (item is! Map<String, dynamic>) return item;
    return {...item}..removeWhere((key, _) => _privateFields.contains(key));
  }

  /// آخر طلبات اتعرضت، لحد ما الطلب الجديد من السيرفر يوصل
  static Future<List<OrderModel>> savedOrders() async {
    final saved = await SavedData.read('orders');
    if (saved is! List) return const [];
    return saved.whereType<Map<String, dynamic>>().map(OrderModel.fromJson).toList();
  }

  /// جلب قائمة طلبات المستخدم الحالي (عميل أو محامٍ)
  static Future<ApiResponse<List<OrderModel>>> getOrders({String? status}) async {
    final queryParams = status != null ? {'status': status} : null;
    final res = await ApiService.get('/orders', queryParams: queryParams);

    if (res.isOk && res.data is List) {
      final list = res.data as List;
      if (status == null) unawaited(SavedData.write('orders', list.map(_withoutPrivate).toList()));
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

  /// طلب واحد بنفس شكل القائمة، وفاضي لو مبقاش من طلبات المستخدم
  static Future<ApiResponse<OrderModel?>> getOrderFromList(String id) async {
    final res = await ApiService.get('/orders', queryParams: {'id': id});
    if (res.isOk && res.data is List) {
      final list = res.data as List;
      return ApiResponse<OrderModel?>(
        success: true,
        statusCode: res.statusCode,
        data: list.isEmpty ? null : OrderModel.fromJson(list.first as Map<String, dynamic>),
      );
    }
    return ApiResponse<OrderModel?>(success: false, statusCode: res.statusCode, error: res.error);
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

  /// تسجيل وصول المحامي، والخادم يتحقق من قربه من الموكل
  static Future<ApiResponse<dynamic>> markArrived(String orderId, double lat, double lon) {
    return ApiService.post('/orders/$orderId/arrive', {'latitude': lat, 'longitude': lon});
  }

  /// الموكل يختار يستنى المحامي المتأخر
  static Future<ApiResponse<dynamic>> keepWaiting(String orderId) {
    return ApiService.post('/orders/$orderId/keep-waiting', {});
  }

  /// المحامي يأجل المهمة بعد وصوله، والفلوس تفضل محجوزة
  /// تأجيل المهمة بعد الوصول: تأكيد بس، من غير سبب ولا ميعاد
  static Future<ApiResponse<dynamic>> postponeOrder(String orderId) {
    return ApiService.post('/orders/$orderId/postpone', {});
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

  static Future<ApiResponse<dynamic>> submitReview(String orderId, int rating, String comment) {
    return ApiService.post('/orders/$orderId/review', {
      'rating': rating,
      if (comment.isNotEmpty) 'comment': comment,
    });
  }

  static Future<Map<String, dynamic>?> savedWallet() async {
    final saved = await SavedData.read('wallet');
    return saved is Map<String, dynamic> ? saved : null;
  }

  static Future<ApiResponse<LawyerWallet>> getLawyerWallet() async {
    final res = await ApiService.get('/orders/wallet/me');
    if (res.isOk && res.data is Map<String, dynamic>) {
      unawaited(SavedData.write('wallet', res.data));
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
      unawaited(SavedData.write('wallet', res.data));
      return ApiResponse<double>(success: true, statusCode: res.statusCode, data: balance.toDouble());
    }
    return ApiResponse<double>(
      success: false,
      statusCode: res.statusCode,
      error: res.error ?? 'تعذر تحميل الرصيد',
    );
  }

  /// كل دفعات الموكل: اللي اتدفعت واللي اتردت واللي ما تمتش، الأحدث الأول
  /// آخر مدفوعات اتعرضت، عشان الصفحة تظهر على طول
  static List<PaymentRecord>? savedPayments() {
    final value = SavedData.peek('payments');
    return value is List ? value.whereType<Map<String, dynamic>>().map(PaymentRecord.fromJson).toList() : null;
  }

  static Future<ApiResponse<List<PaymentRecord>>> getPayments() async {
    final res = await ApiService.get('/wallet/payments');
    if (res.isOk && res.data is List) {
      unawaited(SavedData.write('payments', res.data));
      final list = (res.data as List).whereType<Map<String, dynamic>>().map(PaymentRecord.fromJson).toList();
      return ApiResponse<List<PaymentRecord>>(success: true, statusCode: res.statusCode, data: list);
    }
    return ApiResponse<List<PaymentRecord>>(
      success: false,
      statusCode: res.statusCode,
      error: res.error ?? 'تعذر تحميل المدفوعات',
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
