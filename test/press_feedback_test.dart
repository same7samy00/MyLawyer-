import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:my_lawyer/core/widgets/app_loader.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_lawyer/core/theme/app_theme.dart';
import 'package:my_lawyer/core/widgets/app_button.dart';
import 'package:my_lawyer/core/widgets/app_card.dart';
import 'package:my_lawyer/core/widgets/app_pressable.dart';
import 'package:my_lawyer/core/widgets/keyboard_dismiss_area.dart';

Widget _host(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(body: Center(child: SizedBox(width: 280, child: child))),
    ),
  );
}

bool _isGray(WidgetTester tester, Finder pressable) {
  return tester
      .widget<PressTint>(find.descendant(of: pressable, matching: find.byType(PressTint)).first)
      .active;
}

void main() {
  group('الضغط الرمادي لكل أنواع الأزرار', () {
    final buttons = <String, Widget Function(VoidCallback)>{
      'AppButton.primary': (tap) => AppButton.primary(text: 'زر', onPressed: tap),
      'AppButton.outlined': (tap) => AppButton.outlined(text: 'زر', onPressed: tap),
      'ElevatedButton': (tap) => AppPressable(child: ElevatedButton(onPressed: tap, child: const Text('زر'))),
      'OutlinedButton': (tap) => AppPressable(child: OutlinedButton(onPressed: tap, child: const Text('زر'))),
      'TextButton': (tap) => AppPressable(child: TextButton(onPressed: tap, child: const Text('زر'))),
      'IconButton': (tap) => AppPressable(child: IconButton(onPressed: tap, icon: const Icon(Icons.add))),
      'AppCard': (tap) => AppCard(onTap: tap, child: const Text('زر')),
    };

    buttons.forEach((name, build) {
      testWidgets('$name: طبيعي ثم رمادي فوراً ثم يعود بنفس الأبعاد', (tester) async {
        int taps = 0;
        await tester.pumpWidget(_host(build(() => taps++)));

        final pressable = find.byType(AppPressable);
        final normalSize = tester.getSize(pressable);
        expect(_isGray(tester, pressable), isFalse);
        expect(find.byType(AppLoader), findsNothing);

        final gesture = await tester.startGesture(tester.getCenter(pressable));
        await tester.pump();

        expect(_isGray(tester, pressable), isTrue);
        expect(tester.getSize(pressable), normalSize);
        final tint = tester.renderObject(find.byType(PressTint).first);
        expect(tint.debugLayer, isA<ColorFilterLayer>());

        await gesture.up();
        await tester.pump(AppPressable.minimumPressedDuration);

        expect(_isGray(tester, pressable), isFalse);
        expect(tester.renderObject(find.byType(PressTint).first).debugLayer, isNull);
        expect(taps, 1);
      });
    });

    testWidgets('التمرير من فوق الزر يلغي الرمادي ولا يبقيه عالقاً', (tester) async {
      await tester.pumpWidget(_host(AppButton.primary(text: 'زر', onPressed: () {})));

      final pressable = find.byType(AppPressable);
      final gesture = await tester.startGesture(tester.getCenter(pressable));
      await tester.pump();
      expect(_isGray(tester, pressable), isTrue);

      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();
      expect(_isGray(tester, pressable), isFalse);

      await gesture.up();
    });

    testWidgets('الزر المعطل لا يتفاعل مع الضغط', (tester) async {
      await tester.pumpWidget(_host(const AppPressable(
        child: ElevatedButton(onPressed: null, child: Text('زر')),
      )));

      final pressable = find.byType(AppPressable);
      final gesture = await tester.startGesture(tester.getCenter(pressable));
      await tester.pump();
      expect(_isGray(tester, pressable), isFalse);
      await gesture.up();
    });

    test('الثيم بلا Ripple وبلا Hover على مستوى التطبيق', () {
      final theme = AppTheme.lightTheme;
      expect(theme.splashFactory, NoSplash.splashFactory);
      expect(theme.hoverColor, Colors.transparent);
      expect(theme.highlightColor, Colors.transparent);

      const states = {WidgetState.hovered};
      expect(theme.elevatedButtonTheme.style!.overlayColor!.resolve(states), Colors.transparent);
      expect(theme.outlinedButtonTheme.style!.overlayColor!.resolve(states), Colors.transparent);
      expect(theme.textButtonTheme.style!.overlayColor!.resolve(states), Colors.transparent);
      expect(theme.iconButtonTheme.style!.overlayColor!.resolve(states), Colors.transparent);
    });

    testWidgets('هيئة الزر الطبيعية محفوظة: الحواف 24 والارتفاع والخط', (tester) async {
      await tester.pumpWidget(_host(AppButton.primary(text: 'زر', onPressed: () {})));

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      final shape = button.style!.shape!.resolve({}) as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(24.0));
      expect(tester.getSize(find.byType(ElevatedButton)).height, 50.0);
      final text = tester.widget<Text>(find.text('زر'));
      expect(text.style!.fontFamily, 'AppFont');
      expect(text.style!.fontWeight, FontWeight.w800);
    });
  });

  group('التحميل داخل الزر', () {
    testWidgets('الإجراء الفوري لا يظهر معه Loading', (tester) async {
      await tester.pumpWidget(_host(AppButton.primary(text: 'زر', onPressed: () {})));

      await tester.tap(find.byType(AppButton));
      await tester.pump();

      expect(find.byType(AppLoader), findsNothing);
    });

    testWidgets('Loading يبقى حتى نجاح العملية الحقيقية مع الرمادي وثبات الأبعاد ومنع التكرار', (tester) async {
      final completer = Completer<void>();
      int calls = 0;
      await tester.pumpWidget(_host(AppButton.primary(
        text: 'زر',
        onPressed: () {
          calls++;
          return completer.future;
        },
      )));

      final pressable = find.byType(AppPressable);
      final normalSize = tester.getSize(pressable);

      await tester.tap(find.byType(AppButton));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(AppLoader), findsOneWidget);
      expect(_isGray(tester, pressable), isTrue);
      expect(tester.getSize(pressable), normalSize);

      await tester.tap(find.byType(AppButton), warnIfMissed: false);
      await tester.tap(find.byType(AppButton), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 200));
      expect(calls, 1);

      completer.complete();
      await tester.pump();
      await tester.pump(AppPressable.minimumPressedDuration);

      expect(find.byType(AppLoader), findsNothing);
      expect(_isGray(tester, pressable), isFalse);

      await tester.tap(find.byType(AppButton));
      await tester.pump();
      expect(calls, 2);
    });

    testWidgets('Loading ينتهي عند الفشل ويعود الزر قابلاً للضغط', (tester) async {
      int calls = 0;
      String? shownError;
      await tester.pumpWidget(_host(StatefulBuilder(
        builder: (context, setState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (shownError != null) Text(shownError!),
            AppButton.primary(
              text: 'زر',
              onPressed: () async {
                calls++;
                await Future<void>.delayed(const Duration(milliseconds: 50));
                setState(() => shownError = 'تعذر إتمام طلبك');
              },
            ),
          ],
        ),
      )));

      await tester.tap(find.byType(AppButton));
      await tester.pump();
      expect(find.byType(AppLoader), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump();

      expect(find.byType(AppLoader), findsNothing);
      expect(find.text('تعذر إتمام طلبك'), findsOneWidget);

      await tester.tap(find.byType(AppButton));
      await tester.pump();
      expect(calls, 2);
      await tester.pump(const Duration(milliseconds: 60));
    });

    testWidgets('خروج الزر من الشاشة أثناء العملية لا يسبب خطأ', (tester) async {
      final completer = Completer<void>();
      await tester.pumpWidget(_host(AppButton.primary(text: 'زر', onPressed: () => completer.future)));

      await tester.tap(find.byType(AppButton));
      await tester.pump();

      await tester.pumpWidget(_host(const SizedBox.shrink()));
      completer.complete();
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  group('لوحة المفاتيح', () {
    testWidgets('الضغط على مكان فارغ يغلقها والضغط على زر لا يضيع', (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      int taps = 0;
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => KeyboardDismissArea(child: child!),
        home: Scaffold(
          body: Column(
            children: [
              TextField(focusNode: focus),
              ElevatedButton(onPressed: () => taps++, child: const Text('زر')),
            ],
          ),
        ),
      ));

      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(focus.hasFocus, isTrue);

      await tester.tap(find.text('زر'));
      await tester.pump();
      expect(taps, 1);
      expect(focus.hasFocus, isTrue);

      await tester.tapAt(const Offset(400, 500));
      await tester.pump();
      expect(focus.hasFocus, isFalse);
    });
  });

  group('خط التطبيق', () {
    test('النصوص تستخدم خط الأرقام الإنجليزية ثم الخط الأساسي', () {
      final style = AppTheme.lightTheme.textTheme.bodyMedium!;
      expect(style.fontFamily, 'AppFont');
      expect(style.fontFamilyFallback, ['IBMPlexSansArabic']);
    });

    test('كل نص يحدد الخط الأساسي صراحة', () {
      final files = Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

      for (final file in files) {
        final source = file.readAsStringSync();
        final uses = "fontFamily: 'AppFont'".allMatches(source).length;
        expect('fontFamilyFallback: appFontFallback'.allMatches(source).length, uses, reason: file.path);
      }
    });
  });

  group('اتجاه الأسهم في RTL', () {
    testWidgets('سهم المتابعة يأتي بعد النص، أي على يساره', (tester) async {
      await tester.pumpWidget(_host(AppButton.primary(
        text: 'التالي',
        icon: Icons.arrow_forward_rounded,
        onPressed: () {},
      )));

      final arrow = tester.getCenter(find.byIcon(Icons.arrow_forward_rounded));
      final label = tester.getCenter(find.text('التالي'));
      expect(arrow.dx, lessThan(label.dx));
    });

    test('كل زر رجوع يستخدم سهم الرجوع وكل زر متابعة يستخدم سهم المتابعة', () {
      final files = Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

      for (final file in files) {
        final source = file.readAsStringSync();
        // الأيقونتان تنعكسان تلقائياً في RTL، فالاسم يعبر عن المعنى لا عن الاتجاه المرئي
        expect(source, isNot(contains('Icon(Icons.arrow_forward_rounded, color: AppColors.dark)')), reason: file.path);
        expect(source, isNot(contains('icon: Icons.arrow_back_rounded,')), reason: file.path);
        expect(source, isNot(contains('Icons.chevron_left_rounded')), reason: file.path);
      }
    });
  });
}
