import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/status_badge.dart';
import '../../data/models/support_ticket.dart';

const supportTextStyle = TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 13, color: AppColors.textMain, height: 1.6);
const supportMutedStyle = TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 12, color: AppColors.textMuted);
const supportTitleStyle = TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.dark);

/// لون الحالة: تحت المراجعة أصفر، مفتوحة أزرق، مقفولة رمادي
class TicketStatusBadge extends StatelessWidget {
  final SupportTicket ticket;

  const TicketStatusBadge(this.ticket, {super.key});

  @override
  Widget build(BuildContext context) {
    final type = switch (ticket.status) {
      'UNDER_REVIEW' => StatusBadgeType.warning,
      'OPEN' => StatusBadgeType.primary,
      _ => StatusBadgeType.neutral,
    };
    return StatusBadge(text: ticket.statusLabel, type: type);
  }
}

String formatTicketDate(DateTime? date) {
  if (date == null) return '';
  String two(int value) => value.toString().padLeft(2, '0');
  return '${date.day}/${date.month}/${date.year} - ${two(date.hour)}:${two(date.minute)}';
}

/// اختيار لحد 5 صور من المعرض، مع عرضها وإمكانية شيل أي واحدة
class TicketImagePicker extends StatelessWidget {
  static const maxImages = 5;

  final List<String> paths;
  final ValueChanged<List<String>> onChanged;

  const TicketImagePicker({super.key, required this.paths, required this.onChanged});

  Future<void> _pick() async {
    final picked = await ImagePicker().pickMultiImage(maxWidth: 1600, imageQuality: 80);
    if (picked.isEmpty) return;
    onChanged([...paths, ...picked.map((image) => image.path)].take(maxImages).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final path in paths)
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(7.0),
                child: Image.file(File(path), width: 64, height: 64, fit: BoxFit.cover),
              ),
              PositionedDirectional(
                top: 2,
                end: 2,
                child: GestureDetector(
                  onTap: () => onChanged(paths.where((item) => item != path).toList()),
                  child: const CircleAvatar(
                    radius: 10,
                    backgroundColor: AppColors.danger,
                    child: Icon(Icons.close_rounded, size: 12, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        if (paths.length < maxImages)
          InkWell(
            onTap: _pick,
            borderRadius: BorderRadius.circular(7.0),
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(7.0),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: const Icon(Icons.add_photo_alternate_outlined, color: AppColors.primary),
            ),
          ),
      ],
    );
  }
}
