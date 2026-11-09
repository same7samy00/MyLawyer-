import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../constants/map_config.dart';
import '../services/app_cached_tile_provider.dart';

/// لون أرض الخريطة نفسه، فالمربع اللي لسه بيتحمل ما يبانش كمربع رمادي
const Color appMapBackground = Color(0xFFECEDF0);

/// أقصى زوم: الصور بتيجي لحد 15 وبتتكبّر بعدها، فتقدر تقرّب لحد 17 عشان الكروت اللي جنب بعض تتفرد
const double appMapMaxZoom = 17.0;
const int _tilesMaxZoom = 15;
const double appMapMinZoom = 8.0;

/// الزوم اللي الخريطة بتفتح عليه وبترجع له، أبعد شوية من الأقصى عشان المنطقة تبان
const double appMapStartZoom = 14.0;

/// الشاشة كلها تفضل جوه مصر، وهي كل ما يرسمه الخادم
final CameraConstraint appMapBounds = CameraConstraint.contain(
  bounds: LatLngBounds(const LatLng(21.7, 24.5), const LatLng(32.0, 37.0)),
);

/// خريطة مصر، ومكان أي مربع لسه ما وصلش يظهر لون الأرض بس
class AppMapLayer extends StatelessWidget {
  const AppMapLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return TileLayer(
      urlTemplate: MapConfig.serverTileUrl,
      fallbackUrl: MapConfig.fallbackTileUrl,
      userAgentPackageName: MapConfig.userAgentPackage,
      tileProvider: AppCachedTileProvider.instance,
      maxNativeZoom: _tilesMaxZoom,
      // صورة TomTom الكبيرة بتترسم في مربع عادي، فالكتابة صغيرة وواضحة
      tileSize: 256,
      // مربعات زيادة حوالين الشاشة بتتحمل مقدمًا وبتفضل في الذاكرة، فالسحب ما يبانش فيه فراغ
      panBuffer: 1,
      keepBuffer: 6,
      tileDisplay: const TileDisplay.instantaneous(),
      tileBuilder: (context, tileWidget, tile) {
        if (tile.readyToDisplay && !tile.loadError) return tileWidget;
        // لون الأرض بس من غير كتابة، والمربع يظهر بهدوء أول ما يوصل
        return const ColoredBox(color: appMapBackground);
      },
    );
  }
}

/// أول ما الخريطة تفتح، المستخدم لازم يشوف 5 محامين على الأقل: لو أقرب 5 ظاهرين في الزوم العادي الخريطة
/// تفضل زي ما هي، ولو أبعد تبعد لحد ما يبانوا كلهم فوق الشيت. ما بتقربش أكتر من زوم البداية أبدًا
MapCamera cameraShowingNearest(MapCamera camera, LatLng here, Iterable<LatLng> nearest, {required double sheetHeight}) {
  final points = [here, ...nearest.take(5)];
  if (points.length < 2) return camera;
  final fitted = CameraFit.coordinates(
    coordinates: points,
    padding: EdgeInsets.only(top: 90, left: 50, right: 50, bottom: sheetHeight + 40),
    maxZoom: appMapStartZoom,
    minZoom: appMapMinZoom,
  ).fit(camera);
  return fitted;
}
