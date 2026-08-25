import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/colors.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../services/audio_service.dart';

class VoiceNoteRecorderScreen extends ConsumerStatefulWidget {
  const VoiceNoteRecorderScreen({super.key, required this.noteId});
  final String noteId;

  @override
  ConsumerState<VoiceNoteRecorderScreen> createState() => _VoiceNoteRecorderScreenState();
}

class _VoiceNoteRecorderScreenState extends ConsumerState<VoiceNoteRecorderScreen> {
  RecordingState _state = RecordingState.idle;
  Duration _elapsed = Duration.zero;
  String? _error;
  bool _saving = false;

  late final AudioService _audio;
  StreamSubscription<RecordingState>? _stateSub;
  StreamSubscription<Duration>? _elapsedSub;

  @override
  void initState() {
    super.initState();
    // AudioService is an app-wide singleton, so these subscriptions must be
    // cancelled on dispose or the closed widget keeps calling setState.
    _audio = ref.read(audioServiceProvider);
    _stateSub = _audio.stateStream.listen((s) {
      if (mounted) setState(() => _state = s);
    });
    _elapsedSub = _audio.elapsedStream.listen((d) {
      if (mounted) setState(() => _elapsed = d);
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _elapsedSub?.cancel();
    // Leaving mid-recording must not leave the microphone open.
    if (_state == RecordingState.recording || _state == RecordingState.paused) {
      unawaited(_audio.cancelRecording());
    }
    super.dispose();
  }

  String get _timeLabel {
    final totalSeconds = _elapsed.inSeconds;
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _start() async {
    setState(() => _error = null);
    try {
      HapticFeedback.mediumImpact();
      await _audio.startRecording();
    } on AudioServiceException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not start recording: $e');
    }
  }

  Future<void> _pauseResume() async {
    try {
      if (_state == RecordingState.recording) {
        await _audio.pauseRecording();
      } else if (_state == RecordingState.paused) {
        await _audio.resumeRecording();
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Recording error: $e');
    }
  }

  Future<void> _stopAndSave() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    HapticFeedback.heavyImpact();
    try {
      final result = await _audio.stopRecording();
      await ref.read(attachmentServiceProvider).saveAudio(
            noteId: widget.noteId,
            sourceFile: result.file,
            durationMs: result.duration.inMilliseconds,
          );
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save the recording: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = CupertinoTheme.of(context).brightness ?? Brightness.light;
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Voice Note')),
      child: Container(
        decoration: BoxDecoration(gradient: AppTheme.backgroundGradient(brightness)),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_timeLabel,
                    style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w200,
                        color: AppColors.textPrimary(brightness),
                        fontFeatures: const [FontFeature.tabularFigures()])),
                const SizedBox(height: 8),
                Text(
                  _state == RecordingState.recording
                      ? 'Recording…'
                      : _state == RecordingState.paused
                          ? 'Paused'
                          : 'Ready to record',
                  style: TextStyle(color: AppColors.textSecondary(brightness)),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: AppColors.danger)),
                ],
                const SizedBox(height: 48),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_state == RecordingState.recording || _state == RecordingState.paused) ...[
                      _RoundButton(
                        icon: _state == RecordingState.recording
                            ? CupertinoIcons.pause_fill
                            : CupertinoIcons.play_fill,
                        onTap: _pauseResume,
                        background: AppColors.glassFill(brightness),
                        iconColor: AppColors.textPrimary(brightness),
                      ),
                      const SizedBox(width: 24),
                      _RoundButton(
                        icon: CupertinoIcons.stop_fill,
                        onTap: _saving ? null : _stopAndSave,
                        background: AppColors.danger,
                        iconColor: CupertinoColors.white,
                        size: 72,
                      ),
                    ] else
                      _RoundButton(
                        icon: CupertinoIcons.mic_fill,
                        onTap: _start,
                        background: AppColors.projectAccents.first,
                        iconColor: CupertinoColors.white,
                        size: 72,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.onTap,
    required this.background,
    required this.iconColor,
    this.size = 56,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final Color background;
  final Color iconColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: background, shape: BoxShape.circle),
          child: Icon(icon, color: iconColor, size: size * 0.42),
        ),
      ),
    );
  }
}
