/// دفعة واحدة في صفحة المدفوعات: اتدفعت، أو اترد مبلغها، أو ما تمتش
class PaymentRecord {
  final String id;
  final String? reference;
  final String status;
  final double amount;
  final double refunded;
  final String method;
  final String? reason;
  final DateTime? at;
  final String? orderNumber;
  final String service;
  final String? lawyerName;

  const PaymentRecord({
    required this.id,
    required this.status,
    required this.amount,
    required this.method,
    required this.service,
    this.reference,
    this.refunded = 0,
    this.reason,
    this.at,
    this.orderNumber,
    this.lawyerName,
  });

  factory PaymentRecord.fromJson(Map<String, dynamic> json) {
    return PaymentRecord(
      id: json['id']?.toString() ?? '',
      reference: json['reference']?.toString(),
      status: json['status']?.toString() ?? 'PAID',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      refunded: (json['refunded'] as num?)?.toDouble() ?? 0,
      method: json['method']?.toString() ?? 'DIRECT',
      reason: json['reason']?.toString(),
      at: DateTime.tryParse(json['at']?.toString() ?? '')?.toLocal(),
      orderNumber: json['orderNumber']?.toString(),
      service: json['service']?.toString() ?? 'طلب محامي',
      lawyerName: json['lawyerName']?.toString(),
    );
  }

  bool get isFailed => status == 'FAILED';

  /// الفاتورة للدفعات اللي اتدفعت فعلاً بس
  bool get hasInvoice => !isFailed && reference != null;

  String get statusLabel => switch (status) {
        'FAILED' => 'ما تمتش',
        'REFUNDED' => 'اترد لرصيدك',
        'PARTLY_REFUNDED' => 'اترد جزء منها',
        _ => 'اتدفعت',
      };

  String get methodLabel => method == 'WALLET' ? 'رصيد My Lawyer' : 'دفع مباشر';
}
