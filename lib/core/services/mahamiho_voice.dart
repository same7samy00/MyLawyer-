import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// ردود محاميحو المسجلة («أهلاً بيك»، «بسمعك»، «فهمت طلبك»...). مش ذكاء اصطناعي: جمل ثابتة بتتسجل مرة واحدة
/// وبتشتغل من التطبيق من غير نت ومن غير تكلفة.
/// الملفات في `assets/mahamiho/voice/<الاسم>.mp3`. أي جملة ملفها مش موجود بتظهر مكتوبة بس من غير صوت،
/// فتقدر تضيف الملفات في أي وقت من غير تعديل في الكود (`docs/VOICE_SERVICES.md` فيه الأسماء والنصوص).
class MahamihoVoice {
  MahamihoVoice._();

  static const String _folder = 'assets/mahamiho/voice/';
  static AudioPlayer? _player;
  static Set<String>? _clips;

  /// كل ملفات الصوت الموجودة فعلًا في التطبيق
  static Future<Set<String>> _available() async {
    final cached = _clips;
    if (cached != null) return cached;
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    return _clips = manifest.listAssets().where((path) => path.startsWith(_folder) && !path.endsWith('.gitkeep')).toSet();
  }

  /// بيشغّل الجملة لو ملفها موجود، ومن غير ما يوقع التطبيق لو لأ
  static Future<void> say(String line) async {
    try {
      final path = (await _available()).where((asset) => asset.startsWith('$_folder$line.')).firstOrNull;
      if (path == null) return;
      final player = _player ??= AudioPlayer();
      await player.stop();
      await player.play(AssetSource(path.substring('assets/'.length)));
    } catch (_) {
      // الصوت مجرد إضافة، والكلام المكتوب موجود
    }
  }

  static Future<void> stop() async {
    try {
      await _player?.stop();
    } catch (_) {
      // ما فيش حاجة تتعمل
    }
  }
}
