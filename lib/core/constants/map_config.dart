/// مصدر صور الخريطة. المحامين ووقت الطريق جايين من سيرفرنا، والخريطة من TomTom عن طريق سيرفرنا
abstract class MapConfig {
  /// صور TomTom بأسامي الشوارع بالعربي، محفوظة على سيرفرنا لكل الناس: كل مربع بيتجاب من TomTom مرة واحدة،
  /// فالتكلفة على قد مربعات مصر مش على قد عدد المستخدمين، والمفتاح ما بيخرجش من السيرفر
  static const String serverTileUrl = 'https://my-lawyer.online/map/t/{z}/{x}/{y}.png';

  /// لو سيرفرنا ما ردش، الخريطة تيجي من OpenStreetMap ومش بتتحفظ
  static const String fallbackTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// معرّف حزمة التطبيق لترويسة User-Agent
  static const String userAgentPackage = 'com.mylawyer.my_lawyer';
}
