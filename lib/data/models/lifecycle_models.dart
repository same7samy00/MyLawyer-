import '../../core/services/notification_center.dart';
/// تقييم منشور لمحامٍ
class LawyerReview {
  final String id;
  final int rating;
  final String? comment;
  final String authorName;
  final String? authorPhoto;
  final DateTime? publishedAt;

  const LawyerReview({
    required this.id,
    required this.rating,
    this.comment,
    required this.authorName,
    this.authorPhoto,
    this.publishedAt,
  });

  factory LawyerReview.fromJson(Map<String, dynamic> json) {
    return LawyerReview(
      id: json['id'].toString(),
      rating: (json['rating'] as num).toInt(),
      comment: json['comment']?.toString(),
      authorName: json['authorName']?.toString() ?? 'عميل',
      authorPhoto: json['authorPhoto']?.toString(),
      publishedAt: DateTime.tryParse(json['publishedAt']?.toString() ?? '')?.toLocal(),
    );
  }
}

/// إشعار داخل التطبيق
class AppNotification {
  final String id;
  final String title;
  final String body;
  final bool isRead;
  final String? orderId;
  final String? ticketId;
  final String? requestId;
  final String? consultationId;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.isRead,
    this.orderId,
    this.ticketId,
    this.requestId,
    this.consultationId,
  });

  bool get opensPage => orderId != null || ticketId != null || requestId != null || consultationId != null;

  NotificationTarget get target => NotificationTarget(orderId: orderId, ticketId: ticketId, requestId: requestId, consultationId: consultationId);

  AppNotification asRead() => AppNotification(
      id: id, title: title, body: body, isRead: true, orderId: orderId, ticketId: ticketId, requestId: requestId, consultationId: consultationId);

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'].toString(),
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      isRead: json['isRead'] == true,
      orderId: json['orderId']?.toString(),
      ticketId: json['ticketId']?.toString(),
      requestId: json['requestId']?.toString(),
      consultationId: json['consultationId']?.toString(),
    );
  }
}

/// أرصدة المحامي بعد مهلة الشكاوى
class LawyerWallet {
  final double available;
  final double held;
  final double frozen;
  final DateTime? nextReleaseAt;

  const LawyerWallet({
    required this.available,
    required this.held,
    required this.frozen,
    this.nextReleaseAt,
  });

  factory LawyerWallet.fromJson(Map<String, dynamic> json) {
    return LawyerWallet(
      available: (json['availableBalance'] as num? ?? 0).toDouble(),
      held: (json['heldBalance'] as num? ?? 0).toDouble(),
      frozen: (json['frozenBalance'] as num? ?? 0).toDouble(),
      nextReleaseAt: DateTime.tryParse(json['nextReleaseAt']?.toString() ?? '')?.toLocal(),
    );
  }
}
