/// مصدر صور الخريطة. المحامين ووقت الطريق جايين من سيرفرنا، والخريطة نفسها من TomTom
abstract class MapConfig {
  /// مفتاح الخريطة بيتحط وقت البناء من `dart_defines.local.json`، ومش بيتكتب في الكود
  static const String tomtomMapKey = String.fromEnvironment('TOMTOM_MAP_KEY');

  /// صور الخريطة من TomTom بأسامي الشوارع بالعربي. من غير مفتاح ترجع لخريطة سيرفرنا القديمة
  static const String serverTileUrl = tomtomMapKey == ''
      ? 'https://my-lawyer.online/map/v2/{z}/{x}/{y}.webp'
      : 'https://api.tomtom.com/map/1/tile/basic/main/{z}/{x}/{y}.png?language=ar&key=$tomtomMapKey';

  /// لو TomTom ما ردش، الخريطة تيجي من OpenStreetMap ومش بتتحفظ
  static const String fallbackTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// معرّف حزمة التطبيق لترويسة User-Agent
  static const String userAgentPackage = 'com.mylawyer.my_lawyer';
}
