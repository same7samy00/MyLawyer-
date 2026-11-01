import '../../core/services/api_service.dart';

/// نموذج بيانات الطلب القانوني في المنصة
class OrderModel {
  final String id;
  final String orderNumber;
  final String serviceType;
  final String serviceTitle;
  final String? problemType;
  final String problemDescription;
  final double clientLat;
  final double clientLon;
  final String? clientAddress;
  final double? lawyerLat;
  final double? lawyerLon;
  final double price;
  final String status;
  final String? cancellationReason;
  final String? rejectionReason;
  final String createdAt;
  final String? lawyerName;
  final String? lawyerPhone;
  final String? lawyerSpecialty;
  final String? lawyerAvatar;
  final double? lawyerRating;
  final String? clientName;
  final String? clientPhone;
  final DateTime? completedAt;
  final DateTime? expiresAt;
  final DateTime? holdUntil;
  final String? payoutStatus;
  final String? completionCode;
  final bool hasReview;
  final bool hasComplaint;
  final bool hasOpenComplaint;
  final bool hasAppeal;
  final bool hasReport;
  final bool canEditReview;
  final bool isCodeLocked;
  final DateTime? arrivedAt;
  final DateTime? paymentDeadline;
  final DateTime? acceptedAt;
  final DateTime? paidAt;
  final int responseSecondsLeft;
  final int clientCompletedOrders;

  const OrderModel({
    required this.id,
    required this.orderNumber,
    required this.serviceType,
    required this.serviceTitle,
    this.problemType,
    required this.problemDescription,
    required this.clientLat,
    required this.clientLon,
    this.clientAddress,
    this.lawyerLat,
    this.lawyerLon,
    required this.price,
    required this.status,
    this.cancellationReason,
    this.rejectionReason,
    required this.createdAt,
    this.lawyerName,
    this.lawyerPhone,
    this.lawyerSpecialty,
    this.lawyerAvatar,
    this.lawyerRating,
    this.clientName,
    this.clientPhone,
    this.completedAt,
    this.expiresAt,
    this.holdUntil,
    this.payoutStatus,
    this.completionCode,
    this.hasReview = false,
    this.hasComplaint = false,
    this.hasOpenComplaint = false,
    this.hasAppeal = false,
    this.hasReport = false,
    this.canEditReview = false,
    this.isCodeLocked = false,
    this.arrivedAt,
    this.paymentDeadline,
    this.acceptedAt,
    this.paidAt,
    this.responseSecondsLeft = 0,
    this.clientCompletedOrders = 0,
  });

  /// الخادم يعيد الأرقام أحياناً كنصوص (نوع numeric في PostgreSQL)
  static double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static DateTime? _toDate(dynamic value) => DateTime.tryParse(value?.toString() ?? '')?.toLocal();

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final lawyerObj = json['lawyer'] as Map<String, dynamic>?;
    final clientObj = json['client'] as Map<String, dynamic>?;

