import '../../settings/domain/app_settings.dart';

enum RecordingStatus { idle, starting, recording, paused, stopping, error }

enum RecorderEventType {
  started,
  paused,
  resumed,
  segmentCompleted,
  segmentSwitched,
  stopped,
  error,
}

class RecordingRequest {
  const RecordingRequest({
    required this.courseName,
    required this.courseDirectoryPath,
    required this.sessionStart,
    required this.settings,
  });

  final String courseName;
  final String courseDirectoryPath;
  final DateTime sessionStart;
  final AppSettings settings;
}

class RecorderStartResult {
  const RecorderStartResult({
    required this.segmentIndex,
    required this.filePath,
  });

  final int segmentIndex;
  final String filePath;
}

class RecorderStateSnapshot {
  const RecorderStateSnapshot({
    required this.courseName,
    required this.sessionStart,
    required this.segmentIndex,
    required this.filePath,
    required this.isPaused,
    required this.elapsed,
  });

  final String courseName;
  final DateTime sessionStart;
  final int segmentIndex;
  final String filePath;
  final bool isPaused;
  final Duration elapsed;
}

class RecorderEvent {
  const RecorderEvent({
    required this.type,
    this.segmentIndex,
    this.filePath,
    this.message,
  });

  final RecorderEventType type;
  final int? segmentIndex;
  final String? filePath;
  final String? message;
}
