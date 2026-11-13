import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// جاهزية تحويل الكلام لنص على الموبايل ده
enum VoiceReady {
  ready,

  /// الإذن اتمنع أو الموبايل مفيهوش خدمة تعرّف على الكلام (زي موبايلات من غير خدمات جوجل)
  unavailable,

  /// الخدمة موجودة بس مش بتدعم العربي
  noArabic,
}

/// تحويل كلام العميل لنص. النص بيروح للإدارة بس، والعميل ما بيشوفوش.
/// منفصل عن الشاشة عشان الشاشة تتجرب بنسخة وهمية من غير ميكروفون
abstract class VoiceInput {
  Future<VoiceReady> prepare();

  /// بيبدأ يسمع. [onFailure] بيتنادى لو المحرك وقع في النص (مفيش نت مثلًا)
  Future<void> start({required VoidCallback onFailure});

  /// بيوقف السمع ويرجّع كل اللي اتقال
  Future<String> stop();

  Future<void> cancel();

  /// علو صوت العميل دلوقتي من 0 لـ 1، عشان علامة التسجيل تتحرك على قد صوته
  ValueListenable<double> get level;
}

/// التنفيذ الحقيقي: محرك التعرف على الكلام اللي في الموبايل نفسه (جوجل على أندرويد)، ببلاش.
/// أندرويد بيقفل السمع بعد وقفة قصيرة، فهنا بنفتحه تاني لوحدنا ونجمّع الأجزاء لحد ما العميل يدوس «خلصت»
class SpeechVoiceInput implements VoiceInput {
  final SpeechToText _speech = SpeechToText();
  String? _localeId;
  bool _wanted = false;
  bool _restarting = false;
  String _committed = '';
  String _partial = '';
  String _lastCommit = '';
  VoidCallback? _onFailure;
  final ValueNotifier<double> _level = ValueNotifier(0);

  @override
  ValueListenable<double> get level => _level;

  /// المحرك بيبعت العلو بالديسيبل تقريبًا من -2 لـ 10، وبنهدّيه شوية عشان العلامة ما ترعشش
  void _onSound(double db) {
    final now = ((db + 2) / 12).clamp(0.0, 1.0);
    _level.value = _level.value * 0.45 + now * 0.55;
  }

  /// أخطاء بتوقف التسجيل خالص، والباقي (مفيش كلام، انتهت المهلة) بيفتح السمع تاني
  static const _fatal = {'error_permission', 'error_network', 'error_server', 'error_language_not_supported', 'error_language_unavailable'};

  @override
  Future<VoiceReady> prepare() async {
    final ok = await _speech.initialize(onStatus: _onStatus, onError: _onError);
    if (!ok) return VoiceReady.unavailable;
    final locales = await _speech.locales();
    String normal(String id) => id.replaceAll('-', '_').toLowerCase();
    final egypt = locales.where((l) => normal(l.localeId) == 'ar_eg');
    final arabic = locales.where((l) => normal(l.localeId).startsWith('ar'));
    _localeId = egypt.isNotEmpty ? egypt.first.localeId : (arabic.isNotEmpty ? arabic.first.localeId : null);
    return _localeId == null ? VoiceReady.noArabic : VoiceReady.ready;
  }

  @override
  Future<void> start({required VoidCallback onFailure}) async {
    _onFailure = onFailure;
    _committed = '';
    _partial = '';
    _lastCommit = '';
    _wanted = true;
    await _listen();
  }

  Future<void> _listen() async {
    if (!_wanted || _speech.isListening) return;
    await _speech.listen(
      onResult: _onResult,
      onSoundLevelChange: _onSound,
      listenOptions: SpeechListenOptions(
        localeId: _localeId,
        listenFor: const Duration(minutes: 3),
        pauseFor: const Duration(seconds: 8),
        partialResults: true,
        cancelOnError: false,
        listenMode: ListenMode.dictation,
      ),
    );
  }

  void _onResult(SpeechRecognitionResult result) {
    _partial = result.recognizedWords;
    if (result.finalResult) {
      _commit(result.recognizedWords);
      _partial = '';
    }
  }

  /// أندرويد ساعات بيبعت النتيجة النهائية مرتين، فاللي زي اللي قبله بيتتجاهل
  void _commit(String words) {
    final text = words.trim();
    if (text.isEmpty || text == _lastCommit) return;
    _lastCommit = text;
    _committed = _committed.isEmpty ? text : '$_committed $text';
  }

  void _onStatus(String status) {
    if (!_wanted) return;
    if (status == SpeechToText.doneStatus || status == SpeechToText.notListeningStatus) _restartSoon();
  }

  void _onError(SpeechRecognitionError error) {
    if (!_wanted) return;
    if (_fatal.contains(error.errorMsg)) {
      _wanted = false;
      _onFailure?.call();
      return;
    }
    _restartSoon();
  }

  Future<void> _restartSoon() async {
    if (_restarting) return;
    _restarting = true;
    _commit(_partial);
    _partial = '';
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _restarting = false;
    if (_wanted) unawaited(_listen());
  }

  @override
  Future<String> stop() async {
    _wanted = false;
    _level.value = 0;
    await _speech.stop();
    // آخر نتيجة بتوصل بعد الإيقاف بلحظة
    await Future<void>.delayed(const Duration(milliseconds: 500));
    _commit(_partial);
    _partial = '';
    return _committed.trim();
  }

  @override
  Future<void> cancel() async {
    _wanted = false;
    _level.value = 0;
    _committed = '';
    _partial = '';
    await _speech.cancel();
  }
}
