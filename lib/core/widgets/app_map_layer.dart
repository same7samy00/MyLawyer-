import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../constants/app_colors.dart';
import '../constants/map_config.dart';
import '../services/app_cached_tile_provider.dart';

/// لون أرض الخريطة، فالمربع اللي لسه بيتحمل يبان جزء منها
const Color appMapBackground = Color(0xFFF1F5F9);

/// حدود الزوم تخفف عدد المربعات المطلوبة من الخادم
const double appMapMaxZoom = 15.0;
const double appMapMinZoom = 8.0;

/// الشاشة كلها تفضل جوه مصر، وهي كل ما يرسمه الخادم
final CameraConstraint appMapBounds = CameraConstraint.contain(
  bounds: LatLngBounds(const LatLng(21.7, 24.5), const LatLng(32.0, 37.0)),
);

/// خريطة مصر من الخادم، ويظهر «جاري التحميل» مكان أي مربع لسه ما وصلش
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
      tileBuilder: (context, tileWidget, tile) {
        if (tile.readyToDisplay && !tile.loadError) return tileWidget;

        return const ColoredBox(
          color: appMapBackground,
          child: Center(
            child: Text(
              'جاري التحميل',
              style: TextStyle(
                fontFamily: 'AppFont',
                fontFamilyFallback: appFontFallback,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
          ),
        );
      },
    );
  }
}
