import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_lawyer/core/constants/app_colors.dart';
import 'package:my_lawyer/core/widgets/app_button.dart';
import 'package:my_lawyer/core/widgets/app_choice_chip.dart';
import 'package:my_lawyer/data/models/field_info.dart';
import 'package:my_lawyer/data/models/order_model.dart';
import 'package:my_lawyer/data/models/service_request.dart';
import 'package:my_lawyer/features/field_service/field_order_blocks.dart';
import 'package:my_lawyer/features/field_service/field_pin_screen.dart';
import 'package:my_lawyer/features/field_service/field_services.dart';

Map<String, dynamic> _fieldJson({Map<String, dynamic> extra = const {}}) => {
      'forOther': true,
      'personName': 'أحمد',
      'relation': 'صديق',
      'detained': true,
      'placeName': 'قسم المعادي',
      'placeKind': 'police',
      'code': '4821',
      'codeLocked': false,
      'proofs': 1,
      ...extra,
    };

void main() {
  group('الخدمات الميدانية: النموذج', () {
    test('الطلب الميداني بيقرا تفاصيله، والعادي من غيرها', () {
      final field = OrderModel.fromJson({'orderId': 'o1', 'status': 'ACTIVE', 'field': _fieldJson()}).field;
      expect(field, isNotNull);
      expect(field!.forOther, isTrue);
      expect(field.code, '4821');
      expect(field.personLine, 'أحمد (صديق)');
      expect(field.canTypeCode, isTrue);
      expect(field.canAddProof, isTrue);
      expect(OrderModel.fromJson({'orderId': 'o2', 'status': 'ACTIVE'}).field, isNull);
    });

    test('الكود المقفول ما يتكتبش، والصور لحد خمسة', () {
      final locked = FieldInfo.fromJson(_fieldJson(extra: {'codeLocked': true, 'proofs': 5}))!;
      expect(locked.canTypeCode, isFalse);
      expect(locked.canAddProof, isFalse);
      expect(FieldInfo.fromJson(_fieldJson(extra: {'forOther': false}))!.canTypeCode, isFalse);
    });

    test('لنفسي: السطر «الموكل نفسه»', () {
      expect(FieldInfo.fromJson(_fieldJson(extra: {'forOther': false, 'personName': null}))!.personLine, 'الموكل نفسه');
    });

    test('طلب المحامي الجديد بيعرف إنه ميداني ولشخص محبوس', () {
      final request = IncomingRequest.fromJson({
        'id': 'r1',
        'service': 'محضر في قسم الشرطة',
        'problemType': 'محضر في قسم الشرطة',
        'distanceKm': 2,
        'minPrice': 300,
        'maxPrice': 500,
        'netRate': 0.8,
        'secondsLeft': 100,
        'field': {'forOther': true, 'detained': true, 'placeKind': 'police'},
      });
      expect(request.field?.detained, isTrue);
      expect(FieldInfo.kindLabel(request.field!.placeKind), 'قسم شرطة');
      expect(IncomingRequest.fromJson({'id': 'r2', 'distanceKm': 1, 'minPrice': 1, 'maxPrice': 2, 'netRate': 1, 'secondsLeft': 1}).field, isNull);
    });

    test('المسودة بتتبعت بالمكان وبيانات الشخص بس لما يكون لشخص تاني', () {
      const place = FieldPlace(name: 'قسم المعادي', lat: 30.05, lon: 31.25);
      final other = const FieldDraft(serviceTitle: 'محضر في قسم الشرطة', description: 'وصف', place: place, forOther: true, personName: 'أحمد', relation: 'صديق', detained: true).toJson();
      expect(other['placeName'], 'قسم المعادي');
      expect(other['personName'], 'أحمد');
      expect(other['detained'], isTrue);
      final mine = const FieldDraft(serviceTitle: 'حضور جلسة', description: 'وصف', place: place, personName: 'تجاهل', detained: true).toJson();
      expect(mine.containsKey('personName'), isFalse);
      expect(mine['detained'], isFalse);
    });
  });

  group('الخدمات الميدانية: القوايم', () {
    test('الخمس خدمات ميدانية، والباقي لأ', () {
      for (final title in ['محضر في قسم الشرطة', 'تحقيق عاجل في النيابة العامة', 'حضور جلسة', 'حضور مجلس عرفي', 'إجراءات إدارية']) {
        expect(FieldServices.isField(title), isTrue, reason: title);
      }
      expect(FieldServices.isField('سرقة أو نصب أو احتيال'), isFalse);
      expect(FieldServices.isField(null), isFalse);
    });

    test('سؤال المحبوس في القسم والنيابة بس', () {
      expect(FieldServices.asksDetained('محضر في قسم الشرطة'), isTrue);
      expect(FieldServices.asksDetained('تحقيق عاجل في النيابة العامة'), isTrue);
      expect(FieldServices.asksDetained('حضور جلسة'), isFalse);
    });
  });

  testWidgets('كارت الكود بيعرض الكود وزرارين: نسخ وشير', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: FieldCodeCard(code: '4821', placeName: 'قسم المعادي', onNotice: (_) {})),
        ),
      ),
    );
    expect(find.text('4821'), findsOneWidget);
    expect(find.text('نسخ الكود'), findsOneWidget);
    expect(find.text('شير'), findsOneWidget);
  });

  testWidgets('مكان الشخص التاني: المحافظة وبعدين الخريطة، والتأكيد مقفول لحد ما يقرّب', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Directionality(textDirection: TextDirection.rtl, child: FieldPinScreen(serviceTitle: 'محضر في قسم الشرطة')),
      ),
    );
    expect(find.text('اختار المحافظة'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.text('الغربية'));
    await tester.pump();
    expect(find.text('محافظة الغربية'), findsOneWidget);
    expect(find.text('قرّب أكتر عشان تحدد المكان بالظبط'), findsOneWidget);
    final confirm = tester.widget<AppButton>(find.widgetWithText(AppButton, 'تأكيد المكان'));
    expect(confirm.onPressed, isNull);

    // «تغيير» بيرجع لقايمة المحافظات
    await tester.tap(find.text('تغيير'));
    await tester.pump();
    expect(find.text('اختار المحافظة'), findsOneWidget);
  });

  test('كل المحافظات ليها عاصمة جوه مصر', () {
    expect(FieldServices.governorates.length, 27);
    for (final (lat, lon) in FieldServices.governorates.values) {
      expect(lat, inInclusiveRange(22.0, 31.7));
      expect(lon, inInclusiveRange(24.7, 36.9));
    }
  });

  testWidgets('الاختيار المختار أزرق ونصه أبيض ومن غير علامة صح', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              AppChoiceChip(label: 'أخ', selected: true, onSelected: (_) {}),
              AppChoiceChip(label: 'أخت', selected: false, onSelected: (_) {}),
            ],
          ),
        ),
      ),
    );
    final chips = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip)).toList();
    expect(chips.every((chip) => chip.showCheckmark == false), isTrue);
    expect(chips.first.selectedColor, AppColors.primary);
    expect(chips.first.labelStyle?.color, Colors.white);
    expect(chips.last.labelStyle?.color, AppColors.textMain);
    expect(find.byIcon(Icons.check), findsNothing);
  });
}
