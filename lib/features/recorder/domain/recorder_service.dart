import 'dart:async';

import 'recorder_models.dart';

abstract class RecorderService {
  Stream<RecorderEvent> get events;

  bool get supportsPauseResume;

  Future<RecorderStartResult> startRecording(RecordingRequest request);

  Future<RecorderStateSnapshot?> getRecordingState();

  Future<void> stopRecording();

  Future<void> pauseRecording();

  Future<void> resumeRecording();

  Future<void> dispose();
}
