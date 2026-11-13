import '../../data/models/consultation.dart';
import 'legal_services.dart';

/// كلام محاميحو في الشات: جمل مكتوبة بإيدنا (مش ذكاء اصطناعي) بس بتتركّب حسب حالة الموكل:
/// اسمه، ووقت اليوم، والخدمة، واللي كتبه (بيقتبس منه، ويلقط لو الطلب لقريبه أو مستعجل).
/// كله هنا عشان يتغير من مكان واحد ويتختبر من غير شاشة
class MahamihoTalk {
  /// أول اسم الموكل، أو فاضي لو مش معروف
  final String firstName;
  final DateTime now;

  const MahamihoTalk({this.firstName = '', required this.now});

  /// أول كلمة من الاسم الكامل اللي في الحساب
  static String firstNameFrom(Map<String, dynamic>? profile) {
    final full = (profile?['fullName']?.toString() ?? '').trim();
    return full.isEmpty ? '' : full.split(RegExp(r'\s+')).first;
  }

  String get _name => firstName.isEmpty ? '' : ' يا $firstName';

  String get _dayGreeting {
    final h = now.hour;
    if (h >= 5 && h < 12) return 'صباح الخير';
    if (h >= 12 && h < 17) return 'أهلاً بيك';
    return 'مساء الخير';
  }

  String hello() => '$_dayGreeting$_name 👋\nأنا محاميحو، اختار الخدمة اللي محتاجها، أو احكيلي حصل إيه وأنا أوجّهك.';

  /// أول ما يختار خدمة: سؤال على قد الخدمة نفسها
  String askDetails(LegalService s) {
    if (s.isUrgent) {
      switch (s.urgentProblem) {
        case 'محضر في قسم الشرطة':
          return 'تمام$_name. احكيلي في سطرين: مين اللي في القسم، إنت ولا حد يخصك؟ وحصل إيه؟';
        case 'تحقيق عاجل في النيابة العامة':
          return 'تمام$_name. التحقيق إمتى، وفي أنهي نيابة؟ واحكيلي باختصار الموضوع إيه.';
        case 'حضور جلسة':
          return 'تمام$_name. الجلسة إمتى وفي أنهي محكمة؟ والقضية عن إيه؟';
        case 'حضور مجلس عرفي':
          return 'تمام$_name. المجلس بين مين ومين، وإمتى؟ واحكيلي الخلاف عن إيه.';
        default:
          return 'تمام$_name. محتاج تخلّص إيه، وفي أنهي جهة؟';
      }
    }
    if (s.consultation == ConsultationKind.papers) {
      return 'تمام$_name. الورق ده بتاع إيه، وعايز تعرف منه إيه بالظبط؟ بعدها هطلب منك صوره.';
    }
    if (_isContract(s)) return 'تمام$_name. عايز تكتب إيه؟ عقد بيع، إيجار، شراكة، إنذار…؟ وبين مين ومين؟';
    return 'تمام$_name. احكيلي مشكلتك بالتفصيل، وكل ما تحكي أكتر المحامي هيفهمك أسرع.';
  }

  /// الكلام لسه قليل على الخدمات المكتبية
  String needMore(int missing) => missing > 15
      ? 'محتاج أفهم أكتر شوية عشان المحامي يجهّز ردّه صح. كمّل وقولي التفاصيل.'
      : 'قربنا! زوّد تفصيلة أو اتنين كمان.';

  /// ملخص اللي فهمه، والخطوة الجاية، وسؤال «أكمّل؟»
  String confirm(LegalService s, String description, {ConsultationSettings settings = const ConsultationSettings()}) {
    final parts = <String>['فهمت$_name: «${_quote(description)}».'];
    final urgent = _isUrgent(description);
    if (s.isUrgent) {
      final who = _relation(description);
      if (who != null) parts.add('وواضح إن الطلب لـ$who.');
      if (urgent) parts.add('وشكله مستعجل، فهنمشي بسرعة.');
      parts.add('هفتحلك طلب «${s.title}» تختار فيه الطلب ليك ولا لحد تاني وتحدد المكان، وأقرب محامي يوصلك. يلا؟');
      return parts.join(' ');
    }
    if (urgent) parts.add('وعارف إنه مستعجل.');
    if (s.consultation == ConsultationKind.papers) {
      parts.add('الخطوة الجاية تبعتلي صور الورق (لحد ${settings.maxPages} صفحة)، وبعدها الدفع، ومحامي يراجعه ويرد عليك. نكمّل؟');
    } else if (_isContract(s)) {
      parts.add('جهّزتلك طلب «${s.title}»: محامي هيكتبلك الورقة مظبوطة ويراجعها معاك. أكمّل للدفع؟');
    } else {
      parts.add('جهّزتلك طلب «${s.title}»: بعد الدفع محامي يكلمك خلال دقايق، والمكالمة ${settings.callMinutes} دقايق. أكمّل للدفع؟');
    }
    return parts.join(' ');
  }

