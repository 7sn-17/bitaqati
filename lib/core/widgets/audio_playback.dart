import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A play button, a waveform and a time readout for one recording.
///
/// The card stores nothing but the URL, so the widget owns its own player: a
/// card can carry a voice note on each side and they must not fight over one
/// shared instance. Nothing is fetched until the learner taps play, which keeps
/// a deck full of audio cheap to scroll through.
class AudioAttachment extends StatefulWidget {
  const AudioAttachment({required this.url, super.key});

  final String url;

  @override
  State<AudioAttachment> createState() => _AudioAttachmentState();
}

class _AudioAttachmentState extends State<AudioAttachment> {
  /// Enough bars to read as a waveform at chip width, few enough that each one
  /// stays a visible 2-3 px sliver on a small phone.
  static const int _barCount = 26;

  late final AudioPlayer _player;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<PlayerState>? _stateSub;

  Duration _position = Duration.zero;
  Duration _total = Duration.zero;
  PlayerState _state = PlayerState.stopped;
  bool _broken = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    // ReleaseMode.stop rewinds when the clip ends, so a second tap replays it
    // from the beginning instead of sitting at the end doing nothing.
    _player.setReleaseMode(ReleaseMode.stop);
    _positionSub = _player.onPositionChanged.listen((Duration value) {
      if (mounted) {
        setState(() => _position = value);
      }
    });
    _durationSub = _player.onDurationChanged.listen((Duration value) {
      if (mounted) {
        setState(() => _total = value);
      }
    });
    _stateSub = _player.onPlayerStateChanged.listen((PlayerState value) {
      if (!mounted) {
        return;
      }
      setState(() {
        _state = value;
        if (value == PlayerState.completed || value == PlayerState.stopped) {
          _position = Duration.zero;
        }
      });
    });
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  bool get _playing => _state == PlayerState.playing;

  Future<void> _toggle() async {
    if (_broken) {
      return;
    }
    try {
      switch (_state) {
        case PlayerState.playing:
          await _player.pause();
        case PlayerState.paused:
          await _player.resume();
        default:
          await _player.play(_source());
      }
    } catch (_) {
      // A file that was never uploaded can be gone from the device, and a
      // deleted cloud file 404s. Either way the chip says so instead of
      // pretending to play.
      if (mounted) {
        setState(() => _broken = true);
      }
    }
  }

  /// The stored URL is either a CDN address or a 'file://' path from an
  /// attachment that never left this device.
  Source _source() {
    final String value = widget.url.trim();
    final Uri? uri = Uri.tryParse(value);
    if (uri != null && uri.scheme == 'file') {
      return DeviceFileSource(uri.toFilePath());
    }
    return UrlSource(value);
  }

  double get _progress {
    if (_total.inMilliseconds <= 0) {
      return 0;
    }
    return (_position.inMilliseconds / _total.inMilliseconds).clamp(0.0, 1.0);
  }

  /// A stable bar height per index, derived from the URL.
  ///
  /// The real waveform would need the decoded samples; a deterministic shape
  /// gives the same "this is a recording" read for a fraction of the cost, and
  /// the same clip always looks the same.
  double _heightAt(int index) {
    final int seed = (widget.url.hashCode ^ (index * 2654435761)).abs();
    return 7 + (seed % 100) / 100 * 17;
  }

  String _label() {
    if (_broken) {
      return 'تعذّر تشغيل المقطع';
    }
    if (_total > Duration.zero) {
      return '${_format(_position)} / ${_format(_total)}';
    }
    return _playing ? 'جارٍ التشغيل…' : 'اضغط للتشغيل';
  }

  static String _format(Duration value) {
    final int minutes = value.inMinutes;
    final String seconds = (value.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final double progress = _progress;
    final int filled = (progress * _barCount).round();
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(6, 6, 14, 6),
      decoration: BoxDecoration(
        color: context.softAccent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          Material(
            color: context.brandInk,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _toggle,
              child: SizedBox(
                width: 38,
                height: 38,
                child: Icon(
                  _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 22,
                  color: context.softAccent,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox(
                  height: 26,
                  child: Row(
                    children: <Widget>[
                      for (int index = 0; index < _barCount; index++)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 1),
                            child: Align(
                              alignment: Alignment.center,
                              child: Container(
                                height: _heightAt(index),
                                decoration: BoxDecoration(
                                  color: index < filled
                                      ? context.brandInk
                                      : context.brandInk.withValues(
                                          alpha: 0.22,
                                        ),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _label(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.bodySmall?.copyWith(
                    color: context.brandInk,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
