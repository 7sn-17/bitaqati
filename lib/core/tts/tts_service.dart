import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Reads card text out loud.
///
/// The engine is created once and reused: building a new [FlutterTts] per
/// button leaks a platform channel per card, and the first utterance on a
/// cold engine takes noticeably longer.
///
/// Language is picked from the text itself rather than from the app locale,
/// because an Arabic interface is full of English terms (Fe, DNA, GDP) and
/// reading those with an Arabic voice is unintelligible.
class TtsService {
  TtsService._();

  static final TtsService instance = TtsService._();

  final FlutterTts _engine = FlutterTts();
  bool _configured = false;
  bool _speaking = false;

  /// Notifies listeners when speech starts and stops, so a button can show
  /// its own state without polling the engine.
  final ValueNotifier<bool> speaking = ValueNotifier<bool>(false);

  static final RegExp _arabic = RegExp(r'[\u0600-\u06FF]');

  Future<void> _configure() async {
    if (_configured) {
      return;
    }
    _configured = true;
    try {
      await _engine.awaitSpeakCompletion(true);
      await _engine.setSpeechRate(0.48);
      await _engine.setPitch(1.0);
      await _engine.setVolume(1.0);
    } catch (_) {
      // A device without a TTS engine simply stays silent.
    }
  }

  /// Speaks [text] in the language it is written in. Returns false when
  /// there was nothing to say or the platform refused.
  Future<bool> speak(String text) async {
    final String clean = _speakable(text);
    if (clean.isEmpty) {
      return false;
    }
    await _configure();
    await stop();
    try {
      await _engine.setLanguage(_arabic.hasMatch(clean) ? 'ar-SA' : 'en-US');
      _setSpeaking(true);
      await _engine.speak(clean);
      return true;
    } catch (_) {
      return false;
    } finally {
      _setSpeaking(false);
    }
  }

  Future<void> stop() async {
    try {
      await _engine.stop();
    } catch (_) {
      // Stopping a silent engine is not an error worth surfacing.
    }
    _setSpeaking(false);
  }

  void _setSpeaking(bool value) {
    if (_speaking == value) {
      return;
    }
    _speaking = value;
    speaking.value = value;
  }

  /// Strips everything the engine would read out literally: markdown
  /// emphasis, cloze wrappers, image and audio tokens, and bare URLs.
  static String _speakable(String raw) {
    String text = raw;
    text = text.replaceAllMapped(
      RegExp(r'\{\{c\d+::(.*?)\}\}'),
      (Match match) => match.group(1) ?? '',
    );
    text = text.replaceAll(RegExp(r'!\[[^\]]*\]\([^)]+\)'), ' ');
    text = text.replaceAllMapped(
      RegExp(r'\[([^\]]*)\]\([^)]+\)'),
      (Match match) => match.group(1) ?? '',
    );
    text = text.replaceAll(RegExp(r'https?://\S+'), ' ');
    text = text.replaceAll(RegExp(r'[*_~`#]'), '');
    text = text.replaceAll(RegExp(r'\$'), '');
    text = text.replaceAll(RegExp(r'\s+'), ' ');
    return text.trim();
  }
}
