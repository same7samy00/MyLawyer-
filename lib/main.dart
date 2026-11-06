import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/services/api_service.dart';
import 'core/services/saved_data.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/connection_gate.dart';
import 'core/widgets/keyboard_dismiss_area.dart';
import 'features/auth/session_router.dart';
import 'features/auth/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // آخر بيانات اتعرضت بتظهر من أول لحظة، والسيرفر بيحدثها بعدها
  await SavedData.preload();
  // لا تصل رسائل التشخيص لسجلات الجهاز في الإصدار النهائي
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  ApiService.onSessionExpired = SessionRouter.handleSessionExpired;
  ApiService.onAccountSuspended = SessionRouter.handleAccountSuspended;
  runApp(const MyLawyerApp());
}

class MyLawyerApp extends StatelessWidget {
  const MyLawyerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Lawyer',
      debugShowCheckedModeBanner: false,
      navigatorKey: SessionRouter.navigatorKey,
      theme: AppTheme.lightTheme,
      locale: const Locale('ar', 'EG'),
      supportedLocales: const [
        Locale('ar', 'EG'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => KeyboardDismissArea(
        child: ConnectionGate(child: child ?? const SizedBox.shrink()),
      ),
      home: const SplashScreen(),
    );
  }
}
