import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/models/order_model.dart';
import '../../data/repositories/order_repository.dart';
import 'api_service.dart';
import 'auth_service.dart';
import 'background_location_service.dart';
import 'live_updates.dart';

/// مكان واحد للطلبات تقرأ منه كل الشاشات.
/// لما السيرفر يقول إن طلب معين اتغير، الطلب ده بس هو اللي بيتجاب، وكل شاشة بتعرضه بتتغير مع بعض.
class OrderStore {
  OrderStore._();

  /// بيبدأ بآخر نسخة محفوظة، فالصفحة بتترسم بيها من أول لحظة
  static final ValueNotifier<List<OrderModel>> orders = ValueNotifier<List<OrderModel>>(OrderRepository.peekOrders());
  static bool isLoaded = false;
  static StreamSubscription<LiveChange>? _subscription;
  static Future<ApiResponse<List<OrderModel>>>? _loading;

  /// الطلبات بتتحمل صفحة صفحة: المفتوحة وأحدث السجل الأول، والباقي لما المستخدم ينزل في السجل
  static const int _pageSize = 30;
  static bool _hasMore = false;
  static bool _loadingMore = false;

  static void start() {
    if (_subscription == null) {
      orders.addListener(_followMission);
      // الطريق للمقابلة لازم يكمل حتى لو التطبيق اتفتح من جديد وصفحة الطلبات مقفولة
      unawaited(load());
    }
    _subscription ??= LiveUpdates.stream.listen((change) {
      if (change.isEverything) {
        unawaited(load());
      } else if (change.kind == 'orders') {
        final id = change.entityId;
        unawaited(id == null ? load() : refreshOne(id));
      }
    });
  }

  /// الطلب المدفوع اللي المحامي لسه ما وصلش فيه: الطرفين بيشاركوا مكانهم لحظيًا لحد «وصلت»
  static void _followMission() {
    final mission = orders.value.where((order) => order.isActive && order.arrivedAt == null).firstOrNull;
    unawaited(() async {
      final isLawyer = await AuthService.currentRole() == 'lawyer';
      await BackgroundLocationService.setMission(
        mission?.id,
        targetLat: mission?.clientLat,
        targetLon: mission?.clientLon,
        isLawyer: isLawyer,
      );
    }());
  }

  static void clear() {
    orders.removeListener(_followMission);
    unawaited(_subscription?.cancel());
    _subscription = null;
    orders.value = const [];
    _hasMore = false;
    isLoaded = false;
  }

  /// آخر نسخة محفوظة بتظهر لحد ما السيرفر يرد
  static Future<void> showSaved() async {
    if (isLoaded || orders.value.isNotEmpty) return;
    final saved = await OrderRepository.savedOrders();
    if (!isLoaded && saved.isNotEmpty) orders.value = saved;
  }

  /// كل الطلبات مرة واحدة، والطلبات المتزامنة بتستنى نفس الرد
  static Future<ApiResponse<List<OrderModel>>> load() {
    return _loading ??= OrderRepository.getOrders(limit: _pageSize).then((res) {
      if (res.isOk) {
        orders.value = res.data ?? const [];
        _hasMore = orders.value.length >= _pageSize;
        isLoaded = true;
      }
      return res;
    }).whenComplete(() => _loading = null);
  }

  /// الصفحة اللي بعدها من السجل، لما المستخدم يوصل لآخر اللي ظاهر
  static Future<void> loadMore() async {
    if (!_hasMore || _loadingMore || _loading != null) return;
    _loadingMore = true;
    final res = await OrderRepository.getOrders(limit: _pageSize, offset: orders.value.length);
    _loadingMore = false;
    final more = res.data;
    if (!res.isOk || more == null) return;
    _hasMore = more.length >= _pageSize;
    final known = orders.value.map((order) => order.id).toSet();
    final fresh = more.where((order) => !known.contains(order.id)).toList();
    if (fresh.isNotEmpty) orders.value = [...orders.value, ...fresh];
  }

  /// طلب واحد اتغير: يتجاب لوحده ويتحط مكانه
  static Future<void> refreshOne(String id) async {
    final res = await OrderRepository.getOrderFromList(id);
    if (!res.isOk) return;
    final fresh = res.data;
    final list = List<OrderModel>.of(orders.value);
    final index = list.indexWhere((order) => order.id == id);
    if (fresh == null) {
      if (index >= 0) list.removeAt(index);
    } else if (index >= 0) {
      list[index] = fresh;
    } else {
      list.insert(0, fresh);
    }
    orders.value = list;
  }

  static OrderModel? find(String id) => orders.value.where((order) => order.id == id).firstOrNull;
}
