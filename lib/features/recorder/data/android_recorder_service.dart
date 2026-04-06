import 'dart:async';

import 'package:flutter/services.dart';

import '../domain/recorder_models.dart';
import '../domain/recorder_service.dart';

class AndroidRecorderService implements RecorderService {
  AndroidRecorderService() {
    _subscription = _eventChannel.receiveBroadcastStream().listen(
      _handleNativeEvent,
      onError: (Object error) {
        _eventsController.add(
          RecorderEvent(
            type: RecorderEventType.error,
            message: error.toString(),
          ),
        );
      },
    );
  }

  static const _methodChannel = MethodChannel('lecture_recorder/recorder');
  static const _eventChannel = EventChannel('lecture_recorder/recorder_events');

  final _eventsController = StreamController<RecorderEvent>.broadcast();
  StreamSubscription<dynamic>? _subscription;

  @override
  Stream<RecorderEvent> get events => _eventsController.stream;

  @override
  bool get supportsPauseResume => true;

  @override
  Future<RecorderStartResult> startRecording(RecordingRequest request) async {
    final result = await _methodChannel
        .invokeMapMethod<String, dynamic>('startRecording', {
          'courseName': request.courseName,
          'courseDirectoryPath': request.courseDirectoryPath,
          'sessionStartMillis': request.sessionStart.millisecondsSinceEpoch,
          'segmentationEnabled': request.settings.segmentationEnabled,
          'maxFileSizeMb': request.settings.androidMaxSizeMb,
          'bitRate': request.settings.audioQuality.androidBitRate,
          'sampleRate': request.settings.audioQuality.sampleRate,
        });

    if (result == null) {
      throw Exception('Native recorder did not return a start result.');
    }

    return RecorderStartResult(
      segmentIndex: result['segmentIndex'] as int? ?? 1,
      filePath: result['filePath'] as String? ?? '',
    );
  }

  @override
  Future<RecorderStateSnapshot?> getRecordingState() async {
    final result = await _methodChannel.invokeMapMethod<String, dynamic>(
      'getRecordingState',
    );
    if (result == null) {
      return null;
    }

    final courseName = result['courseName'] as String?;
    final sessionStartMillis = (result['sessionStartMillis'] as num?)?.toInt();
    final filePath = result['filePath'] as String?;
    if (courseName == null ||
        sessionStartMillis == null ||
        filePath == null ||
        filePath.isEmpty) {
      return null;
    }

    return RecorderStateSnapshot(
      courseName: courseName,
      sessionStart: DateTime.fromMillisecondsSinceEpoch(sessionStartMillis),
      segmentIndex: (result['segmentIndex'] as num?)?.toInt() ?? 1,
      filePath: filePath,
      isPaused: result['isPaused'] as bool? ?? false,
      elapsed: Duration(
        milliseconds: (result['elapsedMillis'] as num?)?.toInt() ?? 0,
      ),
    );
  }

  @override
  Future<void> stopRecording() {
    return _methodChannel.invokeMethod<void>('stopRecording');
  }

  @override
  Future<void> pauseRecording() {
    return _methodChannel.invokeMethod<void>('pauseRecording');
  }

  @override
  Future<void> resumeRecording() {
    return _methodChannel.invokeMethod<void>('resumeRecording');
  }

  void _handleNativeEvent(dynamic rawEvent) {
    if (rawEvent is! Map) {
      return;
    }

    final event = Map<String, dynamic>.from(rawEvent.cast<String, dynamic>());
    final typeName = event['type'] as String? ?? '';
    final type = switch (typeName) {
      'started' => RecorderEventType.started,
      'paused' => RecorderEventType.paused,
      'resumed' => RecorderEventType.resumed,
      'segment_completed' => RecorderEventType.segmentCompleted,
      'segment_switched' => RecorderEventType.segmentSwitched,
      'stopped' => RecorderEventType.stopped,
      _ => RecorderEventType.error,
    };

    _eventsController.add(
      RecorderEvent(
        type: type,
        segmentIndex: (event['segmentIndex'] as num?)?.toInt(),
        filePath: event['filePath'] as String?,
        message: event['message'] as String?,
      ),
    );
  }

  @override
  Future<void> dispose() async {
    await _subscription?.cancel();
    await _eventsController.close();
  }
}
