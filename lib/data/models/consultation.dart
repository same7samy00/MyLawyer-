/// «استشارة سريعة»: نوعين، استشارة بس (CALL) أو اطلاع على ورق واستشارة (PAPERS)
enum ConsultationKind {
  call('CALL', 'استشارة بس', 'استشارة قانونية'),
  papers('PAPERS', 'اطلاع على ورق واستشارة', 'اطلاع على مستندات');

  final String code;
  final String label;

  /// اسم الخدمة في الرئيسية، للاستشارة القديمة اللي اتحفظت من غير اسم خدمتها
  final String serviceName;

  const ConsultationKind(this.code, this.label, this.serviceName);
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

  /// اتقالت بالصوت: النص بيروح للإدارة والعميل ما بيشوفوش
  final bool viaVoice;

  /// الخدمة اللي الموكل اختارها من الرئيسية، وبيتسمى بيها الطلب في صفحة الطلبات
  final String serviceTitle;

  const ConsultationDraft({
    required this.kind,
    required this.details,
    required this.pagePaths,
    required this.quote,
    required this.serviceTitle,
    this.viaVoice = false,
  });
}

/// استشارة اتطلبت، وبتظهر في صفحة الطلبات مع باقي الخدمات
class Consultation {
  final String id;
  final String reference;
  final ConsultationKind kind;

  /// اسم الخدمة اللي اتختارت فعلًا، زي «كتابة عقد أو مستندات»
  final String serviceTitle;
  final String status;
  final String statusText;
  final int price;
  final int pages;
  final String details;
  final String? rejectReason;
  final bool canRequestContact;
  final bool contactRequested;
  final DateTime? createdAt;

  const Consultation({
    required this.id,
    required this.reference,
    required this.kind,
    required this.serviceTitle,
    required this.status,
    required this.statusText,
    required this.price,
    this.pages = 0,
    this.details = '',
    this.rejectReason,
    this.canRequestContact = false,
    this.contactRequested = false,
    this.createdAt,
  });

  /// مستنية مكالمة الفريق أو الفريق بيكلمه: في «الطلبات المفتوحة»، والباقي في السجل
  bool get isOngoing => status == 'PAID' || status == 'CONTACTING';

  factory Consultation.fromJson(Map<String, dynamic> json) {
    final kind = json['kind'] == ConsultationKind.papers.code ? ConsultationKind.papers : ConsultationKind.call;
    final title = json['serviceTitle']?.toString() ?? '';
    return Consultation(
        id: json['id']?.toString() ?? '',
        reference: json['reference']?.toString() ?? '',
        kind: kind,
        serviceTitle: title.isEmpty ? kind.serviceName : title,
        status: json['status']?.toString() ?? '',
        statusText: json['statusText']?.toString() ?? '',
        price: (json['price'] as num?)?.round() ?? 0,
        pages: (json['pages'] is num) ? (json['pages'] as num).toInt() : (json['pages'] is List ? (json['pages'] as List).length : 0),
        details: json['details']?.toString() ?? '',
        rejectReason: json['rejectReason']?.toString(),
        canRequestContact: json['canRequestContact'] == true,
        contactRequested: json['contactRequestedAt'] != null,
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toLocal(),
      );
  }
}
