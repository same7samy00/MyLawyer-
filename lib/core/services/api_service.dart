import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

/// كائن استجابة الـ API الموحد للمنصة
class ApiResponse<T> {
  final bool success;
  final int statusCode;
  final String? message;
  final String? error;
  final T? data;

  /// فشل في الوصول للخادم (لا يعني إطلاقاً انتهاء الجلسة أو رفض الطلب)
  final bool isConnectivityError;

  const ApiResponse({
    required this.success,
    required this.statusCode,
    this.message,
    this.error,
    this.data,
    this.isConnectivityError = false,
  });

  bool get isOk => success && statusCode >= 200 && statusCode < 300;
}

enum _RefreshOutcome { refreshed, expired, unreachable, suspended }

/// خدمة الاتصال الموحدة بالـ Backend الإنتاجي لـ My Lawyer
class ApiService {
  static const String defaultBaseUrl = AppConfig.productionApiBaseUrl;

  static const String prefAccessToken = 'auth_access_token';
  static const String prefRefreshToken = 'auth_refresh_token';

  /// الاستجابات الأكبر من هذا الحجم تفك خارج الـ UI Thread
  static const int _isolateDecodeThresholdBytes = 32 * 1024;

  static http.Client _client = http.Client();
  static final String _baseUrl = AppConfig.apiBaseUrl;

  // نسخة الجلسة في الذاكرة: تكفي وحدها عند عدم تفعيل «تذكر بياناتي»
  static String? _accessToken;
  static String? _refreshToken;
  static Future<_RefreshOutcome>? _activeRefresh;

  /// حالة الوصول للخادم وفق آخر طلب، ويتابعها شريط حالة الاتصال
  static final ValueNotifier<bool> isServerReachable = ValueNotifier<bool>(true);

  /// يستدعى عند ثبوت انتهاء الجلسة من الخادم نفسه
  static Future<void> Function()? onSessionExpired;

  /// يستدعى عند رفض الخادم للحساب لأنه موقوف
  static Future<void> Function()? onAccountSuspended;

  /// يوقف إشعار انتهاء الجلسة أثناء فحص بدء التشغيل لأن الفحص يوجّه المستخدم بنفسه
  static bool muteSessionExpiry = false;

  static String get baseUrl => _baseUrl;

  @visibleForTesting
  static void useHttpClient(http.Client client) {
    _client = client;
    _accessToken = null;
    _refreshToken = null;
    _activeRefresh = null;
    muteSessionExpiry = false;
    onSessionExpired = null;
    onAccountSuspended = null;
    isServerReachable.value = true;
  }

  /// الحصول على توكن الوصول المخزن
  static Future<String?> getAccessToken() async {
    if (_accessToken != null) return _accessToken;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(prefAccessToken);
  }

  /// الحصول على توكن التحديث المخزن
  static Future<String?> getRefreshToken() async {
    if (_refreshToken != null) return _refreshToken;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(prefRefreshToken);
  }

