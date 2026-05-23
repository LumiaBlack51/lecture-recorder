import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../app/providers.dart';
import '../../settings/domain/app_settings.dart';
import '../domain/recorder_models.dart';
import '../domain/recorder_service.dart';

class RecordingUiState {
  const RecordingUiState({
    this.status = RecordingStatus.idle,
    this.courseName,
    this.sessionStart,
    this.elapsed = Duration.zero,
    this.currentSegmentIndex = 0,
    this.currentFilePath,
    this.completedFilePaths = const [],
    this.errorMessage,
    this.canPauseResume = false,
  });

  final RecordingStatus status;
  final String? courseName;
  final DateTime? sessionStart;
  final Duration elapsed;
  final int currentSegmentIndex;
  final String? currentFilePath;
  final List<String> completedFilePaths;
  final String? errorMessage;
  final bool canPauseResume;

  bool get isRecording =>
      status == RecordingStatus.recording || status == RecordingStatus.paused;

  bool get isBusy =>
      status == RecordingStatus.starting || status == RecordingStatus.stopping;

  RecordingUiState copyWith({
    RecordingStatus? status,
    String? courseName,
    DateTime? sessionStart,
    Duration? elapsed,
    int? currentSegmentIndex,
    String? currentFilePath,
    List<String>? completedFilePaths,
    String? errorMessage,
    bool clearError = false,
    bool? canPauseResume,
  }) {
    return RecordingUiState(
      status: status ?? this.status,
      courseName: courseName ?? this.courseName,
      sessionStart: sessionStart ?? this.sessionStart,
      elapsed: elapsed ?? this.elapsed,
      currentSegmentIndex: currentSegmentIndex ?? this.currentSegmentIndex,
      currentFilePath: currentFilePath ?? this.currentFilePath,
      completedFilePaths: completedFilePaths ?? this.completedFilePaths,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      canPauseResume: canPauseResume ?? this.canPauseResume,
    );
  }

  RecordingUiState reset() => const RecordingUiState();
}

class RecordingController extends StateNotifier<RecordingUiState> {
  RecordingController(this._ref) : super(const RecordingUiState()) {
    if (Platform.isAndroid) {
      unawaited(_restoreRecordingState());
    }
  }

  final Ref _ref;
  RecorderService? _service;
  StreamSubscription<RecorderEvent>? _eventSubscription;
  Timer? _ticker;
  DateTime? _elapsedAnchorTime;
  Duration _elapsedAnchorValue = Duration.zero;

  RecorderService get _recordingService {
    final existingService = _service;
    if (existingService != null) {
      return existingService;
    }

    final service = _ref.read(recorderServiceProvider);
    _service = service;
    _eventSubscription = service.events.listen(_handleEvent);
    return service;
  }

