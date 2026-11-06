import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/background_location_service.dart';
import '../../core/services/live_updates.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_map_layer.dart';
import '../../data/models/order_model.dart';

/// الطريق للمقابلة لحظة بلحظة: من الدفع لحد «وصلت»، كل طرف شايف مكانه ومكان التاني والمسافة بينهم.
/// مكان التاني بيوصل على الخط اللايف، ومكان الموبايل ده من خدمة الموقع، ومفيش طلبات زيادة للخادم.
class LiveTrackingCard extends StatefulWidget {
  final OrderModel order;
  final bool isLawyer;

  const LiveTrackingCard({super.key, required this.order, required this.isLawyer});

  @override
  State<LiveTrackingCard> createState() => _LiveTrackingCardState();
}

class _LiveTrackingCardState extends State<LiveTrackingCard> {
  // Same estimate the server uses before the road time is known
  static const double _roadFactor = 1.4;
  static const double _citySpeedKmh = 30;
  static const double _arrivalMeters = 50;

  final MapController _map = MapController();
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    LiveUpdates.position.addListener(_refresh);
    BackgroundLocationService.latest.addListener(_refresh);
  }

  @override
  void dispose() {
    LiveUpdates.position.removeListener(_refresh);
    BackgroundLocationService.latest.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {});
    _fit();
  }

  /// مكان الطرف التاني: اللي وصل على الخط، وإلا آخر نقطة في الطلب، وإلا مكانه وقت الطلب
  LatLng? get _other {
    final live = LiveUpdates.position.value;
    if (live != null && live.orderId == widget.order.id) return LatLng(live.lat, live.lon);
    final order = widget.order;
    if (order.liveLat != null && order.liveLon != null) return LatLng(order.liveLat!, order.liveLon!);
    if (widget.isLawyer) return LatLng(order.clientLat, order.clientLon);
    if (order.lawyerLat != null && order.lawyerLon != null) return LatLng(order.lawyerLat!, order.lawyerLon!);
    return null;
  }

  LatLng? get _me {
    final Position? position = BackgroundLocationService.latest.value;
    return position == null ? null : LatLng(position.latitude, position.longitude);
  }

  void _fit() {
    if (!_mapReady) return;
    final points = [_me, _other].whereType<LatLng>().toList();
    if (points.isEmpty) return;
    if (points.length == 1) {
      _map.move(points.first, 15);
      return;
    }
    _map.fitCamera(CameraFit.coordinates(coordinates: points, padding: const EdgeInsets.all(48), maxZoom: 15));
  }

  String _distanceText(double meters) {
    final who = widget.isLawyer ? 'الموكل' : 'المحامي';
    if (meters <= _arrivalMeters) {
      return widget.isLawyer ? 'إنت جنب الموكل، دوس «وصلت»' : 'المحامي جنبك دلوقتي';
    }
    final minutes = (meters / 1000 * _roadFactor / _citySpeedKmh * 60).ceil();
    final distance = meters < 1000 ? '${meters.round()} متر' : '${(meters / 1000).toStringAsFixed(1)} كم';
    return '$who على بعد $distance، حوالي $minutes دقيقة';
  }

  Marker _marker(LatLng point, {required bool isLawyerPin, required bool isMe}) {
    return Marker(
      point: point,
      width: 44,
      height: 44,
      child: Container(
        decoration: BoxDecoration(
          color: isMe ? AppColors.dark : AppColors.primary,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
        ),
        child: Icon(
          isLawyerPin ? Icons.verified_user_rounded : Icons.location_on_rounded,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = _me;
    final other = _other;
    final meters = me != null && other != null ? const Distance().as(LengthUnit.Meter, me, other) : null;
    final near = meters != null && meters <= _arrivalMeters;
    final center = other ?? me ?? LatLng(widget.order.clientLat, widget.order.clientLon);

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: SizedBox(
              height: 190,
              child: FlutterMap(
                mapController: _map,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 14,
                  minZoom: appMapMinZoom,
                  maxZoom: appMapMaxZoom,
                  backgroundColor: appMapBackground,
                  cameraConstraint: appMapBounds,
                  interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                  onMapReady: () {
                    _mapReady = true;
                    _fit();
                  },
                ),
                children: [
                  const AppMapLayer(),
                  MarkerLayer(markers: [
                    if (other != null) _marker(other, isLawyerPin: !widget.isLawyer, isMe: false),
                    if (me != null) _marker(me, isLawyerPin: widget.isLawyer, isMe: true),
                  ]),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(near ? Icons.check_circle_rounded : Icons.navigation_rounded,
                    size: 20, color: near ? AppColors.success : AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    meters == null ? 'بنحدد مكانك...' : _distanceText(meters),
                    style: TextStyle(
                      fontFamily: 'AppFont',
                      fontFamilyFallback: appFontFallback,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: near ? AppColors.success : AppColors.dark,
                    ),
                  ),
                ),
                const Text(
                  'لايف',
                  style: TextStyle(
                    fontFamily: 'AppFont',
                    fontFamilyFallback: appFontFallback,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.danger,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
