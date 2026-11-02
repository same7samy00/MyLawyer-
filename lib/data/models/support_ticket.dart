import '../../core/services/api_service.dart';

/// تذكرة دعم فني: تحت المراجعة لحد أول رد من الإدارة، ثم مفتوحة لحد ما الإدارة تقفلها
class SupportTicket {
  final String id;
  final String reference;
  final String category;
  final String title;
  final String status;
  final String? orderNumber;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<TicketMessage> messages;

  const SupportTicket({
    required this.id,
    required this.reference,
    required this.category,
    required this.title,
    required this.status,
    this.orderNumber,
    this.createdAt,
    this.updatedAt,
    this.messages = const [],
  });

  static const categories = {
    'ORDER': 'مشكلة في طلب',
    'MONEY': 'الفلوس والمحفظة',
    'ACCOUNT': 'الحساب',
    'OTHER': 'حاجة تانية',
  };

  bool get isUnderReview => status == 'UNDER_REVIEW';
  bool get isClosed => status == 'CLOSED';

  String get statusLabel => switch (status) {
        'UNDER_REVIEW' => 'تحت المراجعة',
        'OPEN' => 'مفتوحة',
        _ => 'مقفولة',
      };

  String get categoryLabel => categories[category] ?? category;

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    return SupportTicket(
      id: json['id'].toString(),
      reference: json['reference']?.toString() ?? '',
      category: json['category']?.toString() ?? 'OTHER',
      title: json['title']?.toString() ?? '',
      status: json['status']?.toString() ?? 'UNDER_REVIEW',
      orderNumber: json['orderNumber']?.toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toLocal(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '')?.toLocal(),
      messages: (json['messages'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(TicketMessage.fromJson)
          .toList(),
    );
  }
}

/// رسالة في التذكرة: من صاحبها أو رد من الدعم الفني، ومعاها صورها
class TicketMessage {
  final bool fromSupport;
  final String body;
  final DateTime? createdAt;
  final List<String> imageUrls;

  const TicketMessage({required this.fromSupport, required this.body, this.createdAt, this.imageUrls = const []});

  factory TicketMessage.fromJson(Map<String, dynamic> json) {
    return TicketMessage(
      fromSupport: json['author'] == 'ADMIN',
      body: json['body']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toLocal(),
      imageUrls: (json['images'] as List<dynamic>? ?? const []).map((path) => '${ApiService.baseUrl}$path').toList(),
    );
  }
}
