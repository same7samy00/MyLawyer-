import '../../core/services/api_service.dart';
import 'field_info.dart';

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
  /// ثواني الدفع الباقية بعد اختيار المحامي (10 دقايق)
  final int paySecondsLeft;
  /// ليه الاختيار اتقفل قبل الدفع: TAKEN (المحامي اتشغل) أو UNPAID (ما كمّلش الدفع)
  final String? releaseReason;
  final String? lawyerName;
  final String? lawyerPhone;
  final String? lawyerAvatar;
  final double? lawyerRating;
  final String? lawyerId;
  final int lawyerReviewsCount;
  final int lawyerExperienceYears;
  final String? clientName;
  final String? clientPhone;
  final DateTime? completedAt;
  final DateTime? expiresAt;
  final DateTime? holdUntil;
  final String? payoutStatus;
  final bool hasReview;

  /// نجوم التقييم على الطلب ده، لو اتعمل
  final int? reviewRating;
  final String? openTicketId;
  final bool hasOpenComplaint;
  final bool canEditReview;
  final DateTime? arrivedAt;
  /// المحامي طلب من الموكل يأكد وصوله من عنده
  final DateTime? arrivalAskedAt;
  /// آخر مكان للطرف التاني بين الدفع والوصول، والخط اللايف بيحدثه أول بأول
  final double? liveLat;
  final double? liveLon;
  final DateTime? paymentDeadline;
  final DateTime? acceptedAt;
  final DateTime? paidAt;
  final int clientCompletedOrders;
  final DateTime? arrivalDeadline;
  final DateTime? delayNotifiedAt;
  final bool clientKeepsWaiting;
  final DateTime? postponedAt;
  final DateTime? postponedUntil;
  final String? postponedReason;

  /// تفاصيل الخدمة الميدانية (محضر، نيابة، جلسة...) لو الطلب منها
  final FieldInfo? field;

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
    this.paySecondsLeft = 0,
    this.releaseReason,
    this.lawyerName,
    this.lawyerPhone,
    this.lawyerAvatar,
    this.lawyerRating,
    this.lawyerId,
    this.lawyerReviewsCount = 0,
    this.lawyerExperienceYears = 0,
    this.clientName,
    this.clientPhone,
    this.completedAt,
    this.expiresAt,
    this.holdUntil,
    this.payoutStatus,
    this.hasReview = false,
    this.reviewRating,
    this.openTicketId,
    this.hasOpenComplaint = false,
    this.canEditReview = false,
    this.arrivedAt,
    this.arrivalAskedAt,
    this.liveLat,
    this.liveLon,
    this.paymentDeadline,
    this.acceptedAt,
    this.paidAt,
    this.clientCompletedOrders = 0,
    this.arrivalDeadline,
    this.delayNotifiedAt,
    this.clientKeepsWaiting = false,
    this.postponedAt,
    this.postponedUntil,
    this.postponedReason,
    this.field,
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
      paySecondsLeft: _toDouble(json['paySecondsLeft'])?.toInt() ?? 0,
      releaseReason: json['releaseReason']?.toString(),
      lawyerName: lawyerObj?['name']?.toString() ?? json['lawyerName']?.toString() ?? json['lawyer_name']?.toString(),
      lawyerPhone: lawyerObj?['phone']?.toString() ?? json['lawyerPhone']?.toString() ?? json['lawyer_phone']?.toString(),
      lawyerAvatar: lawyerObj?['avatar']?.toString() ?? json['lawyerAvatar']?.toString() ?? json['lawyer_avatar']?.toString(),
      lawyerRating: _toDouble(lawyerObj?['rating'] ?? json['lawyerRating']),
      lawyerId: json['lawyerId']?.toString(),
      lawyerReviewsCount: _toDouble(json['lawyerReviewsCount'])?.toInt() ?? 0,
      lawyerExperienceYears: _toDouble(json['lawyerExperienceYears'])?.toInt() ?? 0,
      clientName: clientObj?['name']?.toString() ?? json['clientName']?.toString() ?? json['client_name']?.toString(),
      clientPhone: clientObj?['phone']?.toString() ?? json['clientPhone']?.toString() ?? json['client_phone']?.toString(),
      completedAt: _toDate(json['completedAt'] ?? json['completed_at']),
      expiresAt: _toDate(json['expiresAt'] ?? json['expires_at']),
      holdUntil: _toDate(json['holdUntil'] ?? json['hold_until']),
      payoutStatus: json['payoutStatus']?.toString(),
      hasReview: json['hasReview'] == true,
      reviewRating: _toDouble(json['reviewRating'])?.toInt(),
      openTicketId: json['openTicketId']?.toString(),
      hasOpenComplaint: json['hasOpenComplaint'] == true,
      canEditReview: json['canEditReview'] == true,
      arrivedAt: _toDate(json['arrivedAt'] ?? json['arrived_at']),
      arrivalAskedAt: _toDate(json['arrivalAskedAt']),
      liveLat: _toDouble(json['liveLatitude']),
      liveLon: _toDouble(json['liveLongitude']),
      paymentDeadline: _toDate(json['paymentDeadline'] ?? json['payment_deadline']),
      acceptedAt: _toDate(json['acceptedAt'] ?? json['accepted_at']),
      paidAt: _toDate(json['paidAt'] ?? json['paid_at']),
      clientCompletedOrders: _toDouble(json['clientCompletedOrders'])?.toInt() ?? 0,
      arrivalDeadline: _toDate(json['arrivalDeadline'] ?? json['arrival_deadline']),
      delayNotifiedAt: _toDate(json['delayNotifiedAt'] ?? json['delay_notified_at']),
      clientKeepsWaiting: json['clientKeepsWaiting'] == true || json['client_keeps_waiting'] == true,
      postponedAt: _toDate(json['postponedAt'] ?? json['postponed_at']),
      postponedUntil: _toDate(json['postponedUntil'] ?? json['postponed_until']),
      postponedReason: json['postponedReason']?.toString() ?? json['postponed_reason']?.toString(),
      field: FieldInfo.fromJson(json['field']),
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
        'avatar': lawyerAvatar,
        'rating': lawyerRating,
      },
      'lawyerId': lawyerId,
      'lawyerReviewsCount': lawyerReviewsCount,
      'lawyerExperienceYears': lawyerExperienceYears,
      'client': {
        'name': clientName,
        'phone': clientPhone,
      },
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

  /// المحامي عدى مهلة الوصول وما داسش «وصلت»
  bool get isLawyerLate {
    final deadline = arrivalDeadline;
    return isActive && arrivedAt == null && deadline != null && DateTime.now().isAfter(deadline);
  }

  bool get isPostponed => isActive && postponedAt != null;

  /// الإلغاء بعد الدفع مسموح قبل وصول المحامي، في أول 5 دقايق أو بعد ما يتأخر
  bool get canCancelAfterPayment {
    final paid = paidAt;
    if (!isActive || arrivedAt != null || paid == null) return false;
    return DateTime.now().difference(paid).inMinutes < 5 || (isLawyerLate && !hasOpenComplaint);
  }

  /// سؤال «تستنى ولا تلغي؟» بيظهر لحد ما الموكل يختار يستنى
  /// المحامي مستني الموكل يأكد إنه وصل
  bool get canConfirmArrival => isActive && arrivedAt == null && arrivalAskedAt != null && !hasOpenComplaint;

  bool get canChooseToWait => isLawyerLate && delayNotifiedAt != null && !clientKeepsWaiting && !hasOpenComplaint;

  /// الموكل يلغي قبل الدفع، وبعده قبل وصول المحامي فقط
  bool get canCancel => isPending || isAccepted || canCancelAfterPayment;

  /// الدقائق الباقية لدفع طلب وافق عليه المحامي
  int get paymentMinutesLeft {
    final deadline = paymentDeadline;
    if (deadline == null) return 0;
    final seconds = deadline.difference(DateTime.now()).inSeconds;
    return seconds <= 0 ? 0 : (seconds / 60).ceil();
  }

  /// «عندك مشكلة؟» من وصول المحامي لحد 24 ساعة بعد الإنهاء، وقبل الوصول فيه إلغاء واعتذار. تذكرة مفتوحة واحدة بس على الطلب
  bool get hasOpenTicket => openTicketId != null;

  bool get canOpenTicket {
    final finishedAt = completedAt;
    final windowOpen = finishedAt == null || DateTime.now().difference(finishedAt).inHours < 24;
    return paidAt != null && arrivedAt != null && !hasOpenTicket && windowOpen;
  }

  /// التقييم متاح لمدة 7 أيام بعد إنهاء المهمة
  bool get canReview {
    final finishedAt = completedAt;
    if (!isCompleted || hasReview || finishedAt == null) return false;
    return DateTime.now().difference(finishedAt).inDays < 7;
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
      case 'ACCEPTED':
        return paySecondsLeft > 0 ? 'اخترت المحامي • كمّل الدفع خلال ${(paySecondsLeft / 60).ceil()} دقيقة' : 'اخترت المحامي • كمّل الدفع';
      case 'ACTIVE':
        if (postponedAt != null) return 'مؤجل • الفلوس محجوزة';
        return arrivedAt == null ? 'قيد التنفيذ • المحامي في الطريق' : 'قيد التنفيذ • المحامي وصل';
      case 'COMPLETED':
        return 'مكتمل ومغلق';
      case 'CANCELLED':
        return 'تم الإلغاء';
      case 'PAYMENT_EXPIRED':
        return releaseReason == 'TAKEN' ? 'المحامي اتشغل • اختار غيره' : 'الطلب اتلغى • ما كمّلتش الدفع';
      case 'EXPIRED':
        return 'انتهت المهلة';
      case 'REFUNDED':
        return 'تم رد المبلغ';
      default:
        return 'طلب قديم';
    }
  }

  /// نص الحالة من ناحية المحامي لما يختلف عن نص الموكل
  String? get lawyerStatusLabel {
    if (isAccepted) return 'الموكل اختار عرضك • مستنيين الدفع';
    if (isPostponed) return 'مؤجل • الفلوس محجوزة';
    if (isActive && arrivedAt == null) return 'الموكل دفع • روح لمكانه ودوس «وصلت»';
    if (isActive) return 'وصلت • كمل الشغل ودوس «إنهاء» أو «مؤجل»';
    if (status == 'PAYMENT_EXPIRED') return releaseReason == 'TAKEN' ? 'اتدفعلك في طلب تاني' : 'الموكل ما دفعش';
    return null;
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
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
    ];
    final period = dt.hour >= 12 ? 'م' : 'ص';
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');

    return '${dt.day} ${arabicMonths[dt.month - 1]} ${dt.year} • $hour:$minute $period';
  }
}
