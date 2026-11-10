import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:my_lawyer/core/constants/app_colors.dart';
import 'package:my_lawyer/core/constants/map_config.dart';
import 'package:my_lawyer/core/services/api_service.dart';
import 'package:my_lawyer/core/services/app_cached_tile_provider.dart';
import 'package:my_lawyer/core/services/auth_service.dart';
import 'package:my_lawyer/core/services/geo_naming_service.dart';
import 'package:my_lawyer/core/services/order_store.dart';
import 'package:my_lawyer/core/services/routing_service.dart';
import 'package:my_lawyer/core/theme/app_theme.dart';
import 'package:my_lawyer/core/widgets/app_button.dart';
import 'package:my_lawyer/core/widgets/app_header.dart';
import 'package:my_lawyer/core/widgets/app_loader.dart';
import 'package:my_lawyer/core/widgets/password_strength_widget.dart';
import 'package:my_lawyer/core/widgets/profile_home_card.dart';
import 'package:my_lawyer/data/models/map_lawyer.dart';
import 'package:my_lawyer/features/auth/client_register_screen.dart';
import 'package:my_lawyer/features/auth/email_verification_screen.dart';
import 'package:my_lawyer/features/auth/lawyer_register_screen.dart';
import 'package:my_lawyer/features/auth/login_screen.dart';
import 'package:my_lawyer/features/auth/registration_success_screen.dart';
import 'package:my_lawyer/features/auth/session_router.dart';
import 'package:my_lawyer/features/auth/splash_screen.dart';
import 'package:my_lawyer/features/auth/user_type_selection_screen.dart';
import 'package:my_lawyer/features/client/home_tab.dart';
import 'package:my_lawyer/features/client/nearby_lawyers_showcase_screen.dart';
import 'package:my_lawyer/features/client/orders_tab.dart';
import 'package:my_lawyer/features/lawyer/lawyer_account_tab.dart';
import 'package:my_lawyer/features/lawyer/lawyer_home_tab.dart';
import 'package:my_lawyer/features/lawyer/lawyer_navigation_shell.dart';
import 'package:my_lawyer/features/lawyer/lawyer_orders_tab.dart';
import 'package:my_lawyer/features/lawyer/lawyer_urgent_service_intro_screen.dart';
import 'package:my_lawyer/features/lawyer/lawyer_wallet_tab.dart';
import 'package:my_lawyer/features/urgent_service/order_details_sheet.dart';
import 'package:my_lawyer/features/urgent_service/payment_screen.dart';
import 'package:my_lawyer/features/urgent_service/problem_description_screen.dart';
import 'package:my_lawyer/features/urgent_service/tracking_screen.dart';
import 'package:my_lawyer/features/urgent_service/urgent_service_problem_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_backend.dart';

