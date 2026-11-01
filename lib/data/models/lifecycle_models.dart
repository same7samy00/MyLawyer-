/// تقييم منشور لمحامٍ
class LawyerReview {
  final String id;
  final int rating;
  final String? comment;
  final String authorName;

  const LawyerReview({
    required this.id,
    required this.rating,
    this.comment,
    required this.authorName,
  });

  factory LawyerReview.fromJson(Map<String, dynamic> json) {
    return LawyerReview(
      id: json['id'].toString(),
      rating: (json['rating'] as num).toInt(),
      comment: json['comment']?.toString(),
      authorName: json['authorName']?.toString() ?? 'عميل استخدم الخدمة',
    );
  }
}

/// إشعار داخل التطبيق
class AppNotification {
  final String id;
  final String title;
  final String body;
  final bool isRead;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.isRead,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'].toString(),
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      isRead: json['isRead'] == true,
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
