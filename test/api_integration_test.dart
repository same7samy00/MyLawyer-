import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_lawyer/core/services/api_service.dart';

class _AllowNetworkHttpOverrides extends HttpOverrides {}

/// اختبارات اتصال اختيارية بالخادم، وكلها للقراءة فقط ولا تغيّر أي بيانات
/// لا تعمل إلا بطلب صريح، ولا تُكتب أي بيانات دخول في الكود:
/// flutter test test/api_integration_test.dart --dart-define=RUN_LIVE_API_TESTS=true
/// لاختبار الدخول أضف LIVE_CLIENT_ID وLIVE_CLIENT_PASSWORD لحساب اختبار مخصص
void main() {
  const runLiveTests = bool.fromEnvironment('RUN_LIVE_API_TESTS');
  const liveClientId = String.fromEnvironment('LIVE_CLIENT_ID');
  const liveClientPassword = String.fromEnvironment('LIVE_CLIENT_PASSWORD');

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = _AllowNetworkHttpOverrides();
    SharedPreferences.setMockInitialValues({});
  });

  group('MyLawyer Production Backend & API Tests', () {
    test('Backend Health Check returns status UP and database CONNECTED', () async {
      final res = await ApiService.get('/health');
      expect(res.isOk, isTrue);
      expect(res.data, isA<Map<String, dynamic>>());
      final map = res.data as Map<String, dynamic>;
      expect(map['status'], equals('UP'));
      expect(map['database'], equals('CONNECTED'));
    });

    test('Nearby Lawyers query with Cairo coordinates returns accredited lawyers', () async {
      final res = await ApiService.get('/lawyers/nearby', queryParams: {
        'lat': '30.0444',
        'lon': '31.2357',
      });
      expect(res.isOk, isTrue);
      expect(res.data, isA<List>());
    });

    test(
      'Dedicated test account login returns a valid JWT session',
      () async {
        final res = await ApiService.post('/auth/login', {
          'identifier': liveClientId,
          'password': liveClientPassword,
        });
        expect(res.isOk, isTrue);
        expect((res.data as Map<String, dynamic>).containsKey('accessToken'), isTrue);
      },
      skip: liveClientId.isEmpty ? 'يتطلب LIVE_CLIENT_ID وLIVE_CLIENT_PASSWORD' : false,
    );
  }, skip: runLiveTests ? false : 'اختبارات الخادم الحي تعمل فقط مع RUN_LIVE_API_TESTS=true');
}
