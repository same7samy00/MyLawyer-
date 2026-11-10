import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_lawyer/core/config/app_config.dart';
import 'package:my_lawyer/features/auth/update_required_screen.dart';

void main() {
  test('رقم النسخة في الكود هو نفسه اللي في pubspec.yaml', () {
    final version = File('pubspec.yaml').readAsLinesSync().firstWhere((line) => line.startsWith('version:'));
    expect(int.parse(version.split('+').last.trim()), AppConfig.build);
  });

  testWidgets('صفحة التحديث الإجباري فيها زرار التحديث لما الخادم يبعت الرابط بس', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: UpdateRequiredScreen(updateUrl: 'https://my-lawyer.online/app')));
    expect(find.text('حدّث التطبيق'), findsOneWidget);
    expect(find.text('حدّث دلوقتي'), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(home: UpdateRequiredScreen()));
    expect(find.text('حدّث دلوقتي'), findsNothing);
  });
}
