import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// الرسايل القصيرة («مفيش محامي قريب منك دلوقتي» مثلًا): تحت زي الأول، بخط أصغر شوية ومنظم،
/// وعلامة X تقفلها على طول. رسالة واحدة في نفس الوقت، والجديدة بتحل محل القديمة
void showAppMessage(BuildContext context, SnackBar bar) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: DefaultTextStyle.merge(
        style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 12.5, height: 1.5, color: Colors.white),
        child: bar.content,
      ),
      action: bar.action,
      backgroundColor: bar.backgroundColor ?? AppColors.dark,
      duration: bar.duration,
      behavior: SnackBarBehavior.floating,
      showCloseIcon: true,
      closeIconColor: Colors.white70,
      padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 8, 10),
    ),
  );
}
