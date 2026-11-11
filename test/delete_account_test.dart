import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_lawyer/core/theme/app_theme.dart';
import 'package:my_lawyer/features/account/terms_privacy_screen.dart';

void main() {
  testWidgets('صفحة الشروط فيها حذف الحساب، والنافذة بتطلب كلمة السر قبل ما تبعت', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: const Directionality(textDirection: TextDirection.rtl, child: TermsPrivacyScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('الشروط والأحكام'), findsOneWidget);
    expect(find.text('حذف الحساب'), findsWidgets, reason: 'the section title and the button');

    await tester.tap(find.text('حذف الحساب').last);
    await tester.pumpAndSettle();
    expect(find.text('حذف حسابي'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'كلمة السر'), findsOneWidget);

    // From an empty password the sheet asks for it and sends nothing
    await tester.tap(find.text('حذف حسابي'));
    await tester.pumpAndSettle();
    expect(find.text('اكتب كلمة السر عشان نتأكد إنه حسابك'), findsOneWidget);

    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
    expect(find.text('حذف حسابي'), findsNothing);
  });
}
