import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../constants/app_colors.dart';
import 'app_button.dart';
import 'app_sheet.dart';
import 'line_illustration.dart';

/// صفحة اختيار مصدر الصورة: الكاميرا أو المعرض. بترجع المصدر، أو null لو المستخدم رجع
Future<ImageSource?> pickImageSource(BuildContext context, {required String title, required String note}) {
  return AppSheet.show<ImageSource>(
    context,
    builder: (page) => AppSheet(
      title: title,
      actions: [
        AppButton.primary(
          text: 'افتح الكاميرا',
          icon: Icons.photo_camera_rounded,
          height: 48,
          onPressed: () => Navigator.of(page).pop(ImageSource.camera),
        ),
        const SizedBox(height: 8),
        AppButton.outlined(
          text: 'من المعرض',
          icon: Icons.photo_library_rounded,
          height: 48,
          onPressed: () => Navigator.of(page).pop(ImageSource.gallery),
        ),
      ],
      children: [
        const Center(child: LineIllustration(icon: Icons.photo_camera_rounded, height: 90)),
        const SizedBox(height: 14),
        Text(
          note,
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 13, height: 1.6, color: AppColors.textMuted),
        ),
      ],
    ),
  );
}
