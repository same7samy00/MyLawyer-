/// «استشارة سريعة»: نوعين، استشارة بس (CALL) أو اطلاع على ورق واستشارة (PAPERS)
enum ConsultationKind {
  call('CALL', 'استشارة بس'),
  papers('PAPERS', 'اطلاع على ورق واستشارة');

  final String code;
  final String label;

  const ConsultationKind(this.code, this.label);
}

/// شروط الخدمة من لوحة التحكم
class ConsultationSettings {
  final int maxPages;
  final int callMinutes;
  final int minDetailsChars;
  final bool isOpen;

  const ConsultationSettings({this.maxPages = 10, this.callMinutes = 7, this.minDetailsChars = 50, this.isOpen = true});

  factory ConsultationSettings.fromJson(Map<String, dynamic> json) => ConsultationSettings(
        maxPages: (json['maxPages'] as num?)?.toInt() ?? 10,
        callMinutes: (json['callMinutes'] as num?)?.toInt() ?? 7,
        minDetailsChars: (json['minDetailsChars'] as num?)?.toInt() ?? 50,
        isOpen: json['isOpen'] as bool? ?? true,
      );
}

/// السعر اللي السيرفر حسبه، بسطوره
class ConsultationQuote {
  final List<({String label, int amount})> lines;
  final int total;
  final int callMinutes;

  const ConsultationQuote({required this.lines, required this.total, required this.callMinutes});

  factory ConsultationQuote.fromJson(Map<String, dynamic> json) => ConsultationQuote(
        lines: (json['lines'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map((line) => (label: line['label']?.toString() ?? '', amount: (line['amount'] as num?)?.round() ?? 0))
            .toList(),
        total: (json['total'] as num?)?.round() ?? 0,
        callMinutes: (json['callMinutes'] as num?)?.toInt() ?? 7,
      );
}

/// كل اللي الموكل اختاره قبل الدفع، وبيتبعت مع الدفع مرة واحدة
class ConsultationDraft {
  final ConsultationKind kind;
  final String details;
  final List<String> pagePaths;
  final ConsultationQuote quote;

  const ConsultationDraft({required this.kind, required this.details, required this.pagePaths, required this.quote});
}

/// استشارة اتطلبت
class Consultation {
  final String id;
  final String reference;
  final String status;
  final String statusText;
  final int price;

  const Consultation({required this.id, required this.reference, required this.status, required this.statusText, required this.price});

  factory Consultation.fromJson(Map<String, dynamic> json) => Consultation(
        id: json['id']?.toString() ?? '',
        reference: json['reference']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
        statusText: json['statusText']?.toString() ?? '',
        price: (json['price'] as num?)?.round() ?? 0,
      );
}
