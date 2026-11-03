import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// منشئ الانتقال الموحد لكل الصفحات: انزلاق قصير مع ظهور تدريجي بمدة واحدة
/// يتبع اتجاه RTL ولا ينشئ أي Listeners جديدة مع إعادة بناء الصفحة
class SmoothRtlPageTransitionsBuilder extends PageTransitionsBuilder {
  const SmoothRtlPageTransitionsBuilder();

  static final Animatable<double> _curve = CurveTween(curve: Curves.easeOutCubic);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final slideTween = Tween<Offset>(
      begin: Offset(isRtl ? -0.06 : 0.06, 0.0),
      end: Offset.zero,
    );

    return SlideTransition(
      position: animation.drive(slideTween.chain(_curve)),
      child: FadeTransition(
        opacity: animation.drive(_curve),
        child: child,
      ),
    );
  }
}

/// Central Design System ThemeData with the IBM Plex Sans Arabic font & Minimal UI pill buttons (24.0px)
class AppTheme {
  AppTheme._();

  static const double borderRadiusValue = 14.0;
  static const double buttonRadiusValue = 24.0; // حواف مستديرة واضحة للأزرار (Pill Radius)
  static final BorderRadius commonBorderRadius = BorderRadius.circular(borderRadiusValue);
  static final BorderRadius buttonBorderRadius = BorderRadius.circular(buttonRadiusValue);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'AppFont',
      fontFamilyFallback: appFontFallback,
      scaffoldBackgroundColor: Colors.white, // خلفية بيضاء نقية بأسلوب Minimal UI
      primaryColor: AppColors.primary,

      // لا Ripple ولا Hover في التطبيق: استجابة الضغط الوحيدة هي الرمادي عبر AppPressable
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      focusColor: Colors.transparent,
      splashFactory: NoSplash.splashFactory,

      // Unified, smooth, zero-flicker page transitions tailored for RTL
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: SmoothRtlPageTransitionsBuilder(),
          // انتقال iOS الأصلي يحافظ على إيماءة السحب للرجوع
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: SmoothRtlPageTransitionsBuilder(),
          TargetPlatform.linux: SmoothRtlPageTransitionsBuilder(),
          TargetPlatform.macOS: SmoothRtlPageTransitionsBuilder(),
        },
      ),

      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.dark,
        surface: Colors.white,
        error: AppColors.danger,
      ),

      // App Bar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.dark),
        titleTextStyle: TextStyle(
          fontFamily: 'AppFont',
          fontFamilyFallback: appFontFallback,
          fontWeight: FontWeight.w700,
          fontSize: 18,
          color: AppColors.dark,
        ),
      ),

      // Input Decoration Theme (Minimal UI soft pill-like radius 16.0px)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.0),
          borderSide: const BorderSide(color: AppColors.cardBorder, width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.0),
          borderSide: const BorderSide(color: AppColors.cardBorder, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.0),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.0),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.0),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.4),
        ),
        hintStyle: const TextStyle(
          fontFamily: 'AppFont',
          fontFamilyFallback: appFontFallback,
          color: AppColors.textMuted,
          fontSize: 14,
        ),
        labelStyle: const TextStyle(
          fontFamily: 'AppFont',
          fontFamilyFallback: appFontFallback,
          color: AppColors.textMuted,
          fontSize: 14,
        ),
      ),

      // Button Themes (Pill Radius 24.0px): بلا Ripple وبلا Hover
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          splashFactory: NoSplash.splashFactory,
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return AppColors.primary.withOpacity(0.5);
            }
            return AppColors.primary;
          }),
          foregroundColor: WidgetStateProperty.all(Colors.white),
          elevation: WidgetStateProperty.all(0),
          minimumSize: WidgetStateProperty.all(const Size(double.infinity, 50)),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(buttonRadiusValue),
            ),
          ),
          textStyle: WidgetStateProperty.all(
            const TextStyle(
              fontFamily: 'AppFont',
              fontFamilyFallback: appFontFallback,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          splashFactory: NoSplash.splashFactory,
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          foregroundColor: WidgetStateProperty.all(AppColors.primary),
          side: WidgetStateProperty.all(
            const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          minimumSize: WidgetStateProperty.all(const Size(double.infinity, 50)),
          elevation: WidgetStateProperty.all(0),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(buttonRadiusValue),
            ),
          ),
          textStyle: WidgetStateProperty.all(
            const TextStyle(
              fontFamily: 'AppFont',
              fontFamilyFallback: appFontFallback,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          splashFactory: NoSplash.splashFactory,
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(buttonRadiusValue),
            ),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          splashFactory: NoSplash.splashFactory,
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(buttonRadiusValue),
            ),
          ),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          splashFactory: NoSplash.splashFactory,
          overlayColor: WidgetStateProperty.all(Colors.transparent),
        ),
      ),

      // Card Theme (Strictly 7.0px Border Radius)
      cardTheme: CardTheme(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadiusValue),
          side: const BorderSide(color: AppColors.cardBorder, width: 1.0),
        ),
      ),

      // Dialog Theme (Strictly 7.0px Border Radius)
      dialogTheme: DialogTheme(
        backgroundColor: Colors.white,
        elevation: 16,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadiusValue),
        ),
      ),

      // Bottom Sheet Theme (20.0px Top Radius)
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        elevation: 16,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
        ),
      ),

      // SnackBar Theme (Strictly 7.0px Border Radius)
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadiusValue),
        ),
      ),
    );
  }
}
