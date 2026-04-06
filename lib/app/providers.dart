import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/recorder/data/android_recorder_service.dart';
import '../features/recorder/data/windows_recorder_service.dart';
import '../features/recorder/domain/recorder_service.dart';
import '../features/recorder/presentation/recording_controller.dart';
import '../features/recordings/data/recordings_repository.dart';
import '../features/settings/data/settings_repository.dart';
import '../features/settings/domain/app_settings.dart';
import '../features/settings/presentation/settings_controller.dart';
import '../services/platform_file_service.dart';
import '../services/storage_service.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('SharedPreferences override is missing.'),
);

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

final platformFileServiceProvider = Provider<PlatformFileService>((ref) {
  return PlatformFileService();
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final preferences = ref.watch(sharedPreferencesProvider);
  return SettingsRepository(preferences);
});

final settingsControllerProvider =
    StateNotifierProvider<SettingsController, AsyncValue<AppSettings>>((ref) {
      final repository = ref.watch(settingsRepositoryProvider);
      return SettingsController(repository);
    });

final recorderServiceProvider = Provider<RecorderService>((ref) {
  final service = Platform.isAndroid
      ? AndroidRecorderService()
      : WindowsRecorderService();
  ref.onDispose(service.dispose);
  return service;
});

final recordingControllerProvider =
    StateNotifierProvider<RecordingController, RecordingUiState>(
      (ref) => RecordingController(ref),
    );

final recordingsRepositoryProvider = Provider<RecordingsRepository>((ref) {
  final storageService = ref.watch(storageServiceProvider);
  return RecordingsRepository(storageService);
});

final recordingsRefreshProvider = StateProvider<int>((ref) => 0);

final recordingsProvider = FutureProvider<List<RecordingEntry>>((ref) async {
  ref.watch(recordingsRefreshProvider);
  final repository = ref.watch(recordingsRepositoryProvider);
  return repository.loadRecordings();
});

final recordingDurationProvider = FutureProvider.family<Duration?, String>((
  ref,
  filePath,
) async {
  final repository = ref.watch(recordingsRepositoryProvider);
  return repository.loadDuration(filePath);
});
