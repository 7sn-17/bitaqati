import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// The two feedback sounds every study mode shares.
///
/// One player is reused rather than one per cue: a second cue should replace
/// the first, not layer over it, and a rapid run of correct answers must not
/// spawn a player per answer. Playback is fire-and-forget — a device with no
/// audio route, or an asset that failed to decode, must never interrupt a
/// session, so every failure is swallowed after being logged.
class SoundService {
  SoundService._();

  static final SoundService instance = SoundService._();

  AudioPlayer? _player;

  /// A rising three-note chime for a correct answer or a cleared pair.
  Future<void> correct() => _play('sounds/correct.wav');

  /// A low double buzz for a wrong answer.
  Future<void> wrong() => _play('sounds/wrong.wav');

  Future<void> _play(String asset) async {
    try {
      final AudioPlayer player = _player ??= AudioPlayer();
      await player.stop();
      await player.play(AssetSource(asset), volume: 0.85);
    } catch (error) {
      debugPrint('sound unavailable: $error');
    }
  }

  Future<void> dispose() async {
    await _player?.dispose();
    _player = null;
  }
}
