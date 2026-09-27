import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Live speech-to-text using the phone's built-in recognizer
/// (Google on Android, Apple on iOS).
///
/// Android ends a recognition session after a few seconds of silence, so this
/// class quietly starts a new session until the user taps "I'm done", and
/// joins the pieces together. The screen just reads [text] and [seconds].
///
/// There is one shared instance because the plugin only accepts its status
/// and error callbacks once.
class SpeechService extends ChangeNotifier {
  SpeechService._();
  static final SpeechService instance = SpeechService._();

  final SpeechToText _stt = SpeechToText();
  bool _initialized = false;

  bool available = false;
  String? errorMessage;

  /// Finished sentences from earlier sessions.
  String _committed = '';

  /// Words of the current session (still changing while she talks).
  String _partial = '';

  bool _wantListening = false;
  bool paused = false;
  int seconds = 0;

  /// Microphone loudness from 0 to 1, for the wave bars.
  double level = 0;

  int _session = 0;
  Timer? _clock;
  Timer? _restartTimer;

  bool get isActive => _wantListening && !paused;
  bool get hearing => _stt.isListening;

  /// Everything heard so far.
  String get text => _join(_committed, _partial);

  /// The last few words, shown in a lighter colour like the prototype.
  String get committedText => _committed;
  String get partialText => _partial;

  static String _join(String a, String b) {
    if (a.isEmpty) return b.trim();
    if (b.isEmpty) return a.trim();
    return '${a.trim()} ${b.trim()}';
  }

  Future<bool> _ensureInit() async {
    if (_initialized) return available;
    _initialized = true;
    try {
      available = await _stt.initialize(
        onStatus: _onStatus,
        onError: _onError,
      );
    } catch (e) {
      available = false;
    }
    if (!available) {
      errorMessage =
          "Speech isn't available. Check the microphone permission, or type your words on the next screen.";
    }
    return available;
  }

  /// Start a fresh recording.
  Future<void> begin() async {
    _committed = '';
    _partial = '';
    seconds = 0;
    level = 0;
    paused = false;
    errorMessage = null;
    _wantListening = true;
    notifyListeners();

    _clock?.cancel();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (isActive) {
        seconds++;
        notifyListeners();
      }
    });

    if (!await _ensureInit()) {
      notifyListeners();
      return;
    }
    await _listenNow();
  }

  Future<void> _listenNow() async {
    if (!_wantListening || paused || !available) return;
    if (_stt.isListening) return;

    // Keep any unfinished words from the last session.
    if (_partial.isNotEmpty) {
      _committed = _join(_committed, _partial);
      _partial = '';
    }
    final session = ++_session;
    try {
      await _stt.listen(
        onResult: (r) => _onResult(r, session),
        onSoundLevelChange: (db) {
          // Android reports about -2..10 dB; iOS uses a similar scale.
          level = ((db + 2) / 12).clamp(0.0, 1.0);
          notifyListeners();
        },
        listenOptions: SpeechListenOptions(
          partialResults: true,
          listenMode: ListenMode.dictation,
          cancelOnError: false,
          autoPunctuation: true,
          listenFor: const Duration(minutes: 5),
          pauseFor: const Duration(seconds: 30),
        ),
      );
    } catch (e) {
      debugPrint('listen failed: $e');
      _scheduleRestart();
    }
    notifyListeners();
  }

  void _onResult(SpeechRecognitionResult r, int session) {
    if (session != _session) return; // late result from an old session
    if (r.finalResult) {
      _committed = _join(_committed, r.recognizedWords);
      _partial = '';
    } else {
      _partial = r.recognizedWords;
    }
    notifyListeners();
  }

  void _onStatus(String status) {
    debugPrint('speech status: $status');
    if (status == 'done' || status == 'notListening') {
      level = 0;
      notifyListeners();
      if (isActive) _scheduleRestart();
    }
  }

  void _onError(SpeechRecognitionError e) {
    debugPrint('speech error: ${e.errorMsg} permanent=${e.permanent}');
    // "no match" and "speech timeout" just mean silence, so keep going.
    // Android and web (Chrome) use different names for "mic not allowed".
    const blocked = {
      'error_permission',
      'error_insufficient_permissions',
      'not-allowed',
      'service-not-allowed',
      'audio-capture',
    };
    if (blocked.contains(e.errorMsg)) {
      errorMessage = kIsWeb
          ? 'Microphone is blocked. Click the mic icon in the address bar to allow it, or tap I\'m done to type instead.'
          : 'Please allow microphone access in Settings, or tap I\'m done to type instead.';
      _wantListening = false;
      notifyListeners();
      return;
    }
    if (isActive) _scheduleRestart();
  }

  void _scheduleRestart() {
    _restartTimer?.cancel();
    _restartTimer = Timer(const Duration(milliseconds: 350), _listenNow);
  }

  Future<void> pause() async {
    paused = true;
    level = 0;
    _restartTimer?.cancel();
    notifyListeners();
    await _stt.stop();
  }

  Future<void> resume() async {
    paused = false;
    notifyListeners();
    await _listenNow();
  }

  /// Clear everything and listen again ("Start over").
  Future<void> startOver() async {
    _session++; // ignore anything still arriving from the old session
    _restartTimer?.cancel();
    await _stt.cancel();
    _committed = '';
    _partial = '';
    seconds = 0;
    paused = false;
    notifyListeners();
    await _listenNow();
  }

  /// Stop and return the full text ("I'm done").
  Future<String> finish() async {
    _wantListening = false;
    _restartTimer?.cancel();
    _clock?.cancel();
    if (_stt.isListening) {
      await _stt.stop();
      // Give the recognizer a moment to deliver the final words.
      await Future.delayed(const Duration(milliseconds: 600));
    }
    level = 0;
    final result = text;
    notifyListeners();
    return result;
  }

  /// Leave the screen without saving.
  Future<void> cancel() async {
    _wantListening = false;
    _session++;
    _restartTimer?.cancel();
    _clock?.cancel();
    level = 0;
    await _stt.cancel();
  }
}
