import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/settings_repository.dart';
import '../domain/app_settings.dart';

class SettingsController extends StateNotifier<AsyncValue<AppSettings>> {
  SettingsController(this._repository) : super(const AsyncLoading()) {
    _load();
  }

  final SettingsRepository _repository;

  Future<void> _load() async {
    final settings = await _repository.load();
    state = AsyncData(settings);
  }

  AppSettings? get currentSettings => state.valueOrNull;

  Future<void> updateSettings(AppSettings settings) async {
    state = AsyncData(settings);
    await _repository.save(settings);
  }

  Future<void> setSegmentationEnabled(bool enabled) async {
    final current = currentSettings;
    if (current == null) return;
    await updateSettings(current.copyWith(segmentationEnabled: enabled));
  }

  Future<void> setAndroidMaxSizeMb(int value) async {
    final current = currentSettings;
    if (current == null) return;
    await updateSettings(current.copyWith(androidMaxSizeMb: value));
  }

  Future<void> setWindowsSegmentMinutes(int value) async {
    final current = currentSettings;
    if (current == null) return;
    await updateSettings(current.copyWith(windowsSegmentMinutes: value));
  }

  Future<void> setAudioQuality(AudioQualityPreset quality) async {
    final current = currentSettings;
    if (current == null) return;
    await updateSettings(current.copyWith(audioQuality: quality));
  }

  Future<void> setLanguage(AppLanguage language) async {
    final current = currentSettings;
    if (current == null) return;
    await updateSettings(current.copyWith(language: language));
  }

  Future<void> addCourse(String courseName) async {
    final current = currentSettings;
    if (current == null) return;
    final normalized = courseName.trim();
    if (normalized.isEmpty || current.courses.contains(normalized)) {
      return;
    }

    await updateSettings(
      current.copyWith(courses: [...current.courses, normalized]),
    );
  }

  Future<void> updateCourse({
    required String previousName,
    required String nextName,
  }) async {
    final current = currentSettings;
    if (current == null) return;
    final normalized = nextName.trim();
    if (normalized.isEmpty) {
      return;
    }
    if (normalized != previousName && current.courses.contains(normalized)) {
      return;
    }
    final updatedCourses = current.courses
        .map((course) => course == previousName ? normalized : course)
        .toList();
    await updateSettings(current.copyWith(courses: updatedCourses));
  }

  Future<void> deleteCourse(String courseName) async {
    final current = currentSettings;
    if (current == null || current.courses.length <= 1) return;
    final updatedCourses = current.courses
        .where((course) => course != courseName)
        .toList();
    await updateSettings(current.copyWith(courses: updatedCourses));
  }
}
