import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../constants/app_colors.dart';
import '../services/push_service.dart';
import 'app_button.dart';
import 'app_sheet.dart';
import 'sheet_actions.dart';

/// خطوات تجهيز الموبايل قبل ما المحامي يبقى متاح، عشان تجيله طلبات وهو برّه التطبيق
class BackgroundLocationSheet extends StatefulWidget {
  const BackgroundLocationSheet({super.key});

  /// يرجع true لو الموقع والإشعارات جاهزين، وإلا الزر ما يتفعلش
  static Future<bool> ensureReady(BuildContext context) async {
    final ready = await AppSheet.show<bool>(context, builder: (context) => const BackgroundLocationSheet());
    return ready == true;
  }

  @override
  State<BackgroundLocationSheet> createState() => _BackgroundLocationSheetState();
}

class _BackgroundLocationSheetState extends State<BackgroundLocationSheet> with WidgetsBindingObserver {
  static const _device = MethodChannel('mylawyer/device');

  bool _locationReady = false;
  bool _notificationsReady = false;
  bool _batteryReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// الرجوع من إعدادات الموبايل يحدث العلامات
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<bool> _deviceCheck(String method) async {
    try {
      return await _device.invokeMethod<bool>(method) ?? true;
    } on MissingPluginException {
      return true;
    } on PlatformException {
      return true;
    }
  }

  Future<void> _check() async {
    bool location = false;
    try {
      location = await Geolocator.isLocationServiceEnabled() &&
          await Geolocator.checkPermission() == LocationPermission.always;
    } catch (_) {}
    final notifications = await _deviceCheck('notificationsEnabled');
    final battery = await _deviceCheck('batteryExempt');
    if (!mounted) return;
    setState(() {
      _locationReady = location;
      _notificationsReady = notifications;
      _batteryReady = battery;
    });
  }

  /// بعض الأجهزة ما بتعرضش نافذة «طول الوقت»، فبنفتح إعدادات التطبيق
  Future<void> _enableLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        await Geolocator.openLocationSettings();
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.whileInUse) permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.always) await Geolocator.openAppSettings();
    } catch (_) {}
    await _check();
  }

  Future<void> _enableNotifications() async {
    await PushService.requestPermission();
    await _check();
    if (!_notificationsReady) await Geolocator.openAppSettings();
  }

  Future<void> _enableBattery() async {
    try {
      await _device.invokeMethod<void>('openBatterySettings');
    } catch (_) {
      await Geolocator.openAppSettings();
    }
  }

  Widget _step(String text, bool isDone, VoidCallback onEnable, {String? note}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(
            isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            color: isDone ? AppColors.success : AppColors.textMuted,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.dark)),
                if (note != null && !isDone)
                  Text(note, style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
          if (!isDone)
            SizedBox(
              width: 84,
              child: AppButton.outlined(text: 'فعّل', height: 36, fontSize: 12, onPressed: onEnable),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canStart = _locationReady && _notificationsReady;

    return AppSheet(
      title: 'عشان تجيلك طلبات وإنت برّه التطبيق',
      children: [
            const Text(
              'طول ما أنت متاح، بنحدث مكانك ونبعتلك الطلبات القريبة\nلو قفلت التطبيق من قائمة البرامج ممكن تخرج من الخدمة',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 12, height: 1.5, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            _step('اسمح بالموقع طول الوقت', _locationReady, _enableLocation),
            _step('اسمح بالإشعارات', _notificationsReady, _enableNotifications),
            _step('استثني التطبيق من توفير البطارية', _batteryReady, _enableBattery, note: 'من غيرها الطلبات ممكن تقف'),
            const SizedBox(height: 8),
            ...packSheetActions([
              SheetButton('ابدأ الاستقبال', canStart ? () => Navigator.of(context).pop(true) : null, isPrimary: true),
              SheetButton('مش دلوقتي', () => Navigator.of(context).pop(false)),
            ]),
      ],
    );
  }
}