    return OrderModel(
      // قائمة الطلبات تعيد رقم الطلب في id والمعرف الفعلي في orderId
      id: json['orderId']?.toString() ?? json['id']?.toString() ?? '',
      orderNumber: json['orderNumber']?.toString() ?? json['order_number']?.toString() ?? '',
      serviceType: json['serviceType']?.toString() ?? json['service_type']?.toString() ?? 'lawyer_now',
      serviceTitle: json['serviceTitle']?.toString() ?? json['service_title']?.toString() ?? 'محاميك حالاً',
      problemType: json['problemType']?.toString() ?? json['problem_type']?.toString() ?? json['clientChoice']?.toString(),
      problemDescription: json['problemDescription']?.toString() ?? json['problem_description']?.toString() ?? '',
      clientLat: _toDouble(json['clientLat'] ?? json['clientLatitude'] ?? json['client_latitude']) ?? 30.0444,
      clientLon: _toDouble(json['clientLon'] ?? json['clientLongitude'] ?? json['client_longitude']) ?? 31.2357,
      clientAddress: json['clientAddress']?.toString() ?? json['client_address']?.toString(),
      lawyerLat: _toDouble(json['lawyerLat'] ?? json['lawyerLatitude'] ?? json['lawyer_latitude']),
      lawyerLon: _toDouble(json['lawyerLon'] ?? json['lawyerLongitude'] ?? json['lawyer_longitude']),
      price: _toDouble(json['price']) ?? 0.0,
      status: (json['status']?.toString() ?? 'PENDING').toUpperCase(),
      cancellationReason: json['cancellationReason']?.toString() ?? json['cancellation_reason']?.toString(),
      rejectionReason: json['rejectionReason']?.toString() ?? json['rejection_reason']?.toString(),
      createdAt: json['createdAt']?.toString() ?? json['created_at']?.toString() ?? DateTime.now().toIso8601String(),
      lawyerName: lawyerObj?['name']?.toString() ?? json['lawyerName']?.toString() ?? json['lawyer_name']?.toString(),
      lawyerPhone: lawyerObj?['phone']?.toString() ?? json['lawyerPhone']?.toString() ?? json['lawyer_phone']?.toString(),
      lawyerSpecialty: lawyerObj?['specialty']?.toString() ?? json['lawyerSpecialty']?.toString() ?? json['specialty']?.toString() ?? json['lawyer_specialty']?.toString(),
      lawyerAvatar: lawyerObj?['avatar']?.toString() ?? json['lawyerAvatar']?.toString() ?? json['lawyer_avatar']?.toString(),
      lawyerRating: _toDouble(lawyerObj?['rating'] ?? json['lawyerRating']),
      clientName: clientObj?['name']?.toString() ?? json['clientName']?.toString() ?? json['client_name']?.toString(),
      clientPhone: clientObj?['phone']?.toString() ?? json['clientPhone']?.toString() ?? json['client_phone']?.toString(),
      completedAt: _toDate(json['completedAt'] ?? json['completed_at']),
      expiresAt: _toDate(json['expiresAt'] ?? json['expires_at']),
      holdUntil: _toDate(json['holdUntil'] ?? json['hold_until']),
      payoutStatus: json['payoutStatus']?.toString(),
      completionCode: json['completionCode']?.toString(),
      hasReview: json['hasReview'] == true,
      hasComplaint: json['hasComplaint'] == true,
      hasOpenComplaint: json['hasOpenComplaint'] == true,
      hasAppeal: json['hasAppeal'] == true,
      hasReport: json['hasReport'] == true,
      canEditReview: json['canEditReview'] == true,
      isCodeLocked: json['isCodeLocked'] == true,
      arrivedAt: _toDate(json['arrivedAt'] ?? json['arrived_at']),
      paymentDeadline: _toDate(json['paymentDeadline'] ?? json['payment_deadline']),
      acceptedAt: _toDate(json['acceptedAt'] ?? json['accepted_at']),
      paidAt: _toDate(json['paidAt'] ?? json['paid_at']),
      responseSecondsLeft: _toDouble(json['responseSecondsLeft'])?.toInt() ?? 0,
      clientCompletedOrders: _toDouble(json['clientCompletedOrders'])?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orderNumber': orderNumber,
      'serviceType': serviceType,
      'serviceTitle': serviceTitle,
      'problemType': problemType,
      'problemDescription': problemDescription,
      'clientLat': clientLat,
      'clientLon': clientLon,
      'clientAddress': clientAddress,
      'lawyerLat': lawyerLat,
      'lawyerLon': lawyerLon,
      'price': price,
      'status': status,
      'cancellationReason': cancellationReason,
      'rejectionReason': rejectionReason,
      'createdAt': createdAt,
      'lawyer': {
        'name': lawyerName,
        'phone': lawyerPhone,
        'specialty': lawyerSpecialty,
        'avatar': lawyerAvatar,
        'rating': lawyerRating,
      },
      'client': {
        'name': clientName,
        'phone': clientPhone,
      }
    };
  }

  bool get isPending => status == 'PENDING';
  bool get isAccepted => status == 'ACCEPTED';
  bool get isActive => status == 'ACTIVE';
  bool get isCompleted => status == 'COMPLETED';
  bool get isCancelled => status == 'CANCELLED';
  bool get isRejected => status == 'REJECTED';
  bool get isExpired => status == 'EXPIRED';
  bool get isRefunded => status == 'REFUNDED';
  bool get isNoResponse => status == 'NO_RESPONSE';

  /// الإلغاء بعد الدفع مسموح قبل وصول المحامي فقط
  bool get canCancelAfterPayment => isActive && arrivedAt == null;

  /// الدقائق الباقية لدفع طلب وافق عليه المحامي
  int get paymentMinutesLeft {
    final deadline = paymentDeadline;
    if (deadline == null) return 0;
    final seconds = deadline.difference(DateTime.now()).inSeconds;
    return seconds <= 0 ? 0 : (seconds / 60).ceil();
  }

  /// الشكوى متاحة أثناء التنفيذ وبعد الإنهاء، وواحدة مفتوحة فقط لكل طلب
  bool get canComplain => (isActive || isCompleted) && !hasOpenComplaint;

  /// التقييم متاح لمدة 7 أيام بعد إنهاء المهمة
  bool get canReview {
    final finishedAt = completedAt;
    if (!isCompleted || hasReview || finishedAt == null) return false;
    return DateTime.now().difference(finishedAt).inDays < 7;
  }

  /// الاعتراض متاح للمحامي لمدة 7 أيام بعد انتهاء المهلة
  bool get canAppeal {
    final deadline = expiresAt;
    if (!isExpired || hasAppeal || deadline == null) return false;
    return DateTime.now().difference(deadline).inDays < 7;
  }

  /// طلب لم ينتهِ بعد ويحتاج متابعة من طرفيه
  bool get isOngoing => isPending || isAccepted || isActive;

  bool get isPaid => isActive || isCompleted;

  /// عدد مراحل شريط التتبع المكتملة: الطلب ثم القبول ثم الدفع ثم الوصول ثم الإنهاء
  int get trackerDoneSteps {
    if (isCompleted) return 5;
    if (arrivedAt != null) return 4;
    if (paidAt != null || isActive) return 3;
    if (acceptedAt != null || isAccepted) return 2;
    return 1;
  }

  /// المرحلة التي توقف عندها الطلب، وطلب جارٍ أو مكتمل ليس له مرحلة توقف
  int? get trackerFailedStep => isOngoing || isCompleted ? null : trackerDoneSteps;

  String get statusLabel {
    switch (status) {
      case 'PENDING':
        return 'بانتظار موافقة المحامي';
      case 'ACCEPTED':
        return 'تم قبول الطلب • بانتظار السداد';
      case 'ACTIVE':
        return 'قيد التنفيذ • المحامي في الطريق';
      case 'COMPLETED':
        return 'مكتمل ومغلق';
      case 'CANCELLED':
        return 'تم الإلغاء';
      case 'NO_RESPONSE':
        return 'المحامي ما ردش';
      case 'PAYMENT_EXPIRED':
        return 'انتهت مهلة الدفع';
      case 'EXPIRED':
        return 'انتهت المهلة';
      case 'REFUNDED':
        return 'تم رد المبلغ';
      case 'REJECTED':
        return 'تم الاعتذار';
      default:
        return 'طلب وارد';
    }
  }

  String get priceText => price == price.roundToDouble() ? price.toInt().toString() : price.toStringAsFixed(2);

  String get lawyerAvatarUrl {
    final avatar = lawyerAvatar;
    if (avatar == null || avatar.isEmpty) return '';
    return '${ApiService.baseUrl.replaceAll('/api/v1', '')}$avatar';
  }

  /// تاريخ وساعة إنشاء الطلب بالتوقيت المحلي
  String get formattedDate {
    final dt = DateTime.tryParse(createdAt)?.toLocal();
    if (dt == null) return '';

    const arabicMonths = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];
    final period = dt.hour >= 12 ? 'م' : 'ص';
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');

    return '${dt.day} ${arabicMonths[dt.month - 1]} ${dt.year} • $hour:$minute $period';
  }
}
