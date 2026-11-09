import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_lawyer/core/widgets/auth_error_banner.dart';

void main() {
  test('الأيقونة على قد المشكلة', () {
    expect(AuthErrorBanner.iconFor('كلمة المرور غير صحيحة'), Icons.lock_outline_rounded);
    expect(AuthErrorBanner.iconFor('الحساب غير مسجل'), Icons.person_off_outlined);
    expect(AuthErrorBanner.iconFor('تعذر الاتصال بالخادم'), Icons.wifi_off_rounded);
  });

  test('الرسالة الطويلة تتقسم على سطرين، والقصيرة تفضل سطر', () {
    expect(AuthErrorBanner.split('كلمة المرور غير صحيحة'), ('كلمة المرور غير صحيحة', null));
    final (title, details) = AuthErrorBanner.split('الحساب غير مسجل، اعمل حساب جديد أو تأكد من رقم الموبايل');
    expect(title, 'الحساب غير مسجل');
    expect(details, 'اعمل حساب جديد أو تأكد من رقم الموبايل');
  });
}
