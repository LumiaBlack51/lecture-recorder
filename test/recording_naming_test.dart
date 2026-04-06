import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_recorder/features/settings/domain/app_settings.dart';
import 'package:lecture_recorder/shared/recording_naming.dart';

void main() {
  test('buildRecordingFileName uses the required naming convention', () {
    final fileName = buildRecordingFileName(
      courseName: 'Course 02',
      sessionStart: DateTime(2026, 4, 6, 9, 0),
      segmentIndex: 2,
      extension: 'm4a',
    );

    expect(fileName, 'Course 02_0406_02.m4a');
  });

  test('default settings include bilingual-ready defaults', () {
    final settings = AppSettings.defaults();

    expect(settings.segmentationEnabled, isTrue);
    expect(settings.androidMaxSizeMb, 99);
    expect(settings.windowsSegmentMinutes, 30);
    expect(settings.language, AppLanguage.system);
    expect(settings.courses.length, 5);
  });
}
