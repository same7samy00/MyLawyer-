import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/app_dialog.dart';

/// موبايلات زي ريلمي وأوبو وشاومي بتقفل التطبيق خالص لما يتقفل من قايمة البرامج،
/// فإشعارات الطلبات والاستشارات ما بتوصلش. أول مرة بنطلب من الموكل يسمح للتطبيق يشتغل في الخلفية
class BackgroundAlerts {
  BackgroundAlerts._();

  static const MethodChannel _device = MethodChannel('mylawyer/device');
  static const String _askedKey = 'background_alerts_asked';

  static Future<void> askOnce(BuildContext context) async {
    if (!Platform.isAndroid) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_askedKey) ?? false) return;
    bool exempt = false;
    try {
      exempt = await _device.invokeMethod<bool>('batteryExempt') ?? false;
    } catch (_) {}
    if (exempt) return;
    await prefs.setBool(_askedKey, true);
    if (!context.mounted) return;
    final allow = await AppDialog.confirm(
      context,
      icon: Icons.notifications_active_rounded,
      title: 'خلّي الإشعارات توصلك',
      message: 'عشان توصلك تحديثات طلباتك واستشاراتك وانت قافل التطبيق\nاسمح لـ My Lawyer يشتغل في الخلفية من غير توفير البطارية',
      confirmText: 'افتح الإعدادات',
    );
    if (!allow) return;
    try {
      await _device.invokeMethod<void>('openBatterySettings');
    } catch (_) {}
  }
}
