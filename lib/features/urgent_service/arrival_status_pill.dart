import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/background_location_service.dart';
import '../../core/services/live_updates.dart';
import '../../core/services/routing_service.dart';
import '../../core/widgets/status_pill.dart';
import '../../data/models/order_model.dart';

/// شارة الحالة تحت المراحل من الدفع لحد «وصلت»، وبتتحدث لوحدها مع كل حركة:
/// المحامي بيشوف «الموكل على بعد كذا، حوالي كذا دقيقة»، والموكل بيشوف «المحامي هيوصلك خلال حوالي كذا».
/// الوقت بيتحسب على الطرق الحقيقية من محرك الطرق اللي على السيرفر، بالزحمة المتوقعة،
/// والسؤال مرة كل دقيقتين أو لما المحامي يتحرك 500 متر، وبين السؤالين الوقت بيقل على قد ما المحامي قرّب.
class ArrivalStatusPill extends StatefulWidget {
  final OrderModel order;
  final bool isLawyer;

  const ArrivalStatusPill({super.key, required this.order, required this.isLawyer});

  @override
  State<ArrivalStatusPill> createState() => _ArrivalStatusPillState();
}

class _ArrivalStatusPillState extends State<ArrivalStatusPill> {
  static const double _arrivalMeters = 50;
  static const double _askAgainMeters = 500;
  static const Duration _askAgainEvery = Duration(minutes: 2);

  final RoutingService _routing = RoutingService();
  RouteEstimate? _route;

  /// بُعد المحامي عن الموكل بالخط المستقيم وقت آخر سؤال، عشان الوقت يقل مع كل حركة من غير سؤال جديد
  double? _askedStraightMeters;
  LatLng? _askedFrom;
  DateTime? _askedAt;
  bool _asking = false;

  @override
  void initState() {
    super.initState();
    LiveUpdates.position.addListener(_onMove);
    BackgroundLocationService.latest.addListener(_onMove);
    _onMove();
  }

  @override
  void dispose() {
    LiveUpdates.position.removeListener(_onMove);
    BackgroundLocationService.latest.removeListener(_onMove);
    super.dispose();
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
    final position = BackgroundLocationService.latest.value;
    return position == null ? null : LatLng(position.latitude, position.longitude);
  }

  /// الطريق دايمًا من المحامي للموكل
  (LatLng, LatLng)? get _trip {
    final me = _me;
    final other = _other;
    if (me == null || other == null) return null;
    return widget.isLawyer ? (me, other) : (other, me);
  }

  void _onMove() {
    if (!mounted) return;
    setState(() {});
    final trip = _trip;
    if (trip == null || _asking) return;
    final lawyer = trip.$1;
    final askedFrom = _askedFrom;
    final askedAt = _askedAt;
    final moved = askedFrom == null || const Distance().as(LengthUnit.Meter, askedFrom, lawyer) >= _askAgainMeters;
    final stale = askedAt == null || DateTime.now().difference(askedAt) >= _askAgainEvery;
    if (moved || stale) _ask(trip);
  }

  Future<void> _ask((LatLng, LatLng) trip) async {
    _asking = true;
    _askedFrom = trip.$1;
    _askedAt = DateTime.now();
    final straight = const Distance().as(LengthUnit.Meter, trip.$1, trip.$2);
    final route = await _routing.calculateDrivingRoute(start: trip.$1, destination: trip.$2);
    _asking = false;
    if (!mounted) return;
    if (route.isSuccess) {
      setState(() {
        _route = route;
        _askedStraightMeters = straight;
      });
    }
  }

  /// آخر إجابة من السيرفر، متصغّرة على قد ما المحامي قرّب من وقتها. السؤال الجاي بيصحّحها
  RouteEstimate? _routeNow(double straightMeters) {
    final route = _route;
    final asked = _askedStraightMeters;
    if (route == null || asked == null || asked <= 0) return route;
    final left = (straightMeters / asked).clamp(0.0, 1.5);
    return RouteEstimate(distanceMeters: route.distanceMeters * left, durationSeconds: route.durationSeconds * left);
  }

  String _text(double straightMeters) {
    if (straightMeters <= _arrivalMeters) {
      return widget.isLawyer ? 'إنت جنب الموكل، دوس «وصلت»' : 'المحامي وصل جنبك';
    }
    final route = _routeNow(straightMeters);
    if (route == null) return 'بنحسب وقت الوصول...';
    return widget.isLawyer
        ? 'الموكل على بعد ${route.distanceText}، ${route.arrivalRangeText}'
        : 'المحامي هيوصلك خلال ${route.arrivalRangeText}';
  }

  @override
  Widget build(BuildContext context) {
    final trip = _trip;
    final straight = trip == null ? null : const Distance().as(LengthUnit.Meter, trip.$1, trip.$2);
    final near = straight != null && straight <= _arrivalMeters;

    return StatusPill(
      icon: near ? Icons.check_circle_rounded : Icons.navigation_rounded,
      color: near ? AppColors.success : AppColors.primary,
      text: straight == null ? 'بنحدد مكانك...' : _text(straight),
    );
  }
}
