import 'package:flutter/foundation.dart';

/// إعدادات بيئة التشغيل للتطبيق
/// الإصدار النهائي (Release) مقيد دائماً بخادم الإنتاج مهما كانت قيم البناء،
/// أما بيئات التطوير والاختبار فتحدد خادمها عبر:
/// `--dart-define=APP_ENV=development --dart-define=API_BASE_URL=http://...`
class AppConfig {
  AppConfig._();

  /// رقم النسخة، نفس اللي بعد علامة + في `version` في pubspec.yaml (اختبار بيتأكد إنهم واحد).
  /// الخادم بيقارنه بأقل نسخة مسموحة، وبيتسجل مع أي عطل
  static const int build = 3;

  /// زرار «تحويل لحساب تاني» في المحفظة. مقفول لحد ما يبقى فيه شريك دفع مرخّص،
  /// لأن جوجل بتعتبر التحويل بين الحسابات ميزة مالية محتاجة ترخيص. الخادم كمان مقفول (`WALLET_TRANSFERS`)
  static const bool walletTransfers = bool.fromEnvironment('WALLET_TRANSFERS');

  static const String productionApiBaseUrl = 'https://my-lawyer.online/api/v1';

  static const String _environment = String.fromEnvironment('APP_ENV', defaultValue: 'production');
  static const String _apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: productionApiBaseUrl);

  static String get environment => kReleaseMode ? 'production' : _environment;

  static bool get isProduction => environment == 'production';

  static String get apiBaseUrl => kReleaseMode ? productionApiBaseUrl : _apiBaseUrl;
}
