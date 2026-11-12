import 'package:geolocator/geolocator.dart';

/// مكان الخدمة الميدانية: قسم أو نيابة أو محكمة أو مصلحة
class FieldPlace {
  final String name;

  /// الشارع والمنطقة تحت الاسم
  final String address;
  final double lat;
  final double lon;

  /// false لو الموكل كتب الاسم بإيده، فالنقطة هي نقطته هو
  final bool verified;

  const FieldPlace({required this.name, this.address = '', required this.lat, required this.lon, this.verified = true});

  factory FieldPlace.fromJson(Map<String, dynamic> json) => FieldPlace(
        name: json['name']?.toString() ?? '',
        address: json['address']?.toString() ?? '',
        lat: (json['lat'] as num).toDouble(),
        lon: (json['lon'] as num).toDouble(),
      );
}

/// اللي الموكل ملاه قبل ما الطلب الميداني يتبعت
class FieldDraft {
  final String serviceTitle;
  final String description;
  final FieldPlace place;
  final bool forOther;
  final String personName;
  final String relation;
  final bool detained;

  const FieldDraft({
    required this.serviceTitle,
    required this.description,
    required this.place,
    this.forOther = false,
    this.personName = '',
    this.relation = '',
    this.detained = false,
  });

  /// نقطة المكان بشكل موقع، عشان الخريطة والبحث يشتغلوا عليه زي موقع الموكل
  Position get position => Position(
        latitude: place.lat,
        longitude: place.lon,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );

  Map<String, dynamic> toJson() => {
        'serviceTitle': serviceTitle,
        'problemDescription': description,
        'placeName': place.name,
        'placeLat': place.lat,
        'placeLon': place.lon,
        'placeVerified': place.verified,
        'forOther': forOther,
        if (forOther) 'personName': personName,
        if (forOther && relation.isNotEmpty) 'relation': relation,
        'detained': forOther && detained,
      };
}

/// تفاصيل الخدمة الميدانية على الطلب، لو الطلب منها
class FieldInfo {
  final bool forOther;
  final String? personName;
  final String? relation;
  final bool detained;
  final String placeName;
  final String placeKind;

  /// كود التسليم، للموكل بس وقبل ما المحامي يوصل
  final String? code;
  final bool codeLocked;

  /// طريقة إثبات الوصول: area أو code أو client
  final String? arrivalMethod;
  final bool refused;
  final int proofs;

  static const int maxProofs = 5;

  const FieldInfo({
    required this.forOther,
    this.personName,
    this.relation,
    this.detained = false,
    required this.placeName,
    required this.placeKind,
    this.code,
    this.codeLocked = false,
    this.arrivalMethod,
    this.refused = false,
    this.proofs = 0,
  });

  static FieldInfo? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    return FieldInfo(
      forOther: json['forOther'] == true,
      personName: json['personName']?.toString(),
      relation: json['relation']?.toString(),
      detained: json['detained'] == true,
      placeName: json['placeName']?.toString() ?? '',
      placeKind: json['placeKind']?.toString() ?? 'other',
      code: json['code']?.toString(),
      codeLocked: json['codeLocked'] == true,
      arrivalMethod: json['arrivalMethod']?.toString(),
      refused: json['refused'] == true,
      proofs: (json['proofs'] as num?)?.toInt() ?? 0,
    );
  }

  /// المحامي يقدر يكتب كود الشخص
  bool get canTypeCode => forOther && !codeLocked;

  bool get canAddProof => proofs < maxProofs;

  /// نوع المكان بكلام بسيط
  static String kindLabel(String kind) {
    switch (kind) {
      case 'police':
        return 'قسم شرطة';
      case 'prosecution':
        return 'نيابة';
      case 'court':
        return 'محكمة';
      case 'government':
        return 'مصلحة حكومية';
      default:
        return 'مكان محدد';
    }
  }

  /// «الطلب لـ ...» في تفاصيل الطلب
  String get personLine {
    if (!forOther) return 'الموكل نفسه';
    final name = personName ?? 'شخص تاني';
    final tie = relation;
    return tie == null || tie.isEmpty ? name : '$name ($tie)';
  }
}
