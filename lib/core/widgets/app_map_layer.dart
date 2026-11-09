import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../constants/map_config.dart';
import '../services/app_cached_tile_provider.dart';

/// لون أرض الخريطة نفسه، فالمربع اللي لسه بيتحمل ما يبانش كمربع رمادي
const Color appMapBackground = Color(0xFFF6F1E0);

/// حدود الزوم تخفف عدد المربعات المطلوبة من الخادم
const double appMapMaxZoom = 15.0;
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
      maxNativeZoom: appMapMaxZoom.toInt(),
      // صورة TomTom الكبيرة بتترسم في مربع عادي، فالكتابة صغيرة وواضحة
      tileSize: 256,
      // مربعات زيادة حوالين الشاشة بتتحمل مقدمًا وبتفضل في الذاكرة، فالسحب ما يبانش فيه فراغ
      panBuffer: 2,
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
