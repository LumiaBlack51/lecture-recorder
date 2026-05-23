import 'dart:ui';

import '../../../shared/constants.dart';

enum AudioQualityPreset {
  low,
  standard,
  high;

  int get androidBitRate {
    switch (this) {
      case AudioQualityPreset.low:
        return 64000;
      case AudioQualityPreset.standard:
        return 96000;
      case AudioQualityPreset.high:
        return 128000;
    }
  }

  int get desktopBitRate {
    switch (this) {
      case AudioQualityPreset.low:
        return 64000;
      case AudioQualityPreset.standard:
        return 96000;
      case AudioQualityPreset.high:
        return 128000;
    }
  }

  int get sampleRate {
    switch (this) {
      case AudioQualityPreset.low:
        return 22050;
      case AudioQualityPreset.standard:
        return 32000;
      case AudioQualityPreset.high:
        return 44100;
    }
  }
}

enum AppLanguage {
  system,
  english,
  chinese;

  Locale? get locale {
    switch (this) {
      case AppLanguage.system:
        return null;
      case AppLanguage.english:
        return const Locale('en');
      case AppLanguage.chinese:
        return const Locale('zh');
    }
  }

  static const supportedLocales = <Locale>[Locale('en'), Locale('zh')];
}

class AppSettings {
  const AppSettings({
    required this.segmentationEnabled,
    required this.androidMaxSizeMb,
    required this.windowsSegmentMinutes,
    required this.audioQuality,
    required this.language,
    required this.courses,
  });

  factory AppSettings.defaults() {
    return const AppSettings(
      segmentationEnabled: true,
      androidMaxSizeMb: 99,
      windowsSegmentMinutes: 30,
      audioQuality: AudioQualityPreset.standard,
      language: AppLanguage.system,
      courses: defaultCourseNames,
    );
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      segmentationEnabled: json['segmentationEnabled'] as bool? ?? true,
      androidMaxSizeMb: json['androidMaxSizeMb'] as int? ?? 99,
      windowsSegmentMinutes: json['windowsSegmentMinutes'] as int? ?? 30,
      audioQuality: AudioQualityPreset.values.firstWhere(
        (value) => value.name == json['audioQuality'],
        orElse: () => AudioQualityPreset.standard,
      ),
      language: AppLanguage.values.firstWhere(
        (value) => value.name == json['language'],
        orElse: () => AppLanguage.system,
      ),
      courses:
          (json['courses'] as List<dynamic>?)
              ?.map((item) => item.toString())
              .where((item) => item.trim().isNotEmpty)
              .toList() ??
          defaultCourseNames,
    );
  }

  final bool segmentationEnabled;
  final int androidMaxSizeMb;
  final int windowsSegmentMinutes;
  final AudioQualityPreset audioQuality;
  final AppLanguage language;
  final List<String> courses;

  AppSettings copyWith({
    bool? segmentationEnabled,
    int? androidMaxSizeMb,
    int? windowsSegmentMinutes,
    AudioQualityPreset? audioQuality,
    AppLanguage? language,
    List<String>? courses,
  }) {
    return AppSettings(
      segmentationEnabled: segmentationEnabled ?? this.segmentationEnabled,
      androidMaxSizeMb: androidMaxSizeMb ?? this.androidMaxSizeMb,
      windowsSegmentMinutes:
          windowsSegmentMinutes ?? this.windowsSegmentMinutes,
      audioQuality: audioQuality ?? this.audioQuality,
      language: language ?? this.language,
      courses: courses ?? this.courses,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'segmentationEnabled': segmentationEnabled,
      'androidMaxSizeMb': androidMaxSizeMb,
      'windowsSegmentMinutes': windowsSegmentMinutes,
      'audioQuality': audioQuality.name,
      'language': language.name,
      'courses': courses,
    };
  }
}
