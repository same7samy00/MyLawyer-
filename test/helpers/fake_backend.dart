import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// خادم وهمي لاختبارات الواجهات فقط: يحاكي عقد الـ API الفعلي للخادم
/// ويسجل الطلبات دون أي اتصال بشبكة أو بخادم الإنتاج
class FakeBackend {
  Map<String, dynamic> account = clientAccount();
  List<Map<String, dynamic>> orders = [];
  List<Map<String, dynamic>> lawyers = [];

  /// محاكاة انقطاع الشبكة لكل الطلبات
  bool isOffline = false;

  /// استجابات مخصصة لمسار معين: 'METHOD /path'
  final Map<String, http.Response Function(http.Request request)> overrides = {};

  Map<String, dynamic> wallet = {
    'availableBalance': 1450,
    'heldBalance': 300,
    'frozenBalance': 100,
    'balance': 75,
  };

  final List<String> calls = [];

  int countOf(String route) => calls.where((call) => call == route).length;

  late final http.Client client = MockClient(_handle);

  Future<http.Response> _handle(http.Request request) async {
    final path = request.url.path.replaceFirst('/api/v1', '');
    final route = '${request.method} $path';
    calls.add(route);

    if (isOffline) {
      throw const SocketException('offline');
    }

    final override = overrides[route];
    if (override != null) return override(request);

    switch (route) {
      case 'POST /auth/login':
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (body['password'] == 'wrong-password') {
          return json(401, {'success': false, 'error': 'بيانات الدخول غير صحيحة'});
        }
        return json(200, {
          'success': true,
          'message': 'تم تسجيل الدخول بنجاح',
          'data': {
            'accessToken': 'access-token',
            'refreshToken': 'refresh-token',
            'user': {
              ...account,
              'lawyerApprovalStatus': account['approvalStatus'],
            },
          },
        });
      case 'GET /users/me':
        return json(200, {'success': true, 'data': account});
      case 'POST /auth/refresh':
        return json(200, {
          'success': true,
          'data': {'accessToken': 'renewed-access', 'refreshToken': 'renewed-refresh'},
        });
      case 'POST /auth/logout':
        return json(200, {'success': true});
      case 'GET /orders':
        final status = request.url.queryParameters['status'];
        final list = status == null ? orders : orders.where((order) => order['status'] == status).toList();
        return json(200, {'success': true, 'data': list});
      case 'GET /lawyers/map':
        // كل محامي في مربعه زي السيرفر: x = floor(lon / size) و y = floor(lat / size)
        final size = request.url.queryParameters['size'] == 'l' ? 0.5 : 0.1;
        final asked = (request.url.queryParameters['cells'] ?? '').split(',');
        return json(200, {
          'success': true,
          'data': {
            'seconds': 300,
            'cells': {
              for (final cell in asked)
                cell: [
                  for (final lawyer in lawyers)
                    if ('${((lawyer['coordinates'] as List)[1] as num) ~/ size}_${((lawyer['coordinates'] as List)[0] as num) ~/ size}' == cell) lawyer,
                ],
            },
          },
        });
      case 'GET /lawyers/top':
        return json(200, {'success': true, 'data': lawyers});
      case 'GET /requests/range':
        return json(200, {'success': true, 'data': {'minPrice': 500, 'maxPrice': 1500}});
      case 'GET /requests/incoming':
        return json(200, {'success': true, 'data': []});
      case 'GET /orders/wallet/me':
        return json(200, {'success': true, 'data': wallet});
      case 'GET /notifications/summary':
        return json(200, {'success': true, 'data': {'unread': 0, 'pendingOrders': 0}});
      case 'GET /health':
        return json(200, {'status': 'UP'});
      default:
        return json(404, {'success': false, 'error': 'المسار غير موجود'});
    }
  }

  static http.Response json(int status, Object body) {
    return http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }
}

Map<String, dynamic> clientAccount() => {
      'id': 'client-1',
      'phone': '01012345678',
      'email': 'client@example.com',
      'role': 'client',
      'status': 'active',
      'fullName': null,
      'approvalStatus': null,
      'syndicateNumber': null,
    };

Map<String, dynamic> lawyerAccount({
  String status = 'active',
  String approvalStatus = 'approved',
  String fullName = 'أحمد محمود علي',
  String syndicateNumber = '987654',
}) =>
    {
      'id': 'lawyer-1',
      'phone': '01123456789',
      'email': 'lawyer@example.com',
      'role': 'lawyer',
      'status': status,
      'fullName': fullName,
      'approvalStatus': approvalStatus,
      'syndicateNumber': syndicateNumber,
    };

Map<String, dynamic> sampleOrder({
  String status = 'PENDING',
  String id = 'order-1',
  String orderNumber = 'ML-ORD-100001',
  num price = 350,
}) =>
    {
      'id': orderNumber,
      'orderId': id,
      'orderNumber': orderNumber,
      'serviceTitle': 'محاميك حالاً',
      'clientName': '01099990000',
      'clientPhone': '01099990000',
      'clientChoice': 'محضر في قسم الشرطة',
      'problemDescription': 'تفاصيل الطلب',
      'specialty': 'قضايا جنائية',
      'lawyerName': 'أ/ طارق حسن',
      'lawyerPhone': '01123456789',
      'lawyerAvatar': null,
      'status': status,
      'price': price,
      'createdAt': '2026-11-01T10:00:00.000Z',
      'clientLatitude': 30.0444,
      'clientLongitude': 31.2357,
      'clientAddress': 'قصر النيل، محافظة القاهرة',
      'lawyerLatitude': 30.05,
      'lawyerLongitude': 31.24,
    };
