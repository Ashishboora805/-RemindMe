import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:uuid/uuid.dart';

enum RecordingState { idle, recording, paused, stopped }

/// Wraps `record` (capture) and `just_audio` (playback) so the voice-note
/// feature does real, local-only audio I/O — no fake timers, no stub state.
class AudioService {
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();
  final _uuid = const Uuid();

  String? _currentRecordingPath;
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  final _elapsedController = StreamController<Duration>.broadcast();
  final _stateController = StreamController<RecordingState>.broadcast();

  Stream<Duration> get elapsedStream => _elapsedController.stream;
  Stream<RecordingState> get stateStream => _stateController.stream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  Future<bool> requestMicPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<void> startRecording() async {
    final granted = await requestMicPermission();
    if (!granted) {
      throw AudioServiceException('Microphone permission was denied.');
    }
    final tempDir = await getTemporaryDirectory();
    final path = p.join(tempDir.path, '${_uuid.v4()}.m4a');
    _currentRecordingPath = path;

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000, sampleRate: 44100),
      path: path,
    );
    _elapsed = Duration.zero;
    _stateController.add(RecordingState.recording);
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      _elapsed += const Duration(milliseconds: 200);
      _elapsedController.add(_elapsed);
    });
  }

  Future<void> pauseRecording() async {
    await _recorder.pause();
    _timer?.cancel();
    _stateController.add(RecordingState.paused);
  }

  Future<void> resumeRecording() async {
    await _recorder.resume();
    _stateController.add(RecordingState.recording);
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      _elapsed += const Duration(milliseconds: 200);
      _elapsedController.add(_elapsed);
    });
  }

  /// Stops recording and returns the local temp file + duration. The caller
  /// (note editor) then hands this to AttachmentService.saveAudio() to move
  /// it into permanent app storage.
  Future<RecordingResult> stopRecording() async {
    _timer?.cancel();
    final path = await _recorder.stop();
    _stateController.add(RecordingState.stopped);
    if (path == null || _currentRecordingPath == null) {
      throw AudioServiceException('Recording failed to save.');
    }
    final file = File(path);
    final duration = _elapsed;
    _currentRecordingPath = null;
    return RecordingResult(file: file, duration: duration);
  }

  Future<void> cancelRecording() async {
    _timer?.cancel();
    try {
      await _recorder.stop();
    } catch (_) {}
    if (_currentRecordingPath != null) {
      final f = File(_currentRecordingPath!);
      if (await f.exists()) await f.delete();
    }
    _currentRecordingPath = null;
    _stateController.add(RecordingState.idle);
  }

  /// Path of the file currently loaded into the player, so the UI can tell
  /// which recording a "playing" state belongs to.
  String? get currentPath => _currentPlaybackPath;
  String? _currentPlaybackPath;

  Future<void> playFile(String path) async {
    if (_currentPlaybackPath != path) {
      await _player.setFilePath(path);
      _currentPlaybackPath = path;
    } else if (_player.processingState == ProcessingState.completed) {
      await _player.seek(Duration.zero);
    }
    await _player.play();
  }

  Future<void> pausePlayback() => _player.pause();

  Future<void> stopPlayback() async {
    await _player.stop();
    _currentPlaybackPath = null;
  }

  void dispose() {
    _timer?.cancel();
    _elapsedController.close();
    _stateController.close();
    _recorder.dispose();
    _player.dispose();
  }
}

class RecordingResult {
  final File file;
  final Duration duration;
  RecordingResult({required this.file, required this.duration});
}

class AudioServiceException implements Exception {
  final String message;
  AudioServiceException(this.message);
  @override
  String toString() => message;
}
