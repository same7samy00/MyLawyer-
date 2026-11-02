import 'package:flutter/material.dart';
import '../../data/repositories/lawyer_repository.dart';
import '../constants/app_colors.dart';
import '../services/notification_center.dart';
import 'app_card.dart';

/// زر حالة المحامي: الموكلون يشاهدون المحامي المتاح فقط
class LawyerAvailabilityCard extends StatefulWidget {
  const LawyerAvailabilityCard({super.key});

  @override
  State<LawyerAvailabilityCard> createState() => _LawyerAvailabilityCardState();
}

class _LawyerAvailabilityCardState extends State<LawyerAvailabilityCard> {
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final available = await LawyerRepository.getAvailability();
    if (mounted && available != null) NotificationCenter.isAvailable.value = available;
  }

  Future<void> _toggle(bool value) async {
    setState(() => _isSaving = true);
    final res = await LawyerRepository.setAvailability(value);
    if (!mounted) return;

    setState(() => _isSaving = false);
    if (res.isOk) NotificationCenter.isAvailable.value = value;

    if (!res.isOk) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.error ?? 'تعذر تغيير حالتك')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool?>(
      valueListenable: NotificationCenter.isAvailable,
      builder: (context, isAvailable, _) {
        if (isAvailable == null) return const SizedBox.shrink();
        return _buildCard(isAvailable);
      },
    );
  }

  Widget _buildCard(bool isAvailable) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                isAvailable ? 'أنت متاح لاستقبال الطلبات' : 'أنت غير متاح حالياً',
                style: const TextStyle(
                  fontFamily: 'AppFont',
                  fontFamilyFallback: appFontFallback,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.dark,
                ),
              ),
            ),
            Switch(
              value: isAvailable,
              activeColor: AppColors.primary,
              onChanged: _isSaving ? null : _toggle,
            ),
          ],
        ),
      ),
    );
  }
}
