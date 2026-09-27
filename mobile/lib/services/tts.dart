import 'package:flutter_tts/flutter_tts.dart';

/// Reads text aloud (the Home question, voice messages from family).
class Tts {
  Tts._();
  static final FlutterTts _tts = FlutterTts();
  static bool _ready = false;

  static Future<void> say(String text) async {
    if (!_ready) {
      _ready = true;
      await _tts.setSpeechRate(0.45);
      await _tts.setPitch(1.0);
    }
    await _tts.stop();
    await _tts.speak(text);
  }

  static Future<void> stop() => _tts.stop();
}
