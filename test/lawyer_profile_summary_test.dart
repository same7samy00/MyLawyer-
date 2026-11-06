import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_lawyer/core/widgets/lawyer_profile_summary.dart';

void main() {
  Widget buildSummary({required bool isNearest}) {
    return MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: 284,
              child: SingleChildScrollView(
                child: LawyerProfileSummary(
                  avatar: const SizedBox(width: 56, height: 56),
                  name: 'الأستاذ الدكتور عبد الرحمن محمد عبد العزيز الشافعي',
                  rating: 4.9,
                  reviewsCount: 1250,
                  experienceYears: 25,
                  distanceText: '12.4 كم',
                  distanceCaption: '45 دقيقة تقريباً',
                  isNearest: isNearest,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('LawyerProfileSummary shows all sections without overflow on narrow sheets', (tester) async {
    await tester.pumpWidget(buildSummary(isNearest: true));

    expect(tester.takeException(), isNull);
    expect(find.text('الأقرب إليك'), findsOneWidget);
    expect(find.text('1250 تقييم'), findsOneWidget);
    expect(find.text('سنوات خبرة'), findsOneWidget);
    expect(find.text('12.4 كم'), findsOneWidget);
    expect(find.text('45 دقيقة تقريباً'), findsOneWidget);
  });

  testWidgets('LawyerProfileSummary hides the nearest badge for other lawyers', (tester) async {
    await tester.pumpWidget(buildSummary(isNearest: false));

    expect(find.text('الأقرب إليك'), findsNothing);
  });
}
