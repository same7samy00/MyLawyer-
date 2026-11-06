import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// آخر بيانات اتعرضت على الموبايل، عشان الصفحة تظهر فورًا من غير شاشة تحميل.
/// السيرفر هو المرجع دايمًا، وده بس اللي بيظهر لحد ما التحديث يوصل.
/// الأرقام والعناوين والتوكن ما بيتحفظوش هنا، وكل حاجة بتتمسح عند الخروج من الحساب.
class SavedData {
  SavedData._();

  static const String _prefix = 'saved_data_';
  static final Map<String, Object?> _memory = {};

  /// كل المحفوظ بيتقرا مرة واحدة أول ما التطبيق يفتح، عشان الصفحات تقراه من غير انتظار
  static Future<void> preload() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys().where((key) => key.startsWith(_prefix))) {
        final raw = prefs.getString(key);
        if (raw != null) _memory[key.substring(_prefix.length)] = jsonDecode(raw);
      }
    } catch (_) {
      // من غير المحفوظ الصفحات بتستنى السيرفر زي الأول
    }
  }

  /// المحفوظ فورًا من غير انتظار، للصفحة وهي بتترسم أول مرة
  static Object? peek(String key) => _memory[key];

  static Future<Object?> read(String key) async {
    if (_memory.containsKey(key)) return _memory[key];
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_prefix$key');
      final value = raw == null ? null : jsonDecode(raw);
      _memory[key] = value;
      return value;
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(String key, Object? value) async {
    _memory[key] = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_prefix$key', jsonEncode(value));
    } catch (_) {
      // الحفظ مش شرط، الصفحة بتشتغل من غيره
    }
  }

  static Future<void> clear() async {
    _memory.clear();
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().where((key) => key.startsWith(_prefix)).toList()) {
      await prefs.remove(key);
    }
  }
}