  Future<void> startRecording(String courseName) async {
    if (state.isBusy) {
      return;
    }

    final settings = _readSettings();
    if (settings == null) {
      return;
    }

    if (Platform.isAndroid) {
      final permission = await Permission.microphone.request();
      final notificationPermission = await Permission.notification.request();
      if (!permission.isGranted ||
          (!notificationPermission.isGranted &&
              !notificationPermission.isLimited &&
              !notificationPermission.isProvisional)) {
        state = state.copyWith(
          status: RecordingStatus.error,
          errorMessage: 'Microphone or notification permission was denied.',
        );
        return;
      }
    }

    final sessionStart = DateTime.now();
    final service = _recordingService;
    state = state.copyWith(
      status: RecordingStatus.starting,
      courseName: courseName,
      sessionStart: sessionStart,
      elapsed: Duration.zero,
      currentSegmentIndex: 1,
      completedFilePaths: const [],
      clearError: true,
      canPauseResume: service.supportsPauseResume,
    );

    try {
      final storageService = _ref.read(storageServiceProvider);
      final courseDirectory = await storageService.ensureCourseDirectory(
        courseName,
      );

      final result = await service.startRecording(
        RecordingRequest(
          courseName: courseName,
          courseDirectoryPath: courseDirectory.path,
          sessionStart: sessionStart,
          settings: settings,
        ),
      );

      state = state.copyWith(
        status: RecordingStatus.recording,
        currentSegmentIndex: result.segmentIndex,
        currentFilePath: result.filePath,
      );
      _elapsedAnchorValue = Duration.zero;
      _elapsedAnchorTime = DateTime.now();
      _startTicker();
    } catch (error) {
      state = state.copyWith(
        status: RecordingStatus.error,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> stopRecording() async {
    if (!state.isRecording || state.isBusy) {
      return;
    }

    state = state.copyWith(status: RecordingStatus.stopping, clearError: true);
    _ticker?.cancel();

    try {
      await _recordingService.stopRecording();
      _ref.read(recordingsRefreshProvider.notifier).state++;
    } catch (error) {
      state = state.copyWith(
        status: RecordingStatus.error,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> pauseOrResume() async {
    final service = _service;
    if (!state.canPauseResume || service == null) {
      return;
    }

    if (state.status == RecordingStatus.recording) {
      await service.pauseRecording();
      return;
    }

    if (state.status == RecordingStatus.paused) {
      await service.resumeRecording();
    }
  }

  AppSettings? _readSettings() {
    final settingsState = _ref.read(settingsControllerProvider);
    return settingsState.valueOrNull;
  }

  Future<void> _restoreRecordingState() async {
    try {
      final service = _recordingService;
      final snapshot = await service.getRecordingState();
      if (snapshot == null) {
        return;
      }

      state = state.copyWith(
        status: snapshot.isPaused
            ? RecordingStatus.paused
            : RecordingStatus.recording,
        courseName: snapshot.courseName,
        sessionStart: snapshot.sessionStart,
        elapsed: snapshot.elapsed,
        currentSegmentIndex: snapshot.segmentIndex,
        currentFilePath: snapshot.filePath,
        canPauseResume: service.supportsPauseResume,
        clearError: true,
      );

      _elapsedAnchorValue = snapshot.elapsed;
      _elapsedAnchorTime = snapshot.isPaused ? null : DateTime.now();
      if (!snapshot.isPaused) {
        _startTicker();
      }
    } catch (_) {
      // Ignore restore failures and keep the controller usable.
    }
  }

  void _handleEvent(RecorderEvent event) {
    switch (event.type) {
      case RecorderEventType.started:
        _elapsedAnchorValue = Duration.zero;
        _elapsedAnchorTime = DateTime.now();
        state = state.copyWith(
          status: RecordingStatus.recording,
          currentSegmentIndex: event.segmentIndex ?? state.currentSegmentIndex,
          currentFilePath: event.filePath ?? state.currentFilePath,
          elapsed: Duration.zero,
        );
        _startTicker();
      case RecorderEventType.paused:
        _elapsedAnchorValue = state.elapsed;
        _elapsedAnchorTime = null;
        _ticker?.cancel();
        state = state.copyWith(status: RecordingStatus.paused);
      case RecorderEventType.resumed:
        _elapsedAnchorTime = DateTime.now();
        state = state.copyWith(status: RecordingStatus.recording);
        _startTicker();
      case RecorderEventType.segmentCompleted:
        final filePath = event.filePath;
        if (filePath != null && !state.completedFilePaths.contains(filePath)) {
          state = state.copyWith(
            completedFilePaths: [...state.completedFilePaths, filePath],
          );
        }
      case RecorderEventType.segmentSwitched:
        state = state.copyWith(
          status: RecordingStatus.recording,
          currentSegmentIndex: event.segmentIndex ?? state.currentSegmentIndex,
          currentFilePath: event.filePath ?? state.currentFilePath,
        );
      case RecorderEventType.stopped:
        _ticker?.cancel();
        _elapsedAnchorValue = Duration.zero;
        _elapsedAnchorTime = null;
        state = state.reset();
      case RecorderEventType.error:
        _ticker?.cancel();
        _elapsedAnchorTime = null;
        state = state.copyWith(
          status: RecordingStatus.error,
          errorMessage: event.message ?? 'Recording failed.',
        );
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final anchorTime = _elapsedAnchorTime;
      if (anchorTime == null || state.status != RecordingStatus.recording) {
        return;
      }
      state = state.copyWith(
        elapsed: _elapsedAnchorValue + DateTime.now().difference(anchorTime),
      );
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _eventSubscription?.cancel();
    super.dispose();
  }
}
