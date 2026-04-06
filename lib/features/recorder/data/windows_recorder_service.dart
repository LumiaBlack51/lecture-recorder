import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:record/record.dart';

import '../../../shared/recording_naming.dart';
import '../domain/recorder_models.dart';
import '../domain/recorder_service.dart';

class WindowsRecorderService implements RecorderService {
  final AudioRecorder _recorder = AudioRecorder();
  final _eventsController = StreamController<RecorderEvent>.broadcast();

  RecordingRequest? _request;
  Timer? _segmentTimer;
  int _currentSegmentIndex = 0;
  String? _currentFilePath;
  bool _isRecording = false;
  bool _isSwitching = false;
  bool _isPaused = false;

  @override
  Stream<RecorderEvent> get events => _eventsController.stream;

  @override
  bool get supportsPauseResume => true;

  @override
  Future<RecorderStartResult> startRecording(RecordingRequest request) async {
    if (_isRecording) {
      throw StateError('A recording session is already active.');
    }

    _request = request;
    _currentSegmentIndex = 1;
    _currentFilePath = await _startSegment(_currentSegmentIndex);
    _isRecording = true;
    _isPaused = false;
    _scheduleNextSegment();

    _eventsController.add(
      RecorderEvent(
        type: RecorderEventType.started,
        segmentIndex: _currentSegmentIndex,
        filePath: _currentFilePath,
      ),
    );

    return RecorderStartResult(
      segmentIndex: _currentSegmentIndex,
      filePath: _currentFilePath!,
    );
  }

  @override
  Future<void> stopRecording() async {
    if (!_isRecording && !_isSwitching) {
      return;
    }

    _segmentTimer?.cancel();
    final stoppedPath = await _recorder.stop();
    if (stoppedPath != null && stoppedPath.isNotEmpty) {
      _eventsController.add(
        RecorderEvent(
          type: RecorderEventType.segmentCompleted,
          segmentIndex: _currentSegmentIndex,
          filePath: stoppedPath,
        ),
      );
    }

    _eventsController.add(
      RecorderEvent(
        type: RecorderEventType.stopped,
        segmentIndex: _currentSegmentIndex,
        filePath: stoppedPath ?? _currentFilePath,
      ),
    );

    _currentFilePath = null;
    _isRecording = false;
    _isSwitching = false;
    _isPaused = false;
  }

  @override
  Future<void> pauseRecording() async {
    await _recorder.pause();
    _segmentTimer?.cancel();
    _isPaused = true;
    _eventsController.add(
      RecorderEvent(
        type: RecorderEventType.paused,
        segmentIndex: _currentSegmentIndex,
        filePath: _currentFilePath,
      ),
    );
  }

  @override
  Future<void> resumeRecording() async {
    await _recorder.resume();
    _isPaused = false;
    _scheduleNextSegment();
    _eventsController.add(
      RecorderEvent(
        type: RecorderEventType.resumed,
        segmentIndex: _currentSegmentIndex,
        filePath: _currentFilePath,
      ),
    );
  }

  @override
  Future<RecorderStateSnapshot?> getRecordingState() async {
    final request = _request;
    final filePath = _currentFilePath;
    if (!_isRecording || request == null || filePath == null) {
      return null;
    }

    return RecorderStateSnapshot(
      courseName: request.courseName,
      sessionStart: request.sessionStart,
      segmentIndex: _currentSegmentIndex,
      filePath: filePath,
      isPaused: _isPaused,
      elapsed: Duration.zero,
    );
  }

  Future<String> _startSegment(int segmentIndex) async {
    final request = _request;
    if (request == null) {
      throw StateError('Recording request is missing.');
    }

    final filePath = path.join(
      request.courseDirectoryPath,
      buildRecordingFileName(
        courseName: request.courseName,
        sessionStart: request.sessionStart,
        segmentIndex: segmentIndex,
        extension: 'm4a',
      ),
    );

    final file = File(filePath);
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }

    await _recorder.start(
      RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: request.settings.audioQuality.windowsBitRate,
        sampleRate: request.settings.audioQuality.sampleRate,
      ),
      path: filePath,
    );

    return filePath;
  }

  void _scheduleNextSegment() {
    _segmentTimer?.cancel();
    final request = _request;
    if (request == null || !request.settings.segmentationEnabled) {
      return;
    }

    _segmentTimer = Timer(
      Duration(minutes: request.settings.windowsSegmentMinutes),
      () async {
        await _switchSegment();
      },
    );
  }

  Future<void> _switchSegment() async {
    if (_isSwitching || !_isRecording) {
      return;
    }

    _isSwitching = true;
    final completedPath = await _recorder.stop();
    if (completedPath != null && completedPath.isNotEmpty) {
      _eventsController.add(
        RecorderEvent(
          type: RecorderEventType.segmentCompleted,
          segmentIndex: _currentSegmentIndex,
          filePath: completedPath,
        ),
      );
    }

    _currentSegmentIndex += 1;
    _currentFilePath = await _startSegment(_currentSegmentIndex);
    _isPaused = false;
    _eventsController.add(
      RecorderEvent(
        type: RecorderEventType.segmentSwitched,
        segmentIndex: _currentSegmentIndex,
        filePath: _currentFilePath,
      ),
    );
    _isSwitching = false;
    _scheduleNextSegment();
  }

  @override
  Future<void> dispose() async {
    _segmentTimer?.cancel();
    if (_isRecording || _isSwitching) {
      await _recorder.stop();
    }
    await _recorder.dispose();
    await _eventsController.close();
  }
}
