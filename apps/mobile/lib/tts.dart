/// Voice flashcards (ROADMAP #7), the speech engine behind "reads card
/// fronts/backs aloud". Flutter TTS uses the platform's on-device speech
/// synthesis: no recording, no microphone permission, works offline.
///
/// The engine is injected so every rule and screen runs in tests with a
/// fake and zero platform channels.
library;

import 'package:flutter_tts/flutter_tts.dart';

/// What the flashcard player needs from any speech engine.
abstract class SpeechEngine {
  /// True when this device can talk at all.
  bool get supported;

  /// Speaks [text], replacing anything currently being spoken.
  Future<void> speak(String text);

  /// Stops playback immediately (card change, screen exit).
  Future<void> stop();

  /// Releases any resources; safe to call multiple times.
  void dispose();
}

/// Production engine backed by the flutter_tts plugin (on-device TTS).
/// Every call is defensive: a platform without a TTS service must never
/// crash the player, voice is an enhancement, never a hard requirement.
class FlutterTtsEngine implements SpeechEngine {
  FlutterTtsEngine() {
    _configure();
  }

  final FlutterTts _tts = FlutterTts();

  Future<void> _configure() async {
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      await _tts.awaitSpeakCompletion(false);
    } catch (_) {
      // Unsupported platform, [supported] stays true but every call is
      // a no-op; the player still works with text only.
    }
  }

  @override
  bool get supported => true;

  @override
  Future<void> speak(String text) async {
    final t = text.trim();
    if (t.isEmpty) return;
    try {
      await _tts.stop();
      await _tts.speak(t);
    } catch (_) {
      // Voice unavailable, silent fallback to the visual card.
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }

  @override
  void dispose() {}
}

/// Test double that records what it was asked to say.
class FakeSpeechEngine implements SpeechEngine {
  FakeSpeechEngine({this.supported = true});

  @override
  bool supported;
  final List<String> spoken = <String>[];
  int stopCount = 0;

  @override
  Future<void> speak(String text) async {
    if (!supported) return;
    spoken.add(text);
  }

  @override
  Future<void> stop() async => stopCount++;

  @override
  void dispose() {}
}
