import 'package:flutter/widgets.dart';

/// التحديث الدوري بيقف والتطبيق في الخلفية، والإشعارات شغالة من غيره
bool get isAppVisible {
  final state = WidgetsBinding.instance.lifecycleState;
  return state == null || state == AppLifecycleState.resumed;
}
