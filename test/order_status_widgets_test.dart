import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_lawyer/core/services/external_navigation.dart';
import 'package:my_lawyer/core/services/routing_service.dart';
import 'package:my_lawyer/core/widgets/order_status_tracker.dart';
import 'package:my_lawyer/core/widgets/response_countdown.dart';
import 'package:my_lawyer/data/models/order_model.dart';

OrderModel _order(String status, {Map<String, dynamic> extra = const {}}) {
  return OrderModel.fromJson({'orderId': 'order-1', 'status': status, ...extra});
}

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  group('مراحل شريط التتبع', () {
    test('كل حالة جارية تقف عند مرحلتها', () {
      expect(_order('PENDING').trackerDoneSteps, 1);
      expect(_order('ACCEPTED').trackerDoneSteps, 2);
      expect(_order('ACTIVE').trackerDoneSteps, 3);
      expect(_order('ACTIVE', extra: {'arrivedAt': '2026-11-01T10:00:00Z'}).trackerDoneSteps, 4);
      expect(_order('COMPLETED').trackerDoneSteps, 5);
    });

    test('الطلب المنتهي يوضح مرحلة توقفه', () {
      expect(_order('NO_RESPONSE').trackerFailedStep, 1);
      expect(_order('PAYMENT_EXPIRED', extra: {'acceptedAt': '2026-11-01T10:00:00Z'}).trackerFailedStep, 2);
      expect(_order('ACTIVE').trackerFailedStep, isNull);
      expect(_order('COMPLETED').trackerFailedStep, isNull);
    });
  });

  test('الوقت يظهر كمدى', () {

    const estimate = RouteEstimate(distanceMeters: 9000, durationSeconds: 900, trafficFactor: 1.8);
    expect(estimate.arrivalRangeText, 'حوالي 20 إلى 35 دقيقة');
    expect(const RouteEstimate(distanceMeters: 300, durationSeconds: 120).arrivalRangeText, 'أقل من 5 دقايق');
  });

  test('رابط الاتجاهات يحمل موقع الموكل', () {
    final uri = ExternalNavigation.directionsUri(30.79, 31.0);

    expect(uri.host, 'www.google.com');
    expect(uri.queryParameters['destination'], '30.79,31.0');
  });

  testWidgets('الشريط يعرض المراحل ونص الحالة', (tester) async {
    await tester.pumpWidget(_wrap(OrderStatusTracker(order: _order('ACCEPTED'))));

    expect(find.text('القبول'), findsOneWidget);
    expect(find.text('الإنهاء'), findsOneWidget);
    expect(find.text('تم قبول الطلب • بانتظار السداد'), findsOneWidget);
  });

  testWidgets('العداد يعرض الثواني الباقية وانتهاء الوقت', (tester) async {
    await tester.pumpWidget(_wrap(const ResponseCountdown(key: ValueKey('a'), secondsLeft: 42)));
    expect(find.text('باقي 42 ثانية للرد'), findsOneWidget);

    await tester.pumpWidget(_wrap(const ResponseCountdown(key: ValueKey('b'), secondsLeft: 0)));
    expect(find.text('انتهى وقت الرد'), findsOneWidget);
  });
}
