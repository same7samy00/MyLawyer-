import 'package:flutter/material.dart';

import '../../core/services/device_permission_service.dart';
import '../../data/models/consultation.dart';
import '../auth/location_permission_screen.dart';
import '../consultation/mahamiho_request_screen.dart';
import '../field_service/field_request_screen.dart';
import '../field_service/field_services.dart';
import '../urgent_service/problem_description_screen.dart';

/// خدمات الموكل: نفس القايمة في الرئيسية وفي صفحة محاميحو.
/// اللي ليها [urgentProblem] بتفتح «محاميك حالاً» بالمشكلة دي، والباقي بيفتح الاستشارة بنوعها.
class LegalService {
  final String title;
  final String desc;
  final IconData icon;
  final String? urgentProblem;
  final ConsultationKind consultation;

  /// كلمات بتدل على الخدمة لو الموكل كتب لمحاميحو من غير ما يختار
  final List<String> keywords;

  const LegalService(
    this.title,
    this.desc,
    this.icon, {
    this.urgentProblem,
    this.consultation = ConsultationKind.call,
    this.keywords = const [],
  });

  bool get isUrgent => urgentProblem != null;

  static const all = [
    LegalService('استشارة قانونية', 'احكي مشكلتك ومحامي يكلمك خلال دقايق', Icons.support_agent_rounded,
        keywords: ['استشار', 'سؤال', 'رأي'],),
    LegalService('اطلاع على مستندات', 'محامي يراجع ورقك ويقولك موقفك', Icons.find_in_page_rounded,
        consultation: ConsultationKind.papers, keywords: ['مستند', 'ورق', 'اطلاع', 'أراجع'],),
    LegalService('كتابة عقد أو مستندات', 'عقد أو إنذار أو أي ورقة قانونية مظبوطة', Icons.edit_document,
        keywords: ['عقد', 'إنذار', 'انذار', 'صياغ', 'اكتب'],),
    LegalService('محضر شرطة', 'محامي يروحلك القسم دلوقتي', Icons.local_police_rounded,
        urgentProblem: 'محضر في قسم الشرطة', keywords: ['قسم', 'محضر', 'شرطة', 'قبض', 'اتقبض', 'حجز'],),
    LegalService('تحقيق نيابة', 'محامي يحضر معاك التحقيق', Icons.manage_search_rounded,
        urgentProblem: 'تحقيق عاجل في النيابة العامة', keywords: ['نياب', 'تحقيق'],),
    LegalService('حضور جلسة', 'محامي يحضر عنك أو معاك الجلسة', Icons.event_available_rounded,
        urgentProblem: 'حضور جلسة', keywords: ['جلسة', 'محكمة', 'قضية'],),
    LegalService('حضور مجلس عرفي', 'محامي يحضر الجلسة العرفية ويحفظ حقك', Icons.groups_rounded,
        urgentProblem: 'حضور مجلس عرفي', keywords: ['عرفي', 'صلح', 'قعدة'],),
    LegalService('إجراءات إدارية', 'محامي يخلّصلك ورقك في الجهات الحكومية', Icons.assignment_turned_in_rounded,
        urgentProblem: 'إجراءات إدارية', keywords: ['إداري', 'اداري', 'مصلحة', 'شهر عقاري', 'تراخيص'],),
  ];

  /// اسم الخدمة اللي بيتكتب في الهيدر لطلب المحامي: «محضر شرطة» بدل «محضر في قسم الشرطة»،
  /// ولو المشكلة من القايمة الكاملة بيتكتب اسمها هي
  static String titleFor(String? problem) {
    for (final service in all) {
      if (service.urgentProblem != null && service.urgentProblem == problem) return service.title;
    }
    return (problem == null || problem.trim().isEmpty) ? 'طلب محامي' : problem;
  }

  /// أول خدمة كلامها موجود في النص، أو null
  static LegalService? guess(String text) {
    for (final service in all) {
      if (service.keywords.any(text.contains)) return service;
    }
    return null;
  }

  /// بيفتح أول خطوة في الخدمة، ولو فيه وصف بيتكتب جاهز
  Future<void> open(BuildContext context, {String description = ''}) async {
    final navigator = Navigator.of(context);
    if (!isUrgent) {
      final details = description.isEmpty ? '' : '$title: $description';
      navigator.push(MaterialPageRoute(builder: (_) => MahamihoRequestScreen(kind: consultation, initialDetails: details)));
      return;
    }
    // الخدمات الميدانية ليها شاشاتها: المكان بالاسم، وما بتحتاجش موقع الموكل
    if (FieldServices.isField(urgentProblem)) {
      navigator.push(MaterialPageRoute(builder: (_) => FieldRequestScreen(problemTitle: urgentProblem!, initialDescription: description)));
      return;
    }
    final hasLocation = await DevicePermissionService.instance.isLocationPermissionGranted();
    navigator.push(
      MaterialPageRoute(
        builder: (_) => hasLocation
            ? ProblemDescriptionScreen(problemTitle: urgentProblem!, initialDescription: description)
            : const LocationPermissionScreen(),
      ),
    );
  }
}