  /// حفظ الـ Tokens بعد تسجيل الدخول أو التجديد
  /// عند [persist] = false تبقى الجلسة في الذاكرة فقط وتنتهي بإغلاق التطبيق
  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    bool persist = true,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    if (!persist) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefAccessToken, accessToken);
    await prefs.setString(prefRefreshToken, refreshToken);
  }

  /// مسح الـ Tokens عند تسجيل الخروج
  static Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefAccessToken);
    await prefs.remove(prefRefreshToken);
  }

  /// ترويسات الطلب الموحدة
  static Future<Map<String, String>> _buildHeaders({String? customToken}) async {
    final token = customToken ?? await getAccessToken();
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// GET Request
  static Future<ApiResponse<dynamic>> get(
    String endpoint, {
    Map<String, String>? queryParams,
    String? customToken,
    Duration timeout = const Duration(seconds: 12),
  }) {
    final cleanEndpoint = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    var uri = Uri.parse('$_baseUrl$cleanEndpoint');
    if (queryParams != null && queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }

    return _send(
      cleanEndpoint,
      (headers) => _client.get(uri, headers: headers),
      customToken: customToken,
      timeout: timeout,
      timeoutError: 'انتهت مهلة الاتصال بالخادم، يرجى التحقق من سرعة الإنترنت والمحاولة ثانية.',
    );
  }

  /// رفع ملف صورة، ويمر بنفس تجديد الجلسة
  static Future<ApiResponse<dynamic>> uploadFile(String endpoint, String filePath) {
    final uri = Uri.parse('$_baseUrl$endpoint');

    return _send(
      endpoint,
      (headers) async {
        final request = http.MultipartRequest('POST', uri)
          ..headers.addAll(headers..remove('Content-Type'))
          ..files.add(await http.MultipartFile.fromPath('file', filePath));
        return http.Response.fromStream(await _client.send(request));
      },
      customToken: null,
      timeout: const Duration(seconds: 40),
      timeoutError: 'انتهت مهلة رفع الصورة، حاول تاني',
    );
  }

  /// نموذج فيه نصوص وصور مع بعض، زي تذكرة الدعم الفني
  static Future<ApiResponse<dynamic>> uploadForm(String endpoint, Map<String, String> fields, List<String> imagePaths) {
    final uri = Uri.parse('$_baseUrl$endpoint');

    return _send(
      endpoint,
      (headers) async {
        final request = http.MultipartRequest('POST', uri)
          ..headers.addAll(headers..remove('Content-Type'))
          ..fields.addAll(fields);
        for (final path in imagePaths) {
          request.files.add(await http.MultipartFile.fromPath('images', path));
        }
        return http.Response.fromStream(await _client.send(request));
      },
      customToken: null,
      timeout: const Duration(seconds: 60),
      timeoutError: 'انتهت مهلة الإرسال، حاول تاني',
    );
  }

  /// ترويسة الدخول لعرض الصور الخاصة، زي صور تذاكر الدعم
  static Future<Map<String, String>> imageHeaders() async {
    final token = await getAccessToken();
    return token == null || token.isEmpty ? const {} : {'Authorization': 'Bearer $token'};
  }

  /// POST Request
  static Future<ApiResponse<dynamic>> post(
    String endpoint,
    dynamic body, {
    String? customToken,
    Duration timeout = const Duration(seconds: 14),
  }) {
    final cleanEndpoint = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    final uri = Uri.parse('$_baseUrl$cleanEndpoint');
    final payload = body != null ? jsonEncode(body) : null;

    return _send(
      cleanEndpoint,
      (headers) => _client.post(uri, headers: headers, body: payload),
      customToken: customToken,
      timeout: timeout,
      timeoutError: 'انتهت مهلة إرسال البيانات إلى الخادم، يرجى إعادة المحاولة.',
    );
  }

  static Future<ApiResponse<dynamic>> put(String endpoint, dynamic body) {
    final cleanEndpoint = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    final uri = Uri.parse('$_baseUrl$cleanEndpoint');
    final payload = jsonEncode(body);

    return _send(
      cleanEndpoint,
      (headers) => _client.put(uri, headers: headers, body: payload),
      customToken: null,
      timeout: const Duration(seconds: 14),
      timeoutError: 'انتهت مهلة إرسال البيانات إلى الخادم',
    );
  }

  /// فحص خفيف لعودة الاتصال بالخادم دون أي بيانات مصادقة
  static Future<bool> checkServer() async {
    final res = await get('/health', timeout: const Duration(seconds: 6));
    return !res.isConnectivityError;
  }

  /// تنفيذ الطلب مع تجديد الجلسة مرة واحدة عند استجابة 401
  static Future<ApiResponse<dynamic>> _send(
    String endpoint,
    Future<http.Response> Function(Map<String, String> headers) request, {
    required String? customToken,
    required Duration timeout,
    required String timeoutError,
  }) async {
    try {
      final headers = await _buildHeaders(customToken: customToken);
      var response = await request(headers).timeout(timeout);

      if (response.statusCode == 401 && await _canRefreshFor(endpoint, customToken, headers)) {
        final outcome = await _refreshSession();
        if (outcome == _RefreshOutcome.unreachable) {
          return _connectivityFailure();
        }
        if (outcome == _RefreshOutcome.suspended) {
          return _accountSuspended(const ApiResponse(
            success: false,
            statusCode: 403,
            error: 'تم إيقاف هذا الحساب',
            data: {'status': 'suspended'},
          ));
        }
        if (outcome == _RefreshOutcome.refreshed) {
          response = await request(await _buildHeaders()).timeout(timeout);
        }
      }

      final parsed = await _parseResponse(response);
      isServerReachable.value = !parsed.isConnectivityError;
      if (isSuspended(parsed) && !endpoint.startsWith('/auth/')) return _accountSuspended(parsed);
      return parsed;
    } on TimeoutException {
      isServerReachable.value = false;
      return ApiResponse(
        success: false,
        statusCode: 408,
        error: timeoutError,
        isConnectivityError: true,
      );
    } on SocketException {
      return _connectivityFailure();
    } on http.ClientException {
      return _connectivityFailure();
    } on HandshakeException {
      return _connectivityFailure();
    } catch (_) {
      return const ApiResponse(
        success: false,
        statusCode: 500,
        error: 'حدث خطأ غير متوقع أثناء الاتصال بالخدمة، يرجى المحاولة مرة أخرى.',
      );
    }
  }

  /// الخادم بيقول إن الحساب موقوف، مش مجرد رفض لعملية واحدة
  static bool isSuspended(ApiResponse<dynamic> res) {
    final data = res.data;
    return res.statusCode == 403 && data is Map && data['status'] == 'suspended';
  }

  static Future<ApiResponse<dynamic>> _accountSuspended(ApiResponse<dynamic> res) async {
    if (!muteSessionExpiry) await onAccountSuspended?.call();
    return res;
  }

  static ApiResponse<dynamic> _connectivityFailure() {
    isServerReachable.value = false;
    return const ApiResponse(
      success: false,
      statusCode: 503,
      error: 'تعذر الاتصال بالخادم، يرجى التأكد من اتصال الإنترنت.',
      isConnectivityError: true,
    );
  }

  static Future<bool> _canRefreshFor(
    String endpoint,
    String? customToken,
    Map<String, String> headers,
  ) async {
    if (customToken != null || endpoint.startsWith('/auth/')) return false;
    return headers.containsKey('Authorization') || await getRefreshToken() != null;
  }

  /// طلب تجديد واحد فقط مهما تزامنت الطلبات، لأن الخادم يدوّر Refresh Token مع كل تجديد
  static Future<_RefreshOutcome> _refreshSession() {
    return _activeRefresh ??= _performRefresh().whenComplete(() {
      _activeRefresh = null;
    });
  }

  static Future<_RefreshOutcome> _performRefresh() async {
    final refreshToken = await getRefreshToken();
    if (refreshToken == null) {
      await _expireSession();
      return _RefreshOutcome.expired;
    }

    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/auth/refresh'),
            headers: const {
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json',
            },
            body: jsonEncode({'refreshToken': refreshToken}),
          )
          .timeout(const Duration(seconds: 12));

      final parsed = await _parseResponse(response);
      if (parsed.isOk && parsed.data is Map<String, dynamic>) {
        final data = parsed.data as Map<String, dynamic>;
        final newAccess = data['accessToken'] as String?;
        final newRefresh = data['refreshToken'] as String?;
        if (newAccess != null && newRefresh != null) {
          final prefs = await SharedPreferences.getInstance();
          await saveTokens(
            accessToken: newAccess,
            refreshToken: newRefresh,
            persist: prefs.containsKey(prefRefreshToken),
          );
          return _RefreshOutcome.refreshed;
        }
      }

      // الجلسة تفضل محفوظة، فالتطبيق يرجع لوحده بعد تفعيل الحساب
      if (isSuspended(parsed)) return _RefreshOutcome.suspended;

      if (response.statusCode == 401 || response.statusCode == 403) {
        await _expireSession();
        return _RefreshOutcome.expired;
      }
      return _RefreshOutcome.unreachable;
    } catch (_) {
      // انقطاع الشبكة ليس دليلاً على انتهاء الجلسة
      return _RefreshOutcome.unreachable;
    }
  }

  static Future<void> _expireSession() async {
    await clearTokens();
    if (!muteSessionExpiry) {
      await onSessionExpired?.call();
    }
  }

  static dynamic _decodeBody(Uint8List bytes) {
    try {
      return jsonDecode(utf8.decode(bytes));
    } catch (_) {
      return null;
    }
  }

  /// معالجة استجابة الـ HTTP وفك التشفير
  static Future<ApiResponse<dynamic>> _parseResponse(http.Response response) async {
    final bytes = response.bodyBytes;
    final dynamic jsonBody =
        bytes.length > _isolateDecodeThresholdBytes ? await compute(_decodeBody, bytes) : _decodeBody(bytes);

    final statusCode = response.statusCode;
    final is2xx = statusCode >= 200 && statusCode < 300;
    final isGatewayFailure = statusCode == 502 || statusCode == 503 || statusCode == 504;

    if (jsonBody is Map<String, dynamic>) {
      final hasSuccessField = jsonBody.containsKey('success');
      final success = hasSuccessField ? (jsonBody['success'] == true) : is2xx;
      final message = jsonBody['message']?.toString();
      final error = jsonBody['error']?.toString();

      return ApiResponse(
        success: success,
        statusCode: statusCode,
        message: message,
        error: success ? null : _userFacingError(statusCode, error ?? message),
        data: jsonBody['data'] ?? jsonBody,
        isConnectivityError: isGatewayFailure,
      );
    }

    return ApiResponse(
      success: is2xx,
      statusCode: statusCode,
      data: jsonBody ?? response.body,
      error: is2xx ? null : _userFacingError(statusCode, null),
      isConnectivityError: isGatewayFailure,
    );
  }

  /// لا يصل المستخدم إلا رسالة عربية مفهومة، وتحجب أي رسالة تقنية من الخادم
  static String _userFacingError(int statusCode, String? serverMessage) {
    if (serverMessage != null && RegExp(r'[؀-ۿ]').hasMatch(serverMessage)) {
      return serverMessage;
    }
    if (statusCode == 429) {
      return 'تم إرسال طلبات كثيرة، يرجى الانتظار قليلاً والمحاولة مرة أخرى.';
    }
    return 'تعذر إتمام طلبك حالياً، يرجى المحاولة مرة أخرى.';
  }
}
