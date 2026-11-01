/// إعدادات ومسارات خوادم الخرائط والملاحة الخاصة بـ My Lawyer
/// خادم الاستضافة: VPS Contabo Germany (my-lawyer.online)
abstract class MapConfig {
  /// خادم البلاطات الأساسي (مستضاف ومخزن محلياً على أقراص NVMe فائقة السرعة)
  static const String serverTileUrl =
      'https://my-lawyer.online/map/v1/{z}/{x}/{y}.webp';

  /// خادم بديل أول (OpenStreetMap العالمي) في حال تعذر الاتصال بالخادم
  static const String fallbackTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// خادم بديل ثانٍ (CartoDB Voyager)
  static const String secondaryFallbackTileUrl =
      'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png';

  /// محرك المسارات والملاحة الذاتي OSRM (C++ Backend) لحساب المسافات وأزمنة الوصول
  static const String osrmBaseUrl = 'https://my-lawyer.online/osrm';

  /// خادم بلاطات الفيكتور الخام (PMTiles مصر)
  static const String vectorTilesEndpoint =
      'https://my-lawyer.online/tiles/data/pmtiles/{z}/{x}/{y}.pbf';

  /// معرّف حزمة التطبيق لترويسة User-Agent
  static const String userAgentPackage = 'com.mylawyer.my_lawyer';
}