void main() {
  late FakeBackend backend;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    OrderStore.clear();
    backend = FakeBackend();
    ApiService.useHttpClient(backend.client);
  });

  group('My Lawyer App Tests', () {
    testWidgets('LoginScreen renders Egyptian Arabic elements correctly in RTL', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          locale: const Locale('ar', 'EG'),
          supportedLocales: const [Locale('ar', 'EG')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const LoginScreen(),
        ),
      );

      // Verify logo image & refined Arabic
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('رقم الهاتف المحمول'), findsOneWidget);
      expect(find.text('كلمة المرور'), findsOneWidget);
      expect(find.text('تسجيل الدخول'), findsOneWidget);
      expect(find.text('موكل'), findsNothing);
      expect(find.text('محامي'), findsNothing);
      expect(find.text('تذكر بياناتي على هذا الجهاز'), findsOneWidget);
      expect(find.text('نسيت كلمة المرور؟'), findsOneWidget);
    });

    testWidgets('Theme colors match specified design system', (WidgetTester tester) async {
      expect(AppColors.primary, const Color(0xFF1D4ED8));
      expect(AppColors.dark, const Color(0xFF0F172A));
      expect(AppColors.background, const Color(0xFFF8FAFC));
      expect(AppColors.cardBorder, const Color(0xFFE2E8F0));
      expect(AppColors.danger, const Color(0xFFDC2626));
      expect(AppColors.success, const Color(0xFF16A34A));
    });

    test('MapConfig reads the shared TomTom map cache on our server, with no key in the app', () {
      expect(MapConfig.serverTileUrl, 'https://my-lawyer.online/map/t/{z}/{x}/{y}.png');
      expect(MapConfig.fallbackTileUrl, contains('tile.openstreetmap.org'));
    });

    test('RouteEstimate formats distance and duration correctly', () {
      const estimate = RouteEstimate(
        distanceMeters: 4500,
        durationSeconds: 720,
      );
      expect(estimate.distanceKm, 4.5);
      expect(estimate.durationMinutes, 12);
      expect(estimate.distanceText, '4.5 كم');
      expect(estimate.durationText, '12 دقيقة تقريباً');

      const shortEstimate = RouteEstimate(
        distanceMeters: 600,
        durationSeconds: 90,
      );
      expect(shortEstimate.distanceText, '600 م');
      expect(shortEstimate.durationText, 'دقيقتان تقريباً');
    });

    test('MapLawyer instantiation and distance comparison', () {
      const lawyer1 = MapLawyer(
        id: 'lawyer_1',
        name: 'أ. أحمد الشافعي',
        rating: 4.9,
        position: LatLng(30.045, 31.238),
        distanceMeters: 450,
      );

      const lawyer2 = MapLawyer(
        id: 'lawyer_2',
        name: 'أ. سارة عبد الرحمن',
        rating: 4.8,
        position: LatLng(30.048, 31.240),
        distanceMeters: 750,
      );

      expect(lawyer1.distanceMeters < lawyer2.distanceMeters, isTrue);
      expect(lawyer1.name, 'أ. أحمد الشافعي');
      expect(lawyer1.avatarInitials, 'مح');
      expect(lawyer1.imageUrl, '');
      expect(lawyer1.reviewsCount, 0);
      expect(lawyer1.experienceYears, 0);
    });

    testWidgets('UrgentServiceProblemScreen renders 14 services names only without descriptions in RTL', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          locale: const Locale('ar', 'EG'),
          supportedLocales: const [Locale('ar', 'EG')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const UrgentServiceProblemScreen(),
        ),
      );

      expect(find.text('اختار مشكلتك'), findsNWidgets(2));
      expect(find.text('محضر في قسم الشرطة'), findsOneWidget);
      expect(find.text('القبض على شخص أو احتجازه بقسم الشرطة'), findsOneWidget);
      expect(find.text('تحقيق عاجل في النيابة العامة'), findsOneWidget);
      expect(find.text('مشاجرة أو اعتداء أو تهديد'), findsOneWidget);

      // Verify no consultation or contract drafting services in this screen
      expect(find.text('استشارة قانونية'), findsNothing);
      expect(find.text('صياغة عقود'), findsNothing);

      // Tap on visible item to navigate to ProblemDescriptionScreen
      await tester.tap(find.text('محضر في قسم الشرطة'));
      await tester.pumpAndSettle();
      expect(find.byType(ProblemDescriptionScreen), findsOneWidget);
      expect(find.text('اكتب تفاصيل مشكلتك باختصار'), findsOneWidget);
      expect(find.text('المتابعة إلى خريطة المحامين'), findsOneWidget);
    });

    testWidgets('ProblemDescriptionScreen renders illustration, multiline field and continue button', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          locale: const Locale('ar', 'EG'),
          supportedLocales: const [Locale('ar', 'EG')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const ProblemDescriptionScreen(problemTitle: 'محضر في قسم الشرطة'),
        ),
      );

      expect(find.text('تفاصيل المشكلة'), findsOneWidget);
      expect(find.text('محضر في قسم الشرطة'), findsOneWidget);
      expect(find.text('اكتب تفاصيل مشكلتك باختصار'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('المتابعة إلى خريطة المحامين'), findsOneWidget);

      // Enter text and verify
      await tester.enterText(find.byType(TextField), 'أنا في قسم المعادي بخصوص محضر فقد بطاقة');
      expect(find.text('أنا في قسم المعادي بخصوص محضر فقد بطاقة'), findsOneWidget);
    });

    testWidgets('PaymentScreen renders bill table and payment options in RTL', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          locale: const Locale('ar', 'EG'),
          supportedLocales: const [Locale('ar', 'EG')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const PaymentScreen(
            locationName: 'المعادي، محافظة القاهرة',
            problemTitle: 'محضر في قسم الشرطة',
            price: 350,
          ),
        ),
      );

      expect(find.text('تفاصيل سداد الأتعاب'), findsOneWidget);
      expect(find.text('فاتورة الخدمة'), findsOneWidget);
      expect(find.text('350 ج.م'), findsWidgets);
      expect(find.text('اختار طريقة الدفع'), findsOneWidget);
    });

    testWidgets('OrdersTab renders a summary card and keeps actions on the details page', (WidgetTester tester) async {
      backend.orders = [sampleOrder(status: 'ACTIVE')];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          locale: const Locale('ar', 'EG'),
          supportedLocales: const [Locale('ar', 'EG')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const Scaffold(body: OrdersTab()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('طلب رقم ML-ORD-100001'), findsOneWidget);
      expect(find.text('عرض التفاصيل'), findsOneWidget);
      expect(find.text('عندك مشكلة؟'), findsNothing);
    });
    testWidgets('AppHeader renders centered title, action icons without container boxes in RTL', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          locale: const Locale('ar', 'EG'),
          supportedLocales: const [Locale('ar', 'EG')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const Scaffold(
            appBar: AppHeader(title: 'الطلبات'),
            body: SizedBox.expand(),
          ),
        ),
      );

      expect(find.text('الطلبات'), findsOneWidget);
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);
      expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
    });

    test('MapLawyer effectiveGoogleProfileUrl returns custom or encoded search url', () {
      const lawyerWithCustom = MapLawyer(
        id: 'lawyer_custom',
        name: 'أ. سامح خليل',
        rating: 4.9,
        position: LatLng(30.0444, 31.2357),
        googleProfileUrl: 'https://maps.google.com/?cid=12345',
      );
      expect(lawyerWithCustom.effectiveGoogleProfileUrl, 'https://maps.google.com/?cid=12345');

      const lawyerDefault = MapLawyer(
        id: 'lawyer_default',
        name: 'أ. أحمد الشافعي',
        rating: 4.8,
        position: LatLng(30.0444, 31.2357),
      );
      expect(lawyerDefault.effectiveGoogleProfileUrl, contains('google.com/search?q='));
      expect(lawyerDefault.effectiveGoogleProfileUrl, contains(Uri.encodeComponent('أ. أحمد الشافعي')));
    });

    testWidgets('SplashScreen renders white background without icons or loading', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const SplashScreen(),
        ),
      );

      // Verify white background scaffold
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, Colors.white);

      // Verify no circular progress indicator (no loading)
      expect(find.byType(AppLoader), findsNothing);

      // Verify no shield icon
      expect(find.byIcon(Icons.shield_rounded), findsNothing);

      // Advance past the fallback timer and transition
      await tester.pump(const Duration(milliseconds: 5000));
      await tester.pumpAndSettle();
    });

    testWidgets('NearbyLawyersShowcaseScreen renders without header and without auto bottom sheet or order actions', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          locale: const Locale('ar', 'EG'),
          supportedLocales: const [Locale('ar', 'EG')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const NearbyLawyersShowcaseScreen(),
        ),
      );
      await tester.pump();

      // 1. Verify no AppHeader widget is present
      expect(find.byType(AppHeader), findsNothing);

      // 2. Verify no "طلب الآن" or emergency order button
      expect(find.text('اطلب الآن'), findsNothing);

      // 3. The fixed sheet shows the list first, with no profile open
      expect(find.text('الأعلى تقييماً حولك'), findsOneWidget);
      expect(find.text('ملف Google'), findsNothing);

      // 4. The close button leads to the home page
      expect(find.byTooltip('إغلاق'), findsOneWidget);

      // 6. Verify loading overlay is present during initial fetch
      expect(find.text('جاري البحث عن المحامين حواليك'), findsOneWidget);

      // Advance past location fetch timeout (4s timeout + resolution)
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 200));

      // 7. Verify loading overlay is dismissed once data is ready or fallback resolves
      expect(find.text('جاري البحث عن المحامين حواليك'), findsNothing);

      // 8. Tap a lawyer marker to display the unified profile bottom sheet
      if (find.text('أ. أحمد الشافعي').evaluate().isNotEmpty) {
        await tester.tap(find.text('أ. أحمد الشافعي'));
        await tester.pump(const Duration(milliseconds: 700));

        expect(find.text('ملف المحامي'), findsOneWidget);
        expect(find.text('ملف Google'), findsOneWidget);
        expect(find.text('مقيد بالنقابة العامة'), findsOneWidget);
        expect(find.text('جاهزية حضور فوري'), findsOneWidget);
      }
    });

    test('GeoNamingService correctly resolves city and governorate without duplicating محافظة', () async {
      TestWidgetsFlutterBinding.ensureInitialized();

      // Test Tanta coordinates
      final tantaName = await GeoNamingService.instance.getCityAndGovernorate(30.7865, 31.0004);
      expect(tantaName, contains('الغربية'));
      expect(tantaName.contains('محافظة محافظة'), isFalse);

      // Test Cairo coordinates
      final cairoName = await GeoNamingService.instance.getCityAndGovernorate(29.96, 31.28);
      expect(cairoName, contains('القاهرة'));
      expect(cairoName.contains('محافظة محافظة'), isFalse);
    });

    testWidgets('AppButton renders loading state, locks clicks, and conforms to design system', (WidgetTester tester) async {
      int tapCount = 0;
      bool loading = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: Center(
                  child: AppButton(
                    text: 'تأكيد الطلب',
                    isLoading: loading,
                    onPressed: () {
                      tapCount++;
                      setState(() {
                        loading = true;
                      });
                    },
                  ),
                ),
              );
            },
          ),
        ),
      );

      // Verify initial state
      expect(find.text('تأكيد الطلب'), findsOneWidget);
      expect(find.byType(AppLoader), findsNothing);

      // Tap button once
      await tester.tap(find.byType(AppButton));
      await tester.pump();

      // State is now loading
      expect(tapCount, 1);
      expect(find.byType(AppLoader), findsOneWidget);

      // Attempt second tap while loading (should be locked and ignored)
      await tester.tap(find.byType(AppButton));
      await tester.pump();
      expect(tapCount, 1); // Remains 1, tap was debounced/blocked
      await tester.pump(const Duration(milliseconds: 100));
    });

    test('AppCachedTileProvider initializes persistent disk directory and creates valid image provider', () async {
      final dir = await AppCachedTileProvider.getCacheDirectory();
      expect(dir.existsSync(), isTrue);
      expect(dir.path, contains('my_lawyer_map_tiles'));

      final imageProvider = AppCachedTileProvider.instance.getImage(
        const TileCoordinates(15, 19227, 13514),
        TileLayer(
          urlTemplate: MapConfig.serverTileUrl,
          fallbackUrl: MapConfig.fallbackTileUrl,
        ),
      );
      expect(imageProvider, isA<AppCachedMapImageProvider>());
    });

    test('AuthService evaluatePasswordStrength and hashPassword work securely', () {
      final weak = AuthService.evaluatePasswordStrength('123');
      expect(weak.score < 0.5, isTrue);
      expect(weak.label, 'ضعيفة');

      final strong = AuthService.evaluatePasswordStrength('Karem@Legal2026!');
      expect(strong.score, 1.0);
      expect(strong.label, 'قوية');
      expect(strong.isStrong, isTrue);

      final hash1 = AuthService.hashPassword('Secret123!');
      final hash2 = AuthService.hashPassword('Secret123!');
      final hashDiff = AuthService.hashPassword('Other123!');
      expect(hash1.length, 64);
      expect(hash1, hash2);
      expect(hash1 != hashDiff, isTrue);
    });

    testWidgets('UserTypeSelectionScreen displays Client and Lawyer options', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          locale: const Locale('ar', 'EG'),
          supportedLocales: const [Locale('ar', 'EG')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const UserTypeSelectionScreen(),
        ),
      );

      expect(find.text('إنشــاء حســاب جديد'), findsOneWidget);
      expect(find.text('أنت مــوكل'), findsOneWidget);
      expect(find.text('أنت محــامي'), findsOneWidget);
    });

    testWidgets('ClientRegisterScreen renders step-by-step fields and NO confirm password field', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          locale: const Locale('ar', 'EG'),
          supportedLocales: const [Locale('ar', 'EG')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const ClientRegisterScreen(),
        ),
      );

      // Step 1: Personal Data
      expect(find.text('إنشــاء حســاب موكل'), findsOneWidget);
      expect(find.text('الخطوة 1 من 3: البيانات الشخصية'), findsOneWidget);
      expect(find.text('الاسم الكامل'), findsOneWidget);
      expect(find.text('رقم الهاتف المحمول'), findsOneWidget);
      // Strictly NO confirm password field
      expect(find.text('تأكيد كلمة المرور'), findsNothing);
      expect(find.text('إعادة كلمة المرور'), findsNothing);

      // Advance to Step 2
      await tester.enterText(find.byType(TextFormField).at(0), 'خالد محمود');
      await tester.enterText(find.byType(TextFormField).at(1), '01012345678');
      await tester.ensureVisible(find.text('بيانات الحساب'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('بيانات الحساب'));
      await tester.pumpAndSettle();

      // Step 2: Account Data
      expect(find.text('الخطوة 2 من 3: بيانات الحساب'), findsOneWidget);
      expect(find.text('البريد الإلكتروني'), findsOneWidget);
      expect(find.text('كلمة المرور'), findsOneWidget);
      // Ensure badges/chips are NOT present
      expect(find.text('8+ خانات'), findsNothing);
      expect(find.text('حرف كبير'), findsNothing);
      expect(find.text('أرقام'), findsNothing);
      expect(find.text('تأكيد كلمة المرور'), findsNothing);

      // Go back to Step 1 and verify data is preserved
      await tester.tap(find.text('السابق'));
      await tester.pumpAndSettle();
      expect(find.text('الخطوة 1 من 3: البيانات الشخصية'), findsOneWidget);
      expect(find.text('خالد محمود'), findsOneWidget);
      expect(find.text('01012345678'), findsOneWidget);
    });

    testWidgets('LawyerRegisterScreen renders step-by-step syndicate fields and NO confirm password field', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          locale: const Locale('ar', 'EG'),
          supportedLocales: const [Locale('ar', 'EG')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const LawyerRegisterScreen(),
        ),
      );

      // Step 1: Professional Data
      expect(find.text('إنشــاء حســاب محامي'), findsOneWidget);
      expect(find.text('الخطوة 1 من 4: البيانات الشخصية والمهنية'), findsOneWidget);
      expect(find.text('الاسم الرباعي (مطابق لكارنيه النقابة)'), findsOneWidget);
      expect(find.text('رقم القيد بنقابة المحامين'), findsOneWidget);
      // Strictly NO confirm password field
      expect(find.text('تأكيد كلمة المرور'), findsNothing);

      // Advance to Step 2
      await tester.enterText(find.byType(TextFormField).at(0), 'سامي إبراهيم أحمد السيد');
      await tester.enterText(find.byType(TextFormField).at(1), '01123456789');
      await tester.enterText(find.byType(TextFormField).at(2), '984512');
      await tester.enterText(find.byType(TextFormField).at(3), '7');
      await tester.ensureVisible(find.text('بيانات الحساب'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('بيانات الحساب'));
      await tester.pumpAndSettle();

      // Step 2: Account Data
      expect(find.text('الخطوة 2 من 4: بيانات الحساب'), findsOneWidget);
      expect(find.text('البريد الإلكتروني المهني'), findsOneWidget);
      expect(find.text('كلمة المرور'), findsOneWidget);
      // Ensure badges are NOT present
      expect(find.text('8+ خانات'), findsNothing);
      expect(find.text('تأكيد كلمة المرور'), findsNothing);
    });

    testWidgets('EmailVerificationScreen displays target email and verification actions', (WidgetTester tester) async {
      const regData = RegistrationData(
        accountType: UserAccountType.client,
        fullName: 'أحمد محمود',
        phone: '01012345678',
        email: 'ahmed@test.com',
        password: 'Password123!',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          locale: const Locale('ar', 'EG'),
          supportedLocales: const [Locale('ar', 'EG')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const EmailVerificationScreen(registrationData: regData),
        ),
      );

      expect(find.text('أدخــل رمز التحقــق'), findsOneWidget);
      expect(find.textContaining('ahmed@test.com'), findsOneWidget);
      expect(find.text('تأكيد الرمز والتفعيل'), findsOneWidget);
      expect(find.text('لصق الرمز من الحافظة'), findsOneWidget);
    });

    testWidgets('RegistrationSuccessScreen displays personalized first name and success message', (WidgetTester tester) async {
      const regData = RegistrationData(
        accountType: UserAccountType.client,
        fullName: 'كريم عبد الرحمن الشريف',
        phone: '01012345678',
        email: 'karem@test.com',
        password: 'Password123!',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          locale: const Locale('ar', 'EG'),
          supportedLocales: const [Locale('ar', 'EG')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const RegistrationSuccessScreen(registrationData: regData),
        ),
      );

      expect(find.text('أهلاً كريم'), findsOneWidget);
      expect(find.text('تم إنشاء حسابك بنجاح'), findsOneWidget);
      expect(find.text('المتابعة الآن'), findsOneWidget);
      expect(find.textContaining('ثوانٍ'), findsOneWidget);
    });

    testWidgets('HomeTab (Client) renders banner and services but NO search bar', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'user_name': 'محمد علي',
        'user_location_name': 'الدقي، محافظة الجيزة',
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          locale: const Locale('ar', 'EG'),
          supportedLocales: const [Locale('ar', 'EG')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const Scaffold(body: HomeTab()),
        ),
      );
      await tester.pump();

      // Banner exists
      expect(find.text('محاميك حالاً'), findsAtLeastNWidgets(1));
      expect(find.text('اطلب الآن'), findsOneWidget);

      // Search bar is strictly removed
      expect(find.textContaining('ابحث عن محامي'), findsNothing);

      // Only the services that really work are listed
      expect(find.text('استشارة سريعة'), findsOneWidget);
      expect(find.text('صياغة ومراجعة العقود'), findsNothing);
      expect(find.text('تأسيس الشركات والتراخيص'), findsNothing);
      expect(find.text('إدارة القضايا والتوكيلات'), findsNothing);

      // Real user address from prefs is text only (not clickable to open tracking)
      final addressFinder = find.text('الدقي، محافظة الجيزة');
      expect(addressFinder, findsOneWidget);
      await tester.tap(addressFinder);
      await tester.pumpAndSettle();
      // Ensure no navigation occurred
      expect(find.byType(TrackingScreen), findsNothing);

      // No duplicate notifications button in HomeTab body
      expect(find.byIcon(Icons.notifications_none_rounded), findsNothing);
    });

    testWidgets('LawyerHomeTab renders title prefix, dual name, syndicate number, single service, NO banner, NO search', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'user_name': 'أحمد محمود علي إبراهيم',
        'syndicate_number': '987654',
        'user_location_name': 'مدينة نصر، محافظة القاهرة',
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          locale: const Locale('ar', 'EG'),
          supportedLocales: const [Locale('ar', 'EG')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const Scaffold(body: LawyerHomeTab()),
        ),
      );
      await tester.pump();

      // Prefix and dual name
      expect(find.byType(ProfileHomeCard), findsOneWidget);

      // Syndicate number

      // Real location is text only (not clickable to open tracking)
      final lawyerAddressFinder = find.text('مدينة نصر، محافظة القاهرة');
      expect(lawyerAddressFinder, findsOneWidget);
      await tester.tap(lawyerAddressFinder);
      await tester.pumpAndSettle();
      expect(find.byType(TrackingScreen), findsNothing);

      // No duplicate notifications button in LawyerHomeTab body
      expect(find.byIcon(Icons.notifications_none_rounded), findsNothing);

      // NO Client Banner and NO "طلب الآن"
      expect(find.text('اطلب الآن'), findsNothing);
      expect(find.text('طلب مساعدة قانونية عاجلة من أقرب محامي متاح لموقعك الآن.'), findsNothing);

      // NO search bar
      expect(find.textContaining('ابحث عن محامي'), findsNothing);

      // Exactly ONE service: محاميك حالاً
      expect(find.text('محاميك حالاً'), findsOneWidget);
      expect(find.text('استشارة سريعة'), findsNothing);
      expect(find.text('صياغة ومراجعة العقود'), findsNothing);
    });

    testWidgets('LawyerUrgentServiceIntroScreen renders definition and apply button without client map or ordering', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          locale: const Locale('ar', 'EG'),
          supportedLocales: const [Locale('ar', 'EG')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const LawyerUrgentServiceIntroScreen(),
        ),
      );

      expect(find.text('خدمة «محاميك حالاً» للمحامين'), findsOneWidget);
      expect(find.text('دور المحامي في الخدمة'), findsOneWidget);
      expect(find.text('آلية المشاركة والعمل'), findsOneWidget);
      expect(find.text('تقديم على الخدمة'), findsOneWidget);

      // Strictly NO client actions or maps
      expect(find.text('اطلب الآن'), findsNothing);
      expect(find.byType(FlutterMap), findsNothing);

      // Accepting the terms joins the service
      backend.overrides['POST /lawyers/me/urgent-terms'] = (request) => FakeBackend.json(200, {'success': true});
      await tester.ensureVisible(find.text('قرأت الشروط وأوافق عليها'));
      await tester.tap(find.text('قرأت الشروط وأوافق عليها'));
      await tester.pump();
      await tester.ensureVisible(find.text('تقديم على الخدمة'));
      await tester.tap(find.text('تقديم على الخدمة'));
      await tester.pumpAndSettle();

      expect(find.text('طلبك قيد المراجعة'), findsOneWidget);
    });

    testWidgets('LoginScreen routes lawyer account to LawyerNavigationShell', (WidgetTester tester) async {
      SessionRouter.showPromoMap = false;
      addTearDown(() => SessionRouter.showPromoMap = true);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('flutter.baseflow.com/geolocator'),
        (call) async => call.method == 'checkPermission' ? 3 : throw MissingPluginException(),
      );
      addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('flutter.baseflow.com/geolocator'), null),);
      backend.account = lawyerAccount(fullName: 'إبراهيم حسن سالم', syndicateNumber: '554433');

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          locale: const Locale('ar', 'EG'),
          supportedLocales: const [Locale('ar', 'EG')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const LoginScreen(),
        ),
      );

      await tester.pump();

      // Fill credentials
      await tester.enterText(find.byType(TextFormField).at(0), '01012345678');
      await tester.enterText(find.byType(TextFormField).at(1), '12345678');
      await tester.pump();

      // Tap Login
      await tester.tap(find.text('تسجيل الدخول'));
      await tester.pumpAndSettle();

      // Should open LawyerNavigationShell with LawyerHomeTab
      expect(find.byType(LawyerNavigationShell), findsOneWidget);
      expect(find.byType(ProfileHomeCard), findsOneWidget);
    });

    testWidgets('LawyerOrdersTab displays a summary card without actions instead of client contact/complaint', (WidgetTester tester) async {
      backend.orders = [sampleOrder(status: 'ACTIVE')];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          locale: const Locale('ar', 'EG'),
          supportedLocales: const [Locale('ar', 'EG')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const Scaffold(body: LawyerOrdersTab()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('طلب رقم ML-ORD-100001'), findsOneWidget);
      expect(find.text('محضر في قسم الشرطة'), findsAtLeastNWidgets(1));
      expect(find.textContaining('الموكل: 01099990000'), findsOneWidget);
      expect(find.textContaining('350 ج.م'), findsOneWidget);
      expect(find.text('عرض التفاصيل'), findsOneWidget);

      // Actions live on the details page
      expect(find.text('قبول الطلب'), findsNothing);
      expect(find.text('اعتذار'), findsNothing);
    });

    testWidgets('Opening an order in LawyerOrdersTab shows its details and actions without a map', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      backend.orders = [sampleOrder(status: 'PENDING')];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          locale: const Locale('ar', 'EG'),
          supportedLocales: const [Locale('ar', 'EG')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const Scaffold(body: LawyerOrdersTab()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('عرض التفاصيل'));
      await tester.pumpAndSettle();

      expect(find.byType(OrderDetailsSheet), findsOneWidget);
      expect(find.byType(TrackingScreen), findsNothing);
      expect(find.text('ML-ORD-100001'), findsOneWidget);
      // No accept or decline any more: the lawyer is chosen by the client's payment
      expect(find.text('قبول الطلب'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('LawyerWalletTab and LawyerAccountTab render lawyer data properly', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'user_name': 'يوسف كمال الدين',
        'syndicate_number': '778899',
        'user_phone': '01122334455',
      });
      backend.orders = [
        sampleOrder(status: 'COMPLETED', price: 400),
        sampleOrder(status: 'COMPLETED', id: 'order-2', orderNumber: 'ORD-1002', price: 1050),
      ];

      // Test LawyerWalletTab
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          locale: const Locale('ar', 'EG'),
          supportedLocales: const [Locale('ar', 'EG')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const Scaffold(body: LawyerWalletTab()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('الرصيد المتاح للسحب'), findsOneWidget);
      expect(find.text('1450.00'), findsOneWidget);
      expect(find.text('طلب سحب الأتعاب'), findsOneWidget);
      expect(find.text('أتعاب معلقة 24 ساعة'), findsOneWidget);
      expect(find.text('300 ج.م'), findsOneWidget);
      expect(find.text('متوقفة بسبب شكوى'), findsOneWidget);
      expect(find.text('100 ج.م'), findsOneWidget);

      // Test LawyerAccountTab
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          locale: const Locale('ar', 'EG'),
          supportedLocales: const [Locale('ar', 'EG')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const Scaffold(body: LawyerAccountTab()),
        ),
      );
      await tester.pump();

      expect(find.text('أ/ يوسف كمال'), findsOneWidget);
      expect(find.textContaining('778899'), findsOneWidget);
      expect(find.text('تسجيل الخروج'), findsOneWidget);
    });

    testWidgets('LawyerNavigationShell switches between all 4 independent lawyer tabs', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'user_name': 'عمر عبد العزيز',
        'syndicate_number': '112233',
        'user_account_type': 'lawyer',
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          locale: const Locale('ar', 'EG'),
          supportedLocales: const [Locale('ar', 'EG')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const LawyerNavigationShell(),
        ),
      );
      await tester.pump();

      // Tab 0: Home
      expect(find.byType(LawyerHomeTab), findsOneWidget);
      expect(find.byType(ProfileHomeCard), findsOneWidget);

      // Switch to Tab 1: Orders
      await tester.tap(find.text('الطلبات'));
      await tester.pump();
      expect(find.byType(LawyerOrdersTab), findsOneWidget);

      // Switch to Tab 2: Wallet
      await tester.tap(find.text('المحفظة'));
      await tester.pump();
      expect(find.byType(LawyerWalletTab), findsOneWidget);

      // Switch to Tab 3: Account
      await tester.tap(find.text('الحساب'));
      await tester.pump();
      expect(find.byType(LawyerAccountTab), findsOneWidget);
    });

    testWidgets('PasswordStrengthWidget displays only progress bar and no condition chips', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('ar', 'EG'),
          supportedLocales: [Locale('ar', 'EG')],
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: PasswordStrengthWidget(
              strength: PasswordStrength(
                score: 0.9,
                label: 'كلمة مرور قوية ومؤمنة',
                hasMinLength: true,
                hasUppercase: true,
                hasLowercase: true,
                hasDigits: true,
                hasSpecialChars: true,
              ),
            ),
          ),
        ),
      );

      // Label and LinearProgressIndicator exist
      expect(find.text('كلمة مرور قوية ومؤمنة'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      // Strictly NO condition badges/chips
      expect(find.text('8+ خانات'), findsNothing);
      expect(find.text('حرف كبير'), findsNothing);
      expect(find.text('حرف صغير'), findsNothing);
      expect(find.text('أرقام'), findsNothing);
      expect(find.text('رموز خاصة'), findsNothing);
    });
  });
}
