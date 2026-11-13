import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/geo_naming_service.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_header.dart';
import '../../core/widgets/app_map_layer.dart';
import '../../data/models/field_info.dart';
import 'field_input.dart';
import 'field_services.dart';

/// مكان الشخص التاني: يختار المحافظة، والخريطة تفتح عليها، ويحرّكها لحد ما الدبوس اللي في النص يقع على المكان.
/// التأكيد بيشتغل بس لما يقرّب كفاية، لأن وصول المحامي بيتحسب من النقطة دي
class FieldPinScreen extends StatefulWidget {
  final String serviceTitle;

  const FieldPinScreen({super.key, required this.serviceTitle});

  @override
  State<FieldPinScreen> createState() => _FieldPinScreenState();
}

class _FieldPinScreenState extends State<FieldPinScreen> {
  final MapController _map = MapController();
  String? _governorate;
  double _zoom = 11;

  bool get _closeEnough => _zoom >= FieldServices.pinMinZoom;

  void _zoomBy(double step) {
    final camera = _map.camera;
    _map.move(camera.center, (camera.zoom + step).clamp(appMapMinZoom, appMapMaxZoom));
  }

  Future<void> _confirm() async {
    final at = _map.camera.center;
    final area = await GeoNamingService.instance.getCityAndGovernorate(at.latitude, at.longitude);
    if (!mounted) return;
    Navigator.of(context).pop(FieldPlace(name: area, lat: at.latitude, lon: at.longitude));
  }

  @override
  Widget build(BuildContext context) {
    final governorate = _governorate;
    return PopScope(
      // من الخريطة، الرجوع بيفتح المحافظات تاني
      canPop: governorate == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _governorate = null);
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: const AppHeader(title: 'مكان الشخص', isInnerPage: true),
        body: SafeArea(child: governorate == null ? _governorates() : _mapView(governorate)),
      ),
    );
  }

  Widget _governorates() {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        const Text('اختار المحافظة', style: fieldLabelStyle),
        const SizedBox(height: 8),
        for (final name in FieldServices.governorates.keys)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => setState(() {
                _governorate = name;
                _zoom = 11;
              }),
              borderRadius: BorderRadius.circular(7.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(7.0),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Text(name, style: fieldTextStyle),
              ),
            ),
          ),
      ],
    );
  }

  Widget _mapView(String governorate) {
    final (lat, lon) = FieldServices.governorates[governorate]!;
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              FlutterMap(
                mapController: _map,
                options: MapOptions(
                  initialCenter: LatLng(lat, lon),
                  initialZoom: 11,
                  minZoom: appMapMinZoom,
                  maxZoom: appMapMaxZoom,
                  interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                  cameraConstraint: appMapBounds,
                  backgroundColor: appMapBackground,
                  onPositionChanged: (camera, _) {
                    if ((camera.zoom >= FieldServices.pinMinZoom) != _closeEnough) {
                      setState(() => _zoom = camera.zoom);
                    } else {
                      _zoom = camera.zoom;
                    }
                  },
                ),
                children: const [AppMapLayer()],
              ),
              // الدبوس ثابت في النص وسنّه على نقطة المكان
              const IgnorePointer(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 44),
                    child: Icon(Icons.location_on_rounded, size: 44, color: AppColors.danger),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(7.0),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_city_rounded, size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(child: Text('محافظة $governorate', style: fieldLabelStyle)),
                      TextButton(onPressed: () => setState(() => _governorate = null), child: const Text('تغيير')),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 12,
                bottom: 12,
                child: Column(
                  children: [
                    _zoomButton(Icons.add_rounded, 1, 'قرّب'),
                    const SizedBox(height: 6),
                    _zoomButton(Icons.remove_rounded, -1, 'بعّد'),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppColors.cardBorder))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _closeEnough ? FieldServices.placeHint(widget.serviceTitle) : 'قرّب أكتر عشان تحدد المكان بالظبط',
                textAlign: TextAlign.center,
                style: fieldMutedStyle.copyWith(color: _closeEnough ? AppColors.textMuted : AppColors.warning),
              ),
              const SizedBox(height: 10),
              AppButton.primary(text: 'تأكيد المكان', height: 48, onPressed: _closeEnough ? _confirm : null),
            ],
          ),
        ),
      ],
    );
  }

  Widget _zoomButton(IconData icon, double step, String label) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(7.0),
      child: InkWell(
        onTap: () => _zoomBy(step),
        borderRadius: BorderRadius.circular(7.0),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: AppColors.dark, semanticLabel: label),
        ),
      ),
    );
  }
}
