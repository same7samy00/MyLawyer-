import 'dart:async';
import 'package:flutter/material.dart';
import '../services/saved_data.dart';
import '../../data/repositories/lawyer_repository.dart';
import '../services/live_updates.dart';
import '../services/location_service.dart';
import '../constants/app_colors.dart';
import '../services/notification_center.dart';
import 'app_card.dart';
import 'countdown_text.dart';
import 'background_location_sheet.dart';

/// زر حالة المحامي: الموكلون يشاهدون المحامي المتاح فقط
class LawyerAvailabilityCard extends StatefulWidget {
  const LawyerAvailabilityCard({super.key});

  @override
  State<LawyerAvailabilityCard> createState() => _LawyerAvailabilityCardState();
}

class _LawyerAvailabilityCardState extends State<LawyerAvailabilityCard> {
  bool _isSaving = false;
  // آخر حالة اتعرضت بتظهر على طول، والسيرفر بيحدثها بعدها
  bool _canServe = SavedData.peek(_canServeKey) == true;
  static const String _canServeKey = 'lawyer_can_serve';
  static const String _availableKey = 'lawyer_available';
  DateTime? _suspendedUntil;

  AppLifecycleListener? _lifecycle;

  @override
  void initState() {
    super.initState();
    _load();
    // إلغاء المخالفة أو رفع الإيقاف من الإدارة يظهر على طول
    LiveUpdates.changes.addListener(_load);
    _lifecycle = AppLifecycleListener(onResume: _load);
  }

  @override
  void dispose() {
    LiveUpdates.changes.removeListener(_load);
    _lifecycle?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final profile = await LawyerRepository.getProfile();
    if (!mounted || profile == null) return;
    final until = DateTime.tryParse(profile['suspended_until']?.toString() ?? '')?.toLocal();
    setState(() {
      _suspendedUntil = until != null && until.isAfter(DateTime.now()) ? until : null;
      // الكارت للمحامي اللي الإدارة وافقت عليه للخدمة وحسابه مفعّل بس
      _canServe = profile['urgent_status'] == 'APPROVED' && profile['status'] == 'active';
    });
    NotificationCenter.isAvailable.value = profile['is_available'] == true;
    unawaited(SavedData.write(_canServeKey, _canServe));
    unawaited(SavedData.write(_availableKey, profile['is_available'] == true));
  }

  Future<void> _toggle(bool value) async {
    if (value && !await BackgroundLocationSheet.ensureReady(context)) return;
    if (!mounted) return;

    setState(() => _isSaving = true);
    // المكان بيتحدث الأول، عشان ما يتحولش لغير متاح بسبب مكان قديم
    if (value) {
      final position = (await LocationService.instance.checkAndRequestPermission(fresh: true)).position;
      if (!mounted) return;
      if (position == null) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر تحديد موقعك، حاول تاني')),
        );
        return;
      }
      await LawyerRepository.updateLawyerLocation(lat: position.latitude, lon: position.longitude);
      if (!mounted) return;
    }
    final res = await LawyerRepository.setAvailability(value);
    if (!mounted) return;

    setState(() => _isSaving = false);
    if (res.isOk) {
      NotificationCenter.isAvailable.value = value;
      unawaited(SavedData.write(_availableKey, value));
    }

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
        final shown = isAvailable ?? (SavedData.peek(_availableKey) as bool?);
        if (shown == null || !_canServe) return const SizedBox.shrink();
        return _buildCard(shown);
      },
    );
  }

  Widget _buildCard(bool isAvailable) {
    final until = _suspendedUntil;
    if (until != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: AppCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              const Text(
                'موقوف عن استقبال الطلبات بسبب المخالفات',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.dark),
              ),
              const SizedBox(height: 6),
              CountdownText(until: until, fontSize: 18, onDone: _load),
              const SizedBox(height: 4),
              const Text(
                'بعدها تقدر تفعّل «متاح» تاني',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      );
    }
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
