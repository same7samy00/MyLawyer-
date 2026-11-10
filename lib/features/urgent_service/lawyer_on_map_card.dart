import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/live_updates.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_map_layer.dart';
import '../../data/models/order_model.dart';

/// الموكل بيشوف المحامي جاي على الخريطة، من الدفع لحد «وصلت».
/// مكان المحامي بيوصل على الخط المباشر أصلًا، والخريطة من المحفوظ عندنا، فمفيش أي سؤال زيادة لشركة الخرايط:
/// نقطة بتتحرك بس، من غير خط الطريق.
class LawyerOnMapCard extends StatefulWidget {
  final OrderModel order;

  const LawyerOnMapCard({super.key, required this.order});

  @override
  State<LawyerOnMapCard> createState() => _LawyerOnMapCardState();
}

class _LawyerOnMapCardState extends State<LawyerOnMapCard> with SingleTickerProviderStateMixin {
  static const double _height = 190;
  static const double _closestZoom = 16;
  static const EdgeInsets _edges = EdgeInsets.all(44);

  final MapController _map = MapController();
  late final AnimationController _glide = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  bool _mapReady = false;

  /// النقطة اللي المحامي ماشي منها، واللي رايح لها، عشان يتحرك بنعومة بدل ما ينط
  LatLng? _from;
  LatLng? _to;

  LatLng get _client => LatLng(widget.order.clientLat, widget.order.clientLon);

  /// آخر مكان للمحامي: اللي وصل على الخط، وإلا آخر نقطة في الطلب، وإلا مكانه وقت اختيار العرض
  LatLng? get _lawyerNow {
    final order = widget.order;
    final live = LiveUpdates.position.value;
    if (live != null && live.orderId == order.id) return LatLng(live.lat, live.lon);
    if (order.liveLat != null && order.liveLon != null) return LatLng(order.liveLat!, order.liveLon!);
    if (order.lawyerLat != null && order.lawyerLon != null) return LatLng(order.lawyerLat!, order.lawyerLon!);
    return null;
  }

  LatLng? get _shown {
    final from = _from;
    final to = _to;
    if (to == null) return null;
    if (from == null) return to;
    final t = Curves.easeInOut.transform(_glide.value);
    return LatLng(from.latitude + (to.latitude - from.latitude) * t, from.longitude + (to.longitude - from.longitude) * t);
  }

  @override
  void initState() {
    super.initState();
    _to = _lawyerNow;
    LiveUpdates.position.addListener(_onMove);
    _glide.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(LawyerOnMapCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _onMove();
  }

  @override
  void dispose() {
    LiveUpdates.position.removeListener(_onMove);
    _glide.dispose();
    _map.dispose();
    super.dispose();
  }

  void _onMove() {
    final next = _lawyerNow;
    if (!mounted || next == null || next == _to) return;
    _from = _shown;
    _to = next;
    _glide.forward(from: 0);
    _showBoth();
  }

  CameraFit _fit(LatLng lawyer) =>
      CameraFit.coordinates(coordinates: [_client, lawyer], padding: _edges, maxZoom: _closestZoom, minZoom: appMapMinZoom);

  /// الطرفين دايمًا ظاهرين: الخريطة بتقرّب لوحدها كل ما المحامي يقرّب
  void _showBoth() {
    final lawyer = _to;
    if (!_mapReady || lawyer == null) return;
    _map.fitCamera(_fit(lawyer));
  }

  Widget _dot({required Color color, required IconData icon}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
      ),
      child: Icon(icon, color: Colors.white, size: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lawyer = _shown;
    if (lawyer == null) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.borderRadiusValue),
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusValue),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: SizedBox(
          height: _height,
          child: FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCameraFit: _fit(_to ?? lawyer),
              minZoom: appMapMinZoom,
              maxZoom: appMapMaxZoom,
              // الخريطة للفرجة بس، فسحب الصفحة ما يتلخبطش مع سحب الخريطة
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
              backgroundColor: appMapBackground,
              onMapReady: () => _mapReady = true,
            ),
            children: [
              const AppMapLayer(),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _client,
                    width: 30,
                    height: 30,
                    child: _dot(color: AppColors.primary, icon: Icons.location_on_rounded),
                  ),
                  Marker(
                    point: lawyer,
                    width: 34,
                    height: 34,
                    child: _dot(color: AppColors.dark, icon: Icons.person_rounded),
                  ),
                ],
              ),
              const Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: EdgeInsets.all(4),
                  child: Text(
                    '© TomTom',
                    textDirection: TextDirection.ltr,
                    style: TextStyle(fontSize: 9, color: AppColors.textMuted),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
