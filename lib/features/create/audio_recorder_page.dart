import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// Records a voice note and returns the file path, or null when the learner
/// backs out without saving.
///
/// The page owns nothing but the microphone: the caller uploads the file and
/// attaches it, so the recording flow has one job and one failure mode.
class AudioRecorderPage extends StatefulWidget {
  const AudioRecorderPage({super.key});

  /// Opens the recorder and resolves to the saved file path.
  static Future<String?> open(BuildContext context) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        fullscreenDialog: true,
        builder: (BuildContext context) => const AudioRecorderPage(),
      ),
    );
  }

  @override
  State<AudioRecorderPage> createState() => _AudioRecorderPageState();
}

class _AudioRecorderPageState extends State<AudioRecorderPage> {
  /// Five minutes at 64 kbps mono is about 2.4 MB: long enough for a full
  /// explanation, small enough to upload over a phone connection.
  static const int _maxSeconds = 300;

  /// Mono, 44.1 kHz, AAC at 64 kbps. Speech at this rate is transparent on a
  /// phone speaker and a tenth of the size of a wav of the same length.
  static const RecordConfig _config = RecordConfig(
    encoder: AudioEncoder.aacLc,
    bitRate: 64000,
    sampleRate: 44100,
    numChannels: 1,
  );

  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<RecordState>? _stateSub;
  StreamSubscription<Amplitude>? _amplitudeSub;
  Timer? _ticker;

  RecordState _state = RecordState.stop;
  int _seconds = 0;
  double _level = 0;
  bool _saving = false;

