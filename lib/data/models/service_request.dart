import '../../core/services/api_service.dart';

double _number(dynamic value) => value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '') ?? 0;

/// طلب مستني سعر المحامي
class IncomingRequest {
  final String id;
  final String service;
  final String problemType;
  final String problemDescription;
  final String? area;
  final double distanceKm;
  final int minPrice;
  final int maxPrice;
  final double netRate;
  final int secondsLeft;
  final int? myPrice;
  final String state;
  final String? orderId;

  /// وقت ما الطلب اتقرا، عشان العد التنازلي يكمل من غير ما نسأل السيرفر تاني
  final DateTime? receivedAt;

  const IncomingRequest({
    required this.id,
    this.service = 'محاميك حالاً',
    required this.problemType,
    required this.problemDescription,
    this.area,
    required this.distanceKm,
    required this.minPrice,
    required this.maxPrice,
    required this.netRate,
    required this.secondsLeft,
    this.myPrice,
    this.state = 'OPEN',
    this.orderId,
    this.receivedAt,
  });

  int get secondsLeftNow {
    final at = receivedAt;
    if (at == null) return secondsLeft;
    final left = secondsLeft - DateTime.now().difference(at).inSeconds;
    return left < 0 ? 0 : left;
  }

  factory IncomingRequest.fromJson(Map<String, dynamic> json) => IncomingRequest(
        id: json['id'].toString(),
        service: json['service']?.toString() ?? 'محاميك حالاً',
        problemType: json['problemType']?.toString() ?? 'محاميك حالاً',
        problemDescription: json['problemDescription']?.toString() ?? '',
        area: json['area']?.toString(),
        distanceKm: _number(json['distanceKm']),
        minPrice: _number(json['minPrice']).round(),
        maxPrice: _number(json['maxPrice']).round(),
        netRate: _number(json['netRate']),
        secondsLeft: _number(json['secondsLeft']).toInt(),
        myPrice: json['myPrice'] == null ? null : _number(json['myPrice']).round(),
        state: json['state']?.toString() ?? 'OPEN',
        orderId: json['orderId']?.toString(),
        receivedAt: DateTime.now(),
      );

  int netOf(int price) => (price * netRate).round();

  bool get isChosen => state == 'CHOSEN';
}

/// عرض محامي على طلب الموكل
class RequestOffer {
  final String id;
  final String lawyerId;
  final String name;
  final String? avatar;
  final double rating;
  final int reviewsCount;
  final int experienceYears;
  final int price;
  final double distanceKm;
  final int minutesAway;

  const RequestOffer({
    required this.id,
    required this.lawyerId,
    required this.name,
    this.avatar,
    required this.rating,
    required this.reviewsCount,
    required this.experienceYears,
    required this.price,
    required this.distanceKm,
    required this.minutesAway,
  });

  factory RequestOffer.fromJson(Map<String, dynamic> json) => RequestOffer(
        id: json['id'].toString(),
        lawyerId: json['lawyerId'].toString(),
        name: json['name']?.toString() ?? 'محامي',
        avatar: json['avatar']?.toString(),
        rating: _number(json['rating']),
        reviewsCount: _number(json['reviewsCount']).toInt(),
        experienceYears: _number(json['experienceYears']).toInt(),
        price: _number(json['price']).round(),
        distanceKm: _number(json['distanceKm']),
        minutesAway: _number(json['minutesAway']).toInt(),
      );

  String get avatarUrl {
    final path = avatar;
    if (path == null || path.isEmpty) return '';
    return '${ApiService.baseUrl.replaceAll('/api/v1', '')}$path';
  }
}

/// حالة طلب الموكل وعروضه
class ClientRequest {
  final String id;
  final String status;
  final int round;
  final int secondsLeft;
  final int chooseSecondsLeft;
  final List<RequestOffer> offers;

  const ClientRequest({required this.id, required this.status, required this.round, required this.secondsLeft, this.chooseSecondsLeft = 0, required this.offers});

  factory ClientRequest.fromJson(Map<String, dynamic> json) => ClientRequest(
        id: json['id'].toString(),
        status: json['status']?.toString() ?? 'OPEN',
        round: _number(json['round']).toInt(),
        secondsLeft: _number(json['secondsLeft']).toInt(),
        chooseSecondsLeft: _number(json['chooseSecondsLeft']).toInt(),
        offers: ((json['offers'] as List?) ?? const [])
            .map((item) => RequestOffer.fromJson(item as Map<String, dynamic>))
            .toList(),
      );

  bool get isOpen => status == 'OPEN';

  int get chooseMinutesLeft => (chooseSecondsLeft / 60).ceil();
}

/// الطلب اللي اتعمل بعد اختيار العرض
class SelectedOffer {
  final String orderId;
  final String orderNumber;
  final int price;
  final String lawyerId;

  const SelectedOffer({required this.orderId, required this.orderNumber, required this.price, required this.lawyerId});
}

/// طلب الموكل اللي لسه ما اتختارش فيه محامي، لصفحة الطلبات
class MyRequest {
  final String id;
  final String status;
  final String problemType;
  final String serviceTitle;
  final int minPrice;
  final int maxPrice;
  final int offers;
  final int secondsLeft;
  final DateTime? createdAt;

  const MyRequest({required this.id, required this.status, required this.problemType, required this.serviceTitle, required this.minPrice, required this.maxPrice, required this.offers, required this.secondsLeft, this.createdAt});

  factory MyRequest.fromJson(Map<String, dynamic> json) => MyRequest(
        id: json['id'].toString(),
        status: json['status']?.toString() ?? 'OPEN',
        problemType: json['problemType']?.toString() ?? 'محاميك حالاً',
        serviceTitle: json['serviceTitle']?.toString() ?? 'محاميك حالاً',
        minPrice: _number(json['minPrice']).round(),
        maxPrice: _number(json['maxPrice']).round(),
        offers: _number(json['offers']).toInt(),
        secondsLeft: _number(json['secondsLeft']).toInt(),
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toLocal(),
      );

  bool get isOpen => status == 'OPEN';

  /// الحالة بكلام بسيط
  String get statusLabel {
    switch (status) {
      case 'OPEN':
        if (offers > 0) return 'وصلك $offers ${offers == 1 ? 'عرض' : 'عروض'} • اختار واحد';
        return 'بندوّر على محامين قريبين';
      case 'NO_OFFERS':
        return 'محدش بعت عرض';
      case 'EXPIRED':
        return 'الطلب اتلغى • ما اخترتش عرض';
      case 'CANCELLED':
        return 'لغيت الطلب';
      default:
        return 'الطلب اتقفل';
    }
  }
}