  /// كتابة عقد أو مستندات: نوعها استشارة عادية، والفرق في الكلام بس
  bool _isContract(LegalService s) => s.keywords.contains('عقد');

  /// زرار الموافقة على قد الخطوة الجاية
  String yesLabel(LegalService s) {
    if (s.isUrgent) return 'يلا بينا';
    return s.consultation == ConsultationKind.papers ? 'أيوه، نكمّل' : 'أيوه، كمّل للدفع';
  }

  String unclear() => 'مش متأكد إني فهمتك صح$_name. مشكلتك أقرب لأنهي خدمة من دول؟';

  String guessed(LegalService s) => 'شكل موضوعك «${s.title}».';

  String editing() => 'ماشي، احكيلي من الأول، أو اختار خدمة تانية.';

  String closed() => 'الاستشارات واقفة دلوقتي للأسف، جرّب بعد شوية. ولو محتاج محامي يروح معاك مكان اختار خدمة من دول.';

  String anythingElse() => 'محتاج حاجة تانية$_name؟ أنا هنا.';

  /// سلام أو شكر أو سؤال عنه: رد قصير بدل ما يدوّر على خدمة
  String? smallTalk(String text) {
    final t = text.trim();
    if (t.length > 30) return null;
    if (RegExp('سلام|السلام|اهلا|أهلا|هاي|مرحب|ازيك|إزيك|عامل ايه|عامل إيه').hasMatch(t)) {
      return 'وعليكم السلام$_name 😊 أنا تمام وجاهز أساعدك. محتاج إيه؟';
    }
    if (RegExp('شكر|متشكر|تسلم|ميرسي').hasMatch(t)) return 'العفو$_name، ده شغلي 🙏 لو احتجت حاجة أنا هنا.';
    if (RegExp('انت مين|إنت مين|مين انت|مين إنت').hasMatch(t)) {
      return 'أنا محاميحو، بساعدك توصل للمحامي المناسب بسرعة. احكيلي محتاج إيه.';
    }
    return null;
  }

  /// الرد مقسوم جمل، والفقاعة بتكتب كل جملة لوحدها وتمسحها وتكتب اللي بعدها
  static List<String> sentences(String text) => text
      .split(RegExp(r'(?<=[.!؟?])\s+|\n+'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  /// وقت «بيكتب...» على قد طول الرد، عشان يحس إنه بيفكّر
  static Duration thinkingFor(String reply) => Duration(milliseconds: (450 + reply.length * 9).clamp(450, 1600));

  String _quote(String text) {
    final clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.length <= 48) return clean;
    final cut = clean.substring(0, 48);
    final space = cut.lastIndexOf(' ');
    return '${space > 20 ? cut.substring(0, space) : cut}…';
  }

  static const _urgentWords = ['دلوقتي', 'حالا', 'حالاً', 'فورا', 'فوراً', 'مستعجل', 'بسرعة', 'اتقبض', 'محجوز', 'محبوس', 'النهارده', 'بكرة'];

  bool _isUrgent(String text) => _urgentWords.any(text.contains);

  static const _relations = {
    'أخويا': ' أخوك',
    'اخويا': ' أخوك',
    'أختي': ' أختك',
    'اختي': ' أختك',
    'أبويا': ' والدك',
    'ابويا': ' والدك',
    'بابا': ' والدك',
    'أمي': ' والدتك',
    'امي': ' والدتك',
    'ماما': ' والدتك',
    'ابني': ' ابنك',
    'إبني': ' ابنك',
    'بنتي': ' بنتك',
    'مراتي': ' مراتك',
    'جوزي': ' جوزك',
    'صاحبي': ' صاحبك',
    'قريبي': ' قريبك',
  };

  String? _relation(String text) {
    for (final e in _relations.entries) {
      if (text.contains(e.key)) return e.value;
    }
    return null;
  }
}