  /// True once the take has been stopped or thrown away, so dispose does not
  /// call cancel() on a file that is already on its way to the uploader.
  bool _released = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _stateSub = _recorder.onStateChanged().listen(_onState);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _stateSub?.cancel();
    _amplitudeSub?.cancel();
    // Leaving mid-recording must release the microphone, or the next attempt
    // fails with "recorder already in use". A finished take is left alone:
    // cancel() deletes the file, and the caller is uploading it right now.
    if (!_released && _state != RecordState.stop) {
      _recorder.cancel();
    }
    _recorder.dispose();
    super.dispose();
  }

  void _onState(RecordState value) {
    if (!mounted) {
      return;
    }
    setState(() => _state = value);
    if (value == RecordState.record) {
      _startTicker();
    } else {
      _ticker?.cancel();
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _seconds++);
      if (_seconds >= _maxSeconds) {
        _stopAndSave();
      }
    });
  }

  Future<void> _start() async {
    setState(() => _error = null);
    try {
      final bool allowed = await _recorder.hasPermission();
      if (!mounted) {
        return;
      }
      if (!allowed) {
        setState(
          () => _error =
              'يحتاج التطبيق إلى إذن الميكروفون لتسجيل الصوت. '
              'اسمح به من إعدادات الجهاز ثم أعد المحاولة.',
        );
        return;
      }
      final Directory dir = await getTemporaryDirectory();
      final String path =
          '${dir.path}/recording-${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(_config, path: path);
      _amplitudeSub ??= _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 160))
          .listen((Amplitude amplitude) {
            if (!mounted) {
              return;
            }
            // dBFS: -55 is silence in a quiet room, 0 is clipping.
            setState(
              () => _level = ((amplitude.current + 55) / 55).clamp(0.0, 1.0),
            );
          });
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = 'تعذّر بدء التسجيل. تحقق من الميكروفون وحاول مرة أخرى.',
        );
      }
    }
  }

  Future<void> _stopAndSave() async {
    if (_saving) {
      return;
    }
    setState(() => _saving = true);
    _ticker?.cancel();
    try {
      final String? path = await _recorder.stop();
      _released = true;
      if (!mounted) {
        return;
      }
      if (path == null || path.isEmpty) {
        setState(() {
          _saving = false;
          _error = 'لم يُحفظ التسجيل. حاول مرة أخرى.';
        });
        return;
      }
      Navigator.of(context).pop(path);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'لم يُحفظ التسجيل. حاول مرة أخرى.';
        });
      }
    }
  }

  Future<void> _discard() async {
    _ticker?.cancel();
    _released = true;
    await _recorder.cancel();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  static String _clock(int seconds) {
    final String minutes = (seconds ~/ 60).toString();
    final String rest = (seconds % 60).toString().padLeft(2, '0');
    return '${minutes}:${rest}';
  }

  @override
  Widget build(BuildContext context) {
    final bool recording = _state == RecordState.record;
    final bool paused = _state == RecordState.pause;
    final bool started = _state != RecordState.stop;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 18, 0),
              child: Row(
                children: <Widget>[
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    tooltip: 'إغلاق',
                    icon: const Icon(CupertinoIcons.xmark, size: 20),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'تسجيل صوتي',
                    style: context.texts.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _StatusPill(recording: recording, paused: paused),
                    const SizedBox(height: 22),
                    Text(
                      _clock(_seconds),
                      style: TextStyle(
                        fontSize: 58,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        color: context.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'الحد الأقصى 5:00',
                      style: context.texts.bodySmall?.copyWith(
                        color: context.muted,
                      ),
                    ),
                    const SizedBox(height: 26),
                    _LevelMeter(level: started ? _level : 0, active: recording),
                  ],
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    _error!,
                    style: context.texts.bodySmall?.copyWith(
                      color: AppColors.warningInk,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            _RecordButton(
              recording: recording,
              paused: paused,
              busy: _saving,
              onTap: () {
                if (!started) {
                  _start();
                } else if (recording) {
                  _recorder.pause();
                } else {
                  _recorder.resume();
                }
              },
            ),
            const SizedBox(height: 14),
            Text(
              recording
                  ? 'اضغط للإيقاف المؤقت'
                  : (paused ? 'اضغط لمتابعة التسجيل' : 'اضغط لبدء التسجيل'),
              style: context.texts.bodySmall?.copyWith(color: context.muted),
            ),
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextButton(
                      onPressed: started ? _discard : null,
                      style: TextButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        foregroundColor: context.muted,
                      ),
                      child: const Text('إلغاء'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: started && !_saving ? _stopAndSave : null,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(CupertinoIcons.checkmark_alt, size: 18),
                      label: Text(_saving ? 'جارٍ الحفظ…' : 'إيقاف وحفظ'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.recording, required this.paused});

  final bool recording;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    final String label = recording
        ? 'جارٍ التسجيل'
        : (paused ? 'متوقف مؤقتاً' : 'جاهز للتسجيل');
    final Color tint = recording ? AppColors.danger : context.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: context.texts.labelMedium?.copyWith(
              color: tint,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelMeter extends StatelessWidget {
  const _LevelMeter({required this.level, required this.active});

  final double level;
  final bool active;

  static const int _bars = 29;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int index = 0; index < _bars; index++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Container(
                width: 3,
                height: _heightAt(index),
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.danger.withValues(alpha: 0.75)
                      : context.muted.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// A symmetric envelope: tall in the middle, short at the edges, scaled by
  /// the live input level so silence is a flat line and speech fills it out.
  double _heightAt(int index) {
    final double centre = (_bars - 1) / 2;
    final double distance = (index - centre).abs() / centre;
    final double envelope = 1 - distance * 0.65;
    final double seed = ((index * 37) % 11) / 11;
    return 6 + (level * envelope * (0.55 + seed * 0.45)) * 46;
  }
}

class _RecordButton extends StatelessWidget {
  const _RecordButton({
    required this.recording,
    required this.paused,
    required this.busy,
    required this.onTap,
  });

  final bool recording;
  final bool paused;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool live = recording || paused;
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 92,
        height: 92,
        decoration: BoxDecoration(
          color: live
              ? AppColors.danger
              : AppColors.danger.withValues(alpha: 0.12),
          shape: BoxShape.circle,
          boxShadow: live
              ? <BoxShadow>[
                  BoxShadow(
                    color: AppColors.danger.withValues(alpha: 0.32),
                    blurRadius: 26,
                    spreadRadius: 4,
                  ),
                ]
              : null,
        ),
        child: Icon(
          recording
              ? Icons.pause_rounded
              : (paused ? Icons.play_arrow_rounded : Icons.mic_rounded),
          size: 38,
          color: live ? Colors.white : AppColors.danger,
        ),
      ),
    );
  }
}
